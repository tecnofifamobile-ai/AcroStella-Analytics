import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';

class PrivateDocument {
  const PrivateDocument({
    required this.id,
    required this.name,
    required this.path,
    required this.bytes,
    required this.importedAt,
  });
  final String id, name, path;
  final int bytes;
  final DateTime importedAt;
}

/// Bounded, app-private copies. Import never moves/deletes a provider's source.
/// File paths are derived from opaque IDs, never from document names.
class DocumentStore {
  DocumentStore(
    this.directory, {
    this.maxFileBytes = 128 * 1024 * 1024,
    this.maxBytes = 512 * 1024 * 1024,
    this.maxCount = 100,
  });
  final Future<Directory> Function() directory;
  final int maxFileBytes, maxBytes, maxCount;
  Future<void> _pending = Future.value();
  Future<T> _serialize<T>(Future<T> Function(Directory) action) {
    final next = _pending.then((_) async {
      final dir = await directory();
      await dir.create(recursive: true);
      return action(dir);
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<List<PrivateDocument>> list() => _serialize(_list);
  Future<List<PrivateDocument>> _list(Directory dir) async {
    final output = <PrivateDocument>[];
    await for (final entry in dir.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      if (await entry.length() > 8192) {
        throw const FormatException('Registro de documento inválido');
      }
      final data =
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>;
      final id = data['id'] as String, name = data['name'] as String;
      if (!RegExp(r'^[a-f0-9]{24}$').hasMatch(id) ||
          name.isEmpty ||
          name.length > 240 ||
          name.contains(RegExp(r'[/\\\x00]')) ||
          !entry.path.endsWith('/$id.json')) {
        throw const FormatException('Registro de documento inválido');
      }
      final path = '${dir.path}/$id.data';
      final file = File(path);
      if (!await file.exists()) continue;
      final bytes = await file.length();
      if (bytes != data['bytes'] || bytes > maxFileBytes) {
        throw const FormatException('Documento incompleto');
      }
      output.add(
        PrivateDocument(
          id: id,
          name: name,
          path: path,
          bytes: bytes,
          importedAt: DateTime.parse(data['importedAt'] as String),
        ),
      );
    }
    output.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return output;
  }

  Future<PrivateDocument> importFile(XFile source) => _serialize((dir) async {
    final name = source.name;
    if (name.isEmpty ||
        name.length > 240 ||
        name.contains(RegExp(r'[/\\\x00]'))) {
      throw const FormatException('Nombre de archivo inválido');
    }
    final existing = await _list(dir);
    if (existing.length >= maxCount) {
      throw const FileSystemException('Límite de documentos alcanzado');
    }
    final random = Random.secure();
    final id = List.generate(
      12,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final partial = File('${dir.path}/$id.part'),
        file = File('${dir.path}/$id.data'),
        manifest = File('${dir.path}/$id.json');
    var bytes = 0;
    RandomAccessFile? writer;
    try {
      writer = await partial.open(mode: FileMode.write);
      final used = existing.fold<int>(0, (n, f) => n + f.bytes);
      await for (final chunk in source.openRead()) {
        bytes += chunk.length;
        if (bytes > maxFileBytes || used + bytes > maxBytes) {
          throw const FileSystemException(
            'No hay cuota disponible para este archivo',
          );
        }
        await writer.writeFrom(chunk);
      }
      await writer.flush();
      await writer.close();
      writer = null;
      await partial.rename(file.path);
      final now = DateTime.now();
      final temporary = File('${manifest.path}.part');
      await temporary.writeAsString(
        jsonEncode({
          'id': id,
          'name': name,
          'bytes': bytes,
          'importedAt': now.toIso8601String(),
        }),
        flush: true,
      );
      await temporary.rename(manifest.path);
      return PrivateDocument(
        id: id,
        name: name,
        path: file.path,
        bytes: bytes,
        importedAt: now,
      );
    } catch (_) {
      await writer?.close();
      for (final candidate in [
        partial,
        file,
        manifest,
        File('${manifest.path}.part'),
      ]) {
        if (await candidate.exists()) await candidate.delete();
      }
      rethrow;
    }
  });
  Future<void> delete(String id) => _serialize((dir) async {
    if (!RegExp(r'^[a-f0-9]{24}$').hasMatch(id)) {
      throw const FormatException('Identificador inválido');
    }
    for (final suffix in ['data', 'json']) {
      final file = File('${dir.path}/$id.$suffix');
      if (await file.exists()) await file.delete();
    }
  });
}
