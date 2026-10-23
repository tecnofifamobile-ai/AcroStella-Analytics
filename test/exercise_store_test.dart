import 'dart:io';

import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/clips/video_annotation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late FileClipStore store;
  var sequence = 0;
  Future<LocalClip> add([int bytes = 6]) async {
    final input = File('${root.path}/source-${sequence++}.mp4');
    await input.writeAsBytes(List.filled(bytes, 7));
    return store.add(input.path, DateTime.now(), const Duration(seconds: 10));
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('exercise-library-test-');
    store = FileClipStore(
      () async => Directory('${root.path}/library'),
      maxClips: 2,
      maxBytes: 16,
      maxClipBytes: 8,
      maxSavedBytes: 10,
      maxSavedClips: 2,
      durable: true,
    );
  });
  tearDown(() async => root.delete(recursive: true));

  test('saved exercises survive recording beyond pending retention', () async {
    final first = await add();
    await store.updateDetails(first.id, saved: true, name: 'Equilibrio');
    for (var n = 0; n < 5; n++) {
      await add();
    }
    final clips = await store.list();
    expect(clips.length, 3);
    expect(clips.where((c) => c.saved).single.id, first.id);
    expect(await File(first.path).exists(), isTrue);
  });
  test('quota failure preserves both saved and pending originals', () async {
    final first = await add(), second = await add();
    await store.updateDetails(first.id, saved: true);
    await expectLater(
      store.updateDetails(second.id, saved: true),
      throwsA(isA<ClipStorageException>()),
    );
    final clips = await store.list();
    expect(clips.where((c) => c.saved).single.id, first.id);
    expect(clips.where((c) => !c.saved).single.id, second.id);
    expect(await File(second.path).exists(), isTrue);
  });
  test('saved state names notes favorite markers and drawings survive reopen while leased', () async {
    final clip = await add();
    await store.acquire(clip.id);
    final note = VideoAnnotation(
      tool: AnnotationTool.arrow,
      points: const [Offset(.2, .3), Offset(.7, .8)],
      start: Duration.zero,
      end: const Duration(seconds: 2),
      color: 0xffff6b6b,
      width: .012,
    );
    await store.saveAnnotations(clip.id, [note]);
    await store.updateDetails(
      clip.id,
      saved: true,
      name: '  Intento 2 ',
      memo: 'Recepción',
      favorite: true,
      markers: const [Duration(seconds: 1), Duration(seconds: 5)],
    );
    final reopened = FileClipStore(
      () async => Directory('${root.path}/library'),
      durable: true,
    );
    final restored = (await reopened.list()).single;
    expect(restored.saved, isTrue);
    expect(restored.favorite, isTrue);
    expect(restored.name, 'Intento 2');
    expect(restored.memo, 'Recepción');
    expect(restored.markers, const [
      Duration(seconds: 1),
      Duration(seconds: 5),
    ]);
    expect(
      (await reopened.annotations(clip.id)).single.toJson(),
      note.toJson(),
    );
    await expectLater(
      store.delete(clip.id),
      throwsA(isA<ClipStorageException>()),
    );
    await store.release(clip.id);
    await store.delete(clip.id);
    expect(await store.list(), isEmpty);
    expect(
      await File('${root.path}/library/${clip.id}.notes.json').exists(),
      isFalse,
    );
  });
  test(
    'migration copies v03 video and annotations once and keeps cache originals',
    () async {
      final legacyDirectory = Directory('${root.path}/legacy');
      final legacy = FileClipStore(() async => legacyDirectory);
      final input = File('${root.path}/legacy.mp4');
      await input.writeAsBytes([1, 2, 3]);
      final clip = await legacy.add(
        input.path,
        DateTime.now(),
        const Duration(seconds: 2),
      );
      await legacy.saveAnnotations(clip.id, [
        VideoAnnotation(
          tool: AnnotationTool.line,
          points: const [Offset(.2, .2), Offset(.6, .6)],
          start: Duration.zero,
          end: const Duration(seconds: 1),
        ),
      ]);
      FileClipStore migrated() => FileClipStore(
        () async => Directory('${root.path}/migrated'),
        durable: true,
        legacyDirectory: () async => legacyDirectory,
      );
      final next = migrated();
      final imported = (await next.list()).single;
      expect(await File(imported.path).readAsBytes(), [1, 2, 3]);
      expect(imported.saved, isFalse);
      expect((await next.annotations(imported.id)).length, 1);
      expect(await File(clip.path).exists(), isTrue);
      await next.updateDetails(imported.id, saved: true);
      expect((await migrated().list()).single.saved, isTrue);
      await next.delete(imported.id);
      expect(await File(clip.path).exists(), isFalse);
      expect(
        await File('${legacyDirectory.path}/${clip.id}.notes.json').exists(),
        isFalse,
      );
    },
  );
  test('durable mode preserves video when manifest is damaged', () async {
    final clip = await add();
    await store.updateDetails(clip.id, saved: true);
    await File('${root.path}/library/${clip.id}.json').writeAsString('{broken');
    expect(await store.list(), isEmpty);
    expect(await File(clip.path).exists(), isTrue);
  });
  test('invalid edits never replace the valid manifest', () async {
    final clip = await add();
    await store.updateDetails(clip.id, saved: true, name: 'Conservar');
    await expectLater(
      store.updateDetails(clip.id, name: 'x' * 81),
      throwsFormatException,
    );
    await expectLater(
      store.updateDetails(clip.id, markers: const [Duration(seconds: -1)]),
      throwsFormatException,
    );
    await expectLater(
      store.updateDetails(clip.id, saved: false),
      throwsA(isA<ClipStorageException>()),
    );
    expect((await store.list()).single.name, 'Conservar');
    expect((await store.list()).single.saved, isTrue);
  });
}
