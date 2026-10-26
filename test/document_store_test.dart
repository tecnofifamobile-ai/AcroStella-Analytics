import 'dart:io';

import 'package:acrostella_analytics/src/files/document_store.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'imports a private copy, survives reopening, deletion retains the original',
    () async {
      final root = await Directory.systemTemp.createTemp('hub-documents-');
      try {
        final original = await File('${root.path}/plan.txt')
            .writeAsString('Entrenamiento');
        final store = DocumentStore(
          () async => Directory('${root.path}/private'),
        );
        final copy = await store.importFile(XFile(original.path));
        expect(copy.name, 'plan.txt');
        expect(await File(copy.path).readAsString(), 'Entrenamiento');
        expect(
          (await DocumentStore(
            () async => Directory('${root.path}/private'),
          ).list()).single.id,
          copy.id,
        );
        await store.delete(copy.id);
        expect(await store.list(), isEmpty);
        expect(await original.readAsString(), 'Entrenamiento');
        await expectLater(store.delete('../plan'), throwsFormatException);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test('over-limit and interrupted imports clean partial files and preserve originals', () async {
    final root = await Directory.systemTemp.createTemp('hub-document-quota-');
    try {
      final file = await File('${root.path}/big.txt')
          .writeAsBytes(List.filled(64, 7));
      final dir = Directory('${root.path}/private'),
          store = DocumentStore(
            () async => Directory('${root.path}/private'),
            maxFileBytes: 32,
          );
      await expectLater(
        store.importFile(XFile(file.path)),
        throwsA(isA<FileSystemException>()),
      );
      expect(await store.list(), isEmpty);
      expect(await dir.list().toList(), isEmpty);
      expect(await file.length(), 64);
    } finally {
      await root.delete(recursive: true);
    }
  });
  test('concurrent imports share quota atomically', () async {
    final root = await Directory.systemTemp.createTemp('hub-doc-concurrency-');
    try {
      final file = await File('${root.path}/note.txt').writeAsString('one');
      final store = DocumentStore(
        () async => Directory('${root.path}/private'),
        maxCount: 1,
      );
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          store
              .importFile(XFile(file.path))
              .then((_) => true, onError: (Object _) => false),
      ]);
      expect(results.where((v) => v), hasLength(1));
      expect(await store.list(), hasLength(1));
    } finally {
      await root.delete(recursive: true);
    }
  });
}
