import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'video_annotation.dart';

class LocalClip {
  const LocalClip({
    required this.id,
    required this.path,
    required this.createdAt,
    required this.elapsed,
    required this.bytes,
  });

  final String id;
  final String path;
  final DateTime createdAt;
  // Monotonic control elapsed time, not a sensor timestamp or media duration.
  final Duration elapsed;
  final int bytes;
}

class ClipStorageException implements Exception {
  const ClipStorageException(this.message);
  final String message;
}

abstract interface class ClipStore {
  Future<List<LocalClip>> list();
  // Takes ownership of the native temporary file, including on failure.
  Future<LocalClip> add(String source, DateTime createdAt, Duration elapsed);
  Future<void> delete(String id);
  Future<LocalClip> acquire(String id);
  Future<void> release(String id);
  Future<List<VideoAnnotation>> annotations(String id);
  Future<void> saveAnnotations(String id, List<VideoAnnotation> notes);
}

/// An app-private, bounded temporary clip collection, not the final library.
/// Files in use by a player are pinned until that player has been disposed.
class FileClipStore implements ClipStore {
  FileClipStore(
    this._directory, {
    this.maxClips = 3,
    this.maxBytes = 128 * 1024 * 1024,
    this.maxClipBytes = 64 * 1024 * 1024,
  }) {
    if (maxClips < 1 || maxClipBytes < 1 || maxBytes < maxClipBytes) {
      throw ArgumentError('Invalid clip storage limits');
    }
  }

  final Future<Directory> Function() _directory;
  final int maxClips;
  final int maxBytes;
  final int maxClipBytes;
  final Map<String, int> _readers = {};
  Future<void> _pending = Future<void>.value();
  int _sequence = 0;

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<T> _serialize<T>(Future<T> Function(Directory) operation) =>
      _enqueue(() async {
        final directory = await _directory();
        await directory.create(recursive: true);
        return operation(directory);
      });

  static final _validId = RegExp(r'^\d+_\d+$');

  Future<List<LocalClip>> _load(Directory directory) async {
    final clips = <LocalClip>[];
    final entities = await directory.list(followLinks: false).toList();
    for (final entity in entities) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File || !name.endsWith('.json')) continue;
      final id = name.substring(0, name.length - 5);
      if (!_validId.hasMatch(id)) continue;
      try {
        if (await entity.length() > 4096) {
          throw const FormatException('Invalid manifest size');
        }
        final data =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final video = File('${directory.path}/$id.mp4');
        final stat = await video.stat();
        final elapsed = data['elapsedUs'] as int;
        if (data['schema'] != 1 ||
            stat.type != FileSystemEntityType.file ||
            stat.size <= 0 ||
            stat.size > maxClipBytes ||
            stat.size != data['bytes'] ||
            elapsed < 0) {
          throw const FormatException('Invalid clip');
        }
        clips.add(
          LocalClip(
            id: id,
            path: video.path,
            createdAt: DateTime.parse(data['createdAt'] as String),
            elapsed: Duration(microseconds: elapsed),
            bytes: stat.size,
          ),
        );
      } catch (error) {
        if (error is! FormatException &&
            error is! TypeError &&
            !(error is FileSystemException && error.osError?.errorCode == 2)) {
          rethrow;
        }
        // Interrupted writes and missing/invalid cached media are recoverable.
        if (!_readers.containsKey(id)) {
          await _remove(directory, id);
        }
      }
    }
    final known = clips.map((clip) => clip.id).toSet();
    for (final entity in entities) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      final suffix = [
        '.notes.json',
        '.notes.pending',
        '.pending',
        '.mp4',
      ].where((suffix) => name.endsWith(suffix)).firstOrNull;
      if (suffix == null) continue;
      final id = name.substring(0, name.length - suffix.length);
      if (_validId.hasMatch(id) &&
          !known.contains(id) &&
          !_readers.containsKey(id)) {
        await _deleteFile(entity);
      }
    }
    clips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return clips;
  }

  Future<void> _deleteFile(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> _remove(Directory directory, String id) async {
    // Delete the manifest first, so interrupted deletion never exposes a clip.
    await _deleteFile(File('${directory.path}/$id.json'));
    await _deleteFile(File('${directory.path}/$id.mp4'));
    await _deleteFile(File('${directory.path}/$id.pending'));
    await _deleteFile(File('${directory.path}/$id.notes.json'));
    await _deleteFile(File('${directory.path}/$id.notes.pending'));
  }

  @override
  Future<List<LocalClip>> list() => _serialize(_load);

  @override
  Future<LocalClip> add(
    String source,
    DateTime createdAt,
    Duration elapsed,
  ) async {
    try {
      return await _serialize((directory) async {
        final input = File(source);
        String? id;
        var committed = false;
        try {
          final size = await input.length();
          if (size <= 0 || size > maxClipBytes || elapsed.isNegative) {
            throw const ClipStorageException(
              'El clip está vacío o supera 64 MB. No se ha conservado.',
            );
          }
          final clips = await _load(directory);
          final victims = <LocalClip>[];
          var count = clips.length + 1;
          var bytes = clips.fold(size, (sum, clip) => sum + clip.bytes);
          for (final clip in clips.reversed) {
            if (count <= maxClips && bytes <= maxBytes) break;
            if (_readers.containsKey(clip.id)) continue;
            victims.add(clip);
            count--;
            bytes -= clip.bytes;
          }
          if (count > maxClips || bytes > maxBytes) {
            throw const ClipStorageException(
              'Los clips abiertos ocupan el espacio disponible. Cierra el reproductor y vuelve a intentarlo.',
            );
          }
          do {
            id = '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
          } while (await File('${directory.path}/$id.mp4').exists());
          final output = File('${directory.path}/$id.mp4');
          // Both locations are private caches, but support a different volume.
          try {
            await input.rename(output.path);
          } on FileSystemException {
            await input.copy(output.path);
          }
          final metadata = File('${directory.path}/$id.pending');
          await metadata.writeAsString(
            jsonEncode({
              'schema': 1,
              'createdAt': createdAt.toUtc().toIso8601String(),
              'elapsedUs': elapsed.inMicroseconds,
              'bytes': size,
            }),
            flush: true,
          );
          // A staged file may temporarily use up to maxClipBytes extra space.
          // Only evict after the new video and metadata have been written.
          for (final victim in victims) {
            await _remove(directory, victim.id);
          }
          await metadata.rename('${directory.path}/$id.json');
          committed = true;
          return LocalClip(
            id: id,
            path: output.path,
            createdAt: createdAt,
            elapsed: elapsed,
            bytes: size,
          );
        } finally {
          if (!committed && id != null) await _remove(directory, id);
        }
      });
    } finally {
      // Also clean up if resolving/creating the destination directory failed.
      await _deleteFile(File(source));
    }
  }

  @override
  Future<void> delete(String id) => _serialize((directory) async {
    if (!_validId.hasMatch(id)) throw ArgumentError.value(id, 'id');
    if (_readers.containsKey(id)) {
      throw const ClipStorageException('Cierra el clip antes de eliminarlo.');
    }
    await _remove(directory, id);
  });

  @override
  Future<LocalClip> acquire(String id) => _serialize((directory) async {
    final clips = await _load(directory);
    final clip = clips.where((clip) => clip.id == id).firstOrNull;
    if (clip == null) {
      throw const ClipStorageException(
        'Este clip temporal ya no está disponible.',
      );
    }
    _readers.update(id, (count) => count + 1, ifAbsent: () => 1);
    return clip;
  });

  @override
  Future<void> release(String id) => _enqueue(() async {
    final count = _readers[id];
    if (count == null) return;
    if (count > 1) {
      _readers[id] = count - 1;
    } else {
      _readers.remove(id);
    }
  });

  Future<void> _requireClip(Directory directory, String id) async {
    if (!_validId.hasMatch(id)) throw ArgumentError.value(id, 'id');
    if (!(await _load(directory)).any((clip) => clip.id == id)) {
      throw const ClipStorageException(
        'Este clip temporal ya no está disponible.',
      );
    }
  }

  @override
  Future<List<VideoAnnotation>> annotations(String id) => _serialize((
    directory,
  ) async {
    await _requireClip(directory, id);
    final file = File('${directory.path}/$id.notes.json');
    if (!await file.exists()) return [];
    if (await file.length() > 64 * 1024) {
      throw const FormatException('Annotations too large');
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final notes = json['notes'] as List;
    if (json['schema'] != 1 || notes.length > 100) {
      throw const FormatException('Invalid annotations');
    }
    return [
      for (final value in notes)
        VideoAnnotation.fromJson(value as Map<String, dynamic>),
    ];
  });

  @override
  Future<void> saveAnnotations(String id, List<VideoAnnotation> notes) =>
      _serialize((directory) async {
        await _requireClip(directory, id);
        if (notes.length > 100) {
          throw const ClipStorageException(
            'Hay un máximo de 100 dibujos por clip.',
          );
        }
        final data = jsonEncode({
          'schema': 1,
          'notes': notes.map((note) => note.toJson()).toList(),
        });
        if (utf8.encode(data).length > 64 * 1024) {
          throw const ClipStorageException(
            'Los dibujos superan el tamaño permitido.',
          );
        }
        final pending = File('${directory.path}/$id.notes.pending');
        try {
          await pending.writeAsString(data, flush: true);
          await pending.rename('${directory.path}/$id.notes.json');
        } finally {
          await _deleteFile(pending);
        }
      });
}
