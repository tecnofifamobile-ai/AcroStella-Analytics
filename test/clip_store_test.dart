import 'dart:io';

import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/clips/video_annotation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory cache;
  late FileClipStore store;
  var inputSequence = 0;

  Future<File> input(int bytes) async {
    final file = File('${root.path}/input-${inputSequence++}.mp4');
    await file.writeAsBytes(List.filled(bytes, 7));
    return file;
  }

  Future<LocalClip> add(int size, int second) async => store.add(
    (await input(size)).path,
    DateTime.utc(2026, 10, 22, 10, 0, second),
    const Duration(seconds: 2),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('acrostella-clips-test-');
    cache = Directory('${root.path}/clips');
    store = FileClipStore(
      () async => cache,
      maxClips: 3,
      maxBytes: 12,
      maxClipBytes: 6,
    );
  });

  tearDown(() async => root.delete(recursive: true));

  test(
    'completed clip metadata and bytes survive reopening the store',
    () async {
      final source = await input(4);
      final date = DateTime.utc(2026, 10, 22);
      final clip = await store.add(
        source.path,
        date,
        const Duration(seconds: 3),
      );
      expect(await source.exists(), isFalse);
      final reopened = FileClipStore(
        () async => cache,
        maxClips: 3,
        maxBytes: 12,
        maxClipBytes: 6,
      );
      final saved = (await reopened.list()).single;
      expect(saved.id, clip.id);
      expect(saved.createdAt, date);
      expect(saved.elapsed, const Duration(seconds: 3));
      expect(await File(saved.path).readAsBytes(), [7, 7, 7, 7]);
    },
  );

  test(
    'oversized clip is rejected and cleaned without evicting existing media',
    () async {
      final existing = await add(4, 1);
      final source = await input(7);
      await expectLater(
        store.add(source.path, DateTime.now(), Duration.zero),
        throwsA(isA<ClipStorageException>()),
      );
      expect(await source.exists(), isFalse);
      expect((await store.list()).single.id, existing.id);
    },
  );

  test('byte quota evicts oldest unpinned media', () async {
    final oldest = await add(6, 1);
    final next = await add(6, 2);
    final latest = await add(6, 3);
    expect((await store.list()).map((clip) => clip.id), [latest.id, next.id]);
    expect(await File(oldest.path).exists(), isFalse);
  });

  test('count quota evicts independently of byte quota', () async {
    final first = await add(1, 1);
    await add(1, 2);
    await add(1, 3);
    await add(1, 4);
    expect(await store.list(), hasLength(3));
    expect(await File(first.path).exists(), isFalse);
  });

  test('multiple readers protect media until the final release', () async {
    store = FileClipStore(
      () async => cache,
      maxClips: 1,
      maxBytes: 6,
      maxClipBytes: 6,
    );
    final first = await add(4, 1);
    await store.acquire(first.id);
    await store.acquire(first.id);
    await expectLater(add(4, 2), throwsA(isA<ClipStorageException>()));
    await store.release(first.id);
    await expectLater(add(4, 3), throwsA(isA<ClipStorageException>()));
    expect(await File(first.path).exists(), isTrue);
    await store.release(first.id);
    final last = await add(4, 4);
    expect((await store.list()).single.id, last.id);
    expect(await File(first.path).exists(), isFalse);
  });

  test('delete refuses open clips and removes both manifest and media after release', () async {
    final clip = await add(4, 1);
    await store.acquire(clip.id);
    await expectLater(
      store.delete(clip.id),
      throwsA(isA<ClipStorageException>()),
    );
    await store.release(clip.id);
    await store.delete(clip.id);
    expect(await File(clip.path).exists(), isFalse);
    expect(await File('${cache.path}/${clip.id}.json').exists(), isFalse);
    expect(await store.list(), isEmpty);
  });

  test(
    'concurrent imports are serialized and do not exceed count or byte limits',
    () async {
      await Future.wait([for (var i = 1; i <= 6; i++) add(4, i)]);
      final clips = await store.list();
      expect(clips, hasLength(3));
      expect(clips.fold<int>(0, (sum, clip) => sum + clip.bytes), 12);
    },
  );

  test(
    'startup recovers incomplete writes but preserves foreign files',
    () async {
      await cache.create();
      for (final name in [
        '1_0.pending',
        '1_0.mp4',
        '2_0.json',
        '2_0.mp4',
        '3_0.json',
      ]) {
        await File('${cache.path}/$name').writeAsString('broken');
      }
      final foreign = File('${cache.path}/notes.txt');
      await foreign.writeAsString('keep');
      expect(await store.list(), isEmpty);
      final names = await cache
          .list()
          .map((entry) => entry.uri.pathSegments.last)
          .toList();
      expect(names, ['notes.txt']);
    },
  );

  test('destination failure cleans native temporary file and does not poison queue', () async {
    var fail = true;
    store = FileClipStore(() async {
      if (fail) throw const FileSystemException('cache unavailable');
      return cache;
    });
    final source = await input(4);
    await expectLater(
      store.add(source.path, DateTime.now(), Duration.zero),
      throwsA(isA<FileSystemException>()),
    );
    expect(await source.exists(), isFalse);
    fail = false;
    await add(4, 1);
    expect(await store.list(), hasLength(1));
  });

  test(
    'cache purged by OS reports unavailable media instead of a stale clip',
    () async {
      final clip = await add(4, 1);
      await File(clip.path).delete();
      await expectLater(
        store.acquire(clip.id),
        throwsA(isA<ClipStorageException>()),
      );
      expect(await store.list(), isEmpty);
    },
  );

  test('ids cannot delete outside the managed cache', () async {
    final outside = await input(4);
    await expectLater(
      store.delete('../${outside.uri.pathSegments.last}'),
      throwsArgumentError,
    );
    expect(await outside.exists(), isTrue);
  });

  test(
    'normalized drawings and media timing survive store reopening',
    () async {
      final clip = await add(4, 1);
      final note = VideoAnnotation(
        tool: AnnotationTool.line,
        points: const [Offset(.1, .2), Offset(.8, .9)],
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 4),
      );
      await store.saveAnnotations(clip.id, [note]);
      final reopened = FileClipStore(
        () async => cache,
        maxClips: 3,
        maxBytes: 12,
        maxClipBytes: 6,
      );
      final restored = (await reopened.annotations(clip.id)).single;
      expect(restored.points, note.points);
      expect(restored.start, note.start);
      expect(restored.end, note.end);
    },
  );

  test('eviction removes drawings belonging to the evicted clip', () async {
    final clip = await add(6, 1);
    await store.saveAnnotations(clip.id, [
      VideoAnnotation(
        tool: AnnotationTool.line,
        points: const [Offset(0, 0), Offset(1, 1)],
        start: Duration.zero,
        end: const Duration(seconds: 1),
      ),
    ]);
    await add(6, 2);
    await add(6, 3);
    expect(await File('${cache.path}/${clip.id}.notes.json').exists(), isFalse);
  });

  test('corrupt drawings are reported without losing the video or overwriting notes', () async {
    final clip = await add(4, 1);
    final file = File('${cache.path}/${clip.id}.notes.json');
    await file.writeAsString('broken');
    await expectLater(store.annotations(clip.id), throwsFormatException);
    expect(await File(clip.path).exists(), isTrue);
    expect(await file.readAsString(), 'broken');
  });

  test(
    'drawing count is bounded and a failed save preserves previous drawings',
    () async {
      final clip = await add(4, 1);
      final note = VideoAnnotation(
        tool: AnnotationTool.line,
        points: const [Offset(0, 0), Offset(1, 1)],
        start: Duration.zero,
        end: const Duration(seconds: 1),
      );
      await store.saveAnnotations(clip.id, [note]);
      await expectLater(
        store.saveAnnotations(clip.id, List.filled(101, note)),
        throwsA(isA<ClipStorageException>()),
      );
      expect(await store.annotations(clip.id), hasLength(1));
    },
  );
}
