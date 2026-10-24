import 'dart:io';

import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/clips/exercise_backup.dart';
import 'package:acrostella_analytics/src/clips/video_annotation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late FileClipStore store;
  Future<File> media(String name, int value) =>
      File('${root.path}/$name').writeAsBytes(List.filled(256, value));
  setUp(() async {
    root = await Directory.systemTemp.createTemp('acrostella-group-');
    store = FileClipStore(
      () async => Directory('${root.path}/library'),
      durable: true,
      maxClipBytes: 512,
      maxBytes: 2048,
      maxSavedBytes: 8192,
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<LocalClip> grouped() async {
    final c = await store.add(
      (await media('main', 1)).path,
      DateTime.utc(2026),
      const Duration(seconds: 3),
    );
    await store.updateDetails(
      c.id,
      saved: true,
      name: 'Recepción',
      memo: 'Revisar alineación',
      favorite: true,
    );
    await store.organize(c.id, session: 'Sábado', tags: ['Trío', 'Equilibrio']);
    await store.saveAnnotations(c.id, [
      VideoAnnotation(
        tool: AnnotationTool.line,
        points: const [Offset(.2, .2), Offset(.8, .8)],
        start: Duration.zero,
        end: const Duration(seconds: 2),
        angle: 1,
      ),
    ]);
    return store.attachAngle(
      c.id,
      (await media('second', 2)).path,
      offsetUs: -100000,
      clockUncertaintyUs: 12000,
    );
  }

  test('group survives metadata edits, reader lease protects both files, deletion removes both', () async {
    final c = await grouped();
    expect(c.bytes, 512);
    expect(c.tags, ['Trío', 'Equilibrio']);
    await store.updateDetails(c.id, memo: 'Otra nota');
    await store.adjustOffset(c.id, 33000);
    final reopened = FileClipStore(
      () async => Directory('${root.path}/library'),
      durable: true,
      maxClipBytes: 512,
      maxBytes: 2048,
      maxSavedBytes: 8192,
    );
    final saved = (await reopened.list()).single;
    expect(saved.offsetUs, 33000);
    expect(saved.secondaryBytes, 256);
    expect(saved.session, 'Sábado');
    expect((await reopened.annotations(c.id)).single.angle, 1);
    await store.acquire(c.id);
    await expectLater(store.delete(c.id), throwsA(isA<ClipStorageException>()));
    expect(await File(c.secondaryPath!).exists(), isTrue);
    await store.release(c.id);
    await store.delete(c.id);
    expect(await File(c.path).exists(), isFalse);
    expect(await File(c.secondaryPath!).exists(), isFalse);
  });
  test('failed second angle attachment leaves original untouched', () async {
    final c = await store.add(
      (await media('main', 1)).path,
      DateTime.utc(2026),
      Duration.zero,
    );
    final large = await File('${root.path}/large')
        .writeAsBytes(List.filled(513, 3));
    await expectLater(
      store.attachAngle(c.id, large.path, offsetUs: 0, clockUncertaintyUs: 0),
      throwsA(isA<ClipStorageException>()),
    );
    expect((await store.list()).single.hasSecondAngle, isFalse);
    expect(await File(c.path).exists(), isTrue);
  });
  test('streaming backup restores both angles, organization and per-angle drawings with new IDs', () async {
    final c = await grouped();
    final output = await ExerciseBackup.export(
      store,
      File('${root.path}/copy.acrostella'),
    );
    final target = FileClipStore(
      () async => Directory('${root.path}/restored'),
      durable: true,
      maxClipBytes: 512,
      maxBytes: 2048,
      maxSavedBytes: 8192,
    );
    expect(
      await ExerciseBackup.restore(
        target,
        output,
        Directory('${root.path}/stage'),
      ),
      1,
    );
    final restored = (await target.list()).single;
    expect(restored.id, isNot(c.id));
    expect(restored.name, 'Recepción');
    expect(restored.tags, c.tags);
    expect(restored.session, c.session);
    expect(restored.offsetUs, c.offsetUs);
    expect(restored.clockUncertaintyUs, 12000);
    expect(restored.favorite, isTrue);
    expect(
      await File(restored.path).readAsBytes(),
      await File(c.path).readAsBytes(),
    );
    expect(
      await File(restored.secondaryPath!).readAsBytes(),
      await File(c.secondaryPath!).readAsBytes(),
    );
    expect((await target.annotations(restored.id)).single.angle, 1);
  });
  test('corrupt and truncated backups never change existing library', () async {
    final c = await grouped();
    final output = await ExerciseBackup.export(
      store,
      File('${root.path}/copy.acrostella'),
    );
    final bytes = await output.readAsBytes();
    bytes[bytes.length - 1] ^= 1;
    await output.writeAsBytes(bytes);
    await expectLater(
      ExerciseBackup.restore(store, output, Directory('${root.path}/stage')),
      throwsFormatException,
    );
    expect((await store.list()).single.id, c.id);
    await output.writeAsBytes(bytes.sublist(0, bytes.length - 20));
    await expectLater(
      ExerciseBackup.restore(store, output, Directory('${root.path}/stage2')),
      throwsFormatException,
    );
    expect((await store.list()).single.id, c.id);
  });
}
