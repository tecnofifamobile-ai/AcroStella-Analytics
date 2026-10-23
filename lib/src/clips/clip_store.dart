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
    this.saved = false,
    this.name = '',
    this.memo = '',
    this.favorite = false,
    this.markers = const [],
    this.session = '',
    this.tags = const [],
    this.secondaryPath,
    this.secondaryBytes = 0,
    this.offsetUs = 0,
    this.clockUncertaintyUs = 0,
  });

  final String id;
  final String path;
  final DateTime createdAt;
  // Monotonic control elapsed time, not a sensor timestamp or media duration.
  final Duration elapsed;
  final int bytes;
  final bool saved;
  final String name;
  final String memo;
  final bool favorite;
  final List<Duration> markers;
  final String session;
  final List<String> tags;
  final String? secondaryPath;
  final int secondaryBytes;
  final int offsetUs;
  final int clockUncertaintyUs;
  bool get hasSecondAngle => secondaryPath != null;

  LocalClip copyWith({
    bool? saved,
    String? name,
    String? memo,
    bool? favorite,
    List<Duration>? markers,
    String? session,
    List<String>? tags,
  }) => LocalClip(
    id: id,
    path: path,
    createdAt: createdAt,
    elapsed: elapsed,
    bytes: bytes,
    saved: saved ?? this.saved,
    name: name ?? this.name,
    memo: memo ?? this.memo,
    favorite: favorite ?? this.favorite,
    markers: List.unmodifiable(markers ?? this.markers),
    session: session ?? this.session,
    tags: List.unmodifiable(tags ?? this.tags),
    secondaryPath: secondaryPath,
    secondaryBytes: secondaryBytes,
    offsetUs: offsetUs,
    clockUncertaintyUs: clockUncertaintyUs,
  );
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
  Future<LocalClip> updateDetails(
    String id, {
    bool? saved,
    String? name,
    String? memo,
    bool? favorite,
    List<Duration>? markers,
  });
}

abstract interface class OrganizedClipStore {
  Future<LocalClip> organize(
    String id, {
    required String session,
    required List<String> tags,
  });
}

abstract interface class MultiAngleStore {
  Future<LocalClip> attachAngle(
    String id,
    String source, {
    required int offsetUs,
    required int clockUncertaintyUs,
  });
  Future<void> adjustOffset(String id, int offsetUs);
}

/// App-private durable library with a separately bounded pending collection.
/// Files in use by a player are pinned until that player has been disposed.
class FileClipStore implements ClipStore, OrganizedClipStore, MultiAngleStore {
  FileClipStore(
    this._directory, {
    this.maxClips = 3,
    this.maxBytes = 128 * 1024 * 1024,
    this.maxClipBytes = 64 * 1024 * 1024,
    this.maxSavedBytes = 2 * 1024 * 1024 * 1024,
    this.maxSavedClips = 200,
    this.durable = false,
    this.legacyDirectory,
  }) {
    if (maxClips < 1 ||
        maxClipBytes < 1 ||
        maxBytes < maxClipBytes ||
        maxSavedBytes < 1 ||
        maxSavedClips < 1) {
      throw ArgumentError('Invalid clip storage limits');
    }
  }

  final Future<Directory> Function() _directory;
  final int maxClips;
  final int maxBytes;
  final int maxClipBytes;
  final int maxSavedBytes;
  final int maxSavedClips;
  final bool durable;
  final Future<Directory> Function()? legacyDirectory;
  bool _migrated = false;
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
        await _migrate(directory);
        return operation(directory);
      });

  static final _validId = RegExp(r'^\d+_\d+$');

  Future<void> _migrate(Directory destination) async {
    if (_migrated || legacyDirectory == null) return;
    final marker = File('${destination.path}/.imported-v03');
    if (!await marker.exists()) {
      final legacy = await legacyDirectory!();
      if (legacy.path != destination.path && await legacy.exists()) {
        for (final clip in await _load(legacy)) {
          if (await File('${destination.path}/${clip.id}.json').exists()) {
            continue;
          }
          await File(clip.path).copy('${destination.path}/${clip.id}.mp4');
          final notes = File('${legacy.path}/${clip.id}.notes.json');
          if (await notes.exists()) {
            await notes.copy('${destination.path}/${clip.id}.notes.json');
          }
          // Publish the manifest last; leave the original cache untouched.
          final staged = await File('${legacy.path}/${clip.id}.json')
              .copy('${destination.path}/${clip.id}.pending');
          await staged.rename('${destination.path}/${clip.id}.json');
        }
      }
      await marker.writeAsString('1', flush: true);
    }
    _migrated = true;
  }

  Future<List<LocalClip>> _load(Directory directory) async {
    final clips = <LocalClip>[];
    final entities = await directory.list(followLinks: false).toList();
    for (final entity in entities) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File || !name.endsWith('.json')) continue;
      final id = name.substring(0, name.length - 5);
      if (!_validId.hasMatch(id)) continue;
      try {
        if (await entity.length() > 16 * 1024) {
          throw const FormatException('Invalid manifest size');
        }
        final data =
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final video = File('${directory.path}/$id.mp4');
        final stat = await video.stat();
        final elapsed = data['elapsedUs'] as int;
        final angleBytes = data['secondaryBytes'] as int? ?? 0;
        final angle = File('${directory.path}/$id.angle.mp4');
        if (angleBytes < 0 ||
            angleBytes > maxClipBytes ||
            (angleBytes > 0 &&
                (!await angle.exists() ||
                    await angle.length() != angleBytes))) {
          throw const FormatException('Invalid second angle');
        }
        if (data['schema'] != 1 ||
            stat.type != FileSystemEntityType.file ||
            stat.size <= 0 ||
            stat.size > maxClipBytes ||
            stat.size + angleBytes != data['bytes'] ||
            elapsed < 0) {
          throw const FormatException('Invalid clip');
        }
        clips.add(
          LocalClip(
            id: id,
            path: video.path,
            createdAt: DateTime.parse(data['createdAt'] as String),
            elapsed: Duration(microseconds: elapsed),
            bytes: stat.size + angleBytes,
            secondaryPath: angleBytes > 0 ? angle.path : null,
            secondaryBytes: angleBytes,
            offsetUs: _offset(data['offsetUs']),
            clockUncertaintyUs: _uncertainty(data['clockUncertaintyUs']),
            session: _text(data['session'], 80),
            tags: _tags(data['tags']),
            saved: data['saved'] == true,
            name: _text(data['name'], 80),
            memo: _text(data['memo'], 2000),
            favorite: data['favorite'] == true,
            markers: _markers(data['markers']),
          ),
        );
      } catch (error) {
        if (error is! FormatException &&
            error is! TypeError &&
            !(error is FileSystemException && error.osError?.errorCode == 2)) {
          rethrow;
        }
        // Interrupted writes and missing/invalid cached media are recoverable.
        if (!durable && !_readers.containsKey(id)) {
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
      if (!durable &&
          _validId.hasMatch(id) &&
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
    await _deleteFile(File('${directory.path}/$id.angle.mp4'));
    await _deleteFile(File('${directory.path}/$id.angle.pending'));
    await _deleteFile(File('${directory.path}/$id.pending'));
    await _deleteFile(File('${directory.path}/$id.notes.json'));
    await _deleteFile(File('${directory.path}/$id.notes.pending'));
    // Migration keeps a safety copy until the exercise is intentionally
    // deleted (or evicted as pending). Remove that copy at the same time.
    if (durable && legacyDirectory != null) {
      final legacy = await legacyDirectory!();
      if (legacy.path != directory.path) {
        for (final suffix in [
          '.json',
          '.mp4',
          '.pending',
          '.notes.json',
          '.notes.pending',
        ]) {
          await _deleteFile(File('${legacy.path}/$id$suffix'));
        }
      }
    }
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
              'El vídeo está vacío o supera el límite de almacenamiento.',
            );
          }
          final clips = await _load(directory);
          final victims = <LocalClip>[];
          final pending = clips.where((clip) => !clip.saved).toList();
          var count = pending.length + 1;
          var bytes = pending.fold(size, (sum, clip) => sum + clip.bytes);
          for (final clip in pending.reversed) {
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
      throw const ClipStorageException(
        'Cierra el ejercicio antes de eliminarlo.',
      );
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

  static String _text(Object? value, int limit) {
    if (value == null) return '';
    if (value is! String || value.length > limit) {
      throw const FormatException('Invalid text');
    }
    return value;
  }

  static List<Duration> _markers(Object? value) {
    if (value == null) return const [];
    if (value is! List ||
        value.length > 50 ||
        value.any((v) => v is! int || v < 0 || v > 24 * 60 * 60 * 1000)) {
      throw const FormatException('Invalid markers');
    }
    return List.unmodifiable(
      value.cast<int>().map((v) => Duration(milliseconds: v)),
    );
  }

  @override
  Future<LocalClip> updateDetails(
    String id, {
    bool? saved,
    String? name,
    String? memo,
    bool? favorite,
    List<Duration>? markers,
  }) => _serialize((directory) async {
    final clips = await _load(directory);
    final clip = clips.where((clip) => clip.id == id).firstOrNull;
    if (clip == null) {
      throw const ClipStorageException('Este ejercicio ya no está disponible.');
    }
    final next = clip.copyWith(
      saved: saved,
      name: name?.trim(),
      memo: memo?.trim(),
      favorite: favorite,
      markers: markers,
    );
    _text(next.name, 80);
    _text(next.memo, 2000);
    _markers(next.markers.map((m) => m.inMilliseconds).toList());
    if (clip.saved && saved == false) {
      throw const ClipStorageException(
        'Para retirar un ejercicio guardado, utiliza Eliminar.',
      );
    }
    final others = clips.where((c) => c.saved && c.id != id).toList();
    if (next.saved &&
        (others.length >= maxSavedClips ||
            others.fold(next.bytes, (sum, c) => sum + c.bytes) >
                maxSavedBytes)) {
      throw const ClipStorageException(
        'Biblioteca llena. Elimina algún ejercicio guardado para liberar espacio.',
      );
    }
    final pending = File('${directory.path}/$id.pending');
    try {
      await pending.writeAsString(
        jsonEncode({
          'schema': 1,
          'createdAt': next.createdAt.toUtc().toIso8601String(),
          'elapsedUs': next.elapsed.inMicroseconds,
          'bytes': next.bytes,
          'saved': next.saved,
          'name': next.name,
          'memo': next.memo,
          'favorite': next.favorite,
          'markers': next.markers.map((m) => m.inMilliseconds).toList(),
          'session': next.session,
          'tags': next.tags,
          'secondaryBytes': next.secondaryBytes,
          'offsetUs': next.offsetUs,
          'clockUncertaintyUs': next.clockUncertaintyUs,
        }),
        flush: true,
      );
      await pending.rename('${directory.path}/$id.json');
    } finally {
      await _deleteFile(pending);
    }
    return next;
  });

  @override
  Future<List<VideoAnnotation>> annotations(String id) => _serialize((
    directory,
  ) async {
    await _requireClip(directory, id);
    final file = File('${directory.path}/$id.notes.json');
    if (!await file.exists()) return [];
    if (await file.length() > 512 * 1024) {
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
            'Hay un máximo de 100 dibujos por ejercicio.',
          );
        }
        final data = jsonEncode({
          'schema': 1,
          'notes': notes.map((note) => note.toJson()).toList(),
        });
        if (utf8.encode(data).length > 512 * 1024) {
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
  static int _offset(Object? value) {
    if (value == null) return 0;
    if (value is! int || value.abs() > 30000000) {
      throw const FormatException('Invalid offset');
    }
    return value;
  }

  static int _uncertainty(Object? value) {
    if (value == null) return 0;
    if (value is! int || value < 0 || value > 30000000) {
      throw const FormatException('Invalid uncertainty');
    }
    return value;
  }

  static List<String> _tags(Object? value) {
    if (value == null) return const [];
    if (value is! List || value.length > 8) {
      throw const FormatException('Invalid tags');
    }
    return List.unmodifiable(value.map((v) => _text(v, 32)));
  }

  Future<Map<String, dynamic>> _manifest(Directory dir, String id) async {
    await _requireClip(dir, id);
    return jsonDecode(await File('${dir.path}/$id.json').readAsString())
        as Map<String, dynamic>;
  }

  Future<void> _publish(
    Directory dir,
    String id,
    Map<String, dynamic> data,
  ) async {
    final stage = File('${dir.path}/$id.pending');
    try {
      await stage.writeAsString(jsonEncode(data), flush: true);
      await stage.rename('${dir.path}/$id.json');
    } finally {
      await _deleteFile(stage);
    }
  }

  @override
  Future<LocalClip> organize(
    String id, {
    required String session,
    required List<String> tags,
  }) => _serialize((dir) async {
    final data = await _manifest(dir, id);
    data['session'] = _text(session.trim(), 80);
    data['tags'] = _tags(
      tags.map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList(),
    );
    await _publish(dir, id, data);
    return (await _load(dir)).firstWhere((c) => c.id == id);
  });

  @override
  Future<void> adjustOffset(String id, int offsetUs) => _serialize((dir) async {
    final data = await _manifest(dir, id);
    if ((data['secondaryBytes'] as int? ?? 0) <= 0) {
      throw const ClipStorageException('No hay segundo ángulo.');
    }
    data['offsetUs'] = _offset(offsetUs);
    await _publish(dir, id, data);
  });

  @override
  Future<LocalClip> attachAngle(
    String id,
    String source, {
    required int offsetUs,
    required int clockUncertaintyUs,
  }) => _serialize((dir) async {
    final data = await _manifest(dir, id);
    if ((data['secondaryBytes'] as int? ?? 0) != 0) {
      throw const ClipStorageException('Este ejercicio ya tiene dos ángulos.');
    }
    _offset(offsetUs);
    _uncertainty(clockUncertaintyUs);
    final input = File(source);
    final size = await input.length();
    if (size <= 0 || size > maxClipBytes) {
      throw const ClipStorageException(
        'Segundo ángulo demasiado grande o vacío.',
      );
    }
    final clips = await _load(dir);
    final clip = clips.firstWhere((c) => c.id == id);
    var used = clips
        .where((c) => c.saved == clip.saved)
        .fold(0, (n, c) => n + c.bytes);
    final victims = <LocalClip>[];
    if (!clip.saved) {
      for (final candidate in clips.reversed.where(
        (c) => !c.saved && c.id != id && !_readers.containsKey(c.id),
      )) {
        if (used + size <= maxBytes) break;
        victims.add(candidate);
        used -= candidate.bytes;
      }
    }
    if (used + size > (clip.saved ? maxSavedBytes : maxBytes)) {
      throw const ClipStorageException(
        'No hay espacio para conservar ambos ángulos. Guarda o elimina otros ejercicios.',
      );
    }
    final staged = File('${dir.path}/$id.angle.pending');
    final output = File('${dir.path}/$id.angle.mp4');
    var committed = false;
    try {
      await input.copy(staged.path);
      await staged.rename(output.path);
      data['bytes'] = (data['bytes'] as int) + size;
      data['secondaryBytes'] = size;
      data['offsetUs'] = offsetUs;
      data['clockUncertaintyUs'] = clockUncertaintyUs;
      for (final victim in victims) {
        await _remove(dir, victim.id);
      }
      await _publish(dir, id, data);
      committed = true;
      return (await _load(dir)).firstWhere((c) => c.id == id);
    } finally {
      await _deleteFile(staged);
      if (!committed) await _deleteFile(output);
    }
  });

  /// Imports a fully validated record without evicting existing pending media.
  /// Publish its manifest last; a failed record never replaces another exercise.
  Future<LocalClip> importExercise(
    LocalClip metadata,
    List<VideoAnnotation> notes,
  ) => _serialize((dir) async {
    final clips = await _load(dir);
    final saved = clips.where((c) => c.saved).toList();
    if (saved.length >= maxSavedClips ||
        saved.fold(metadata.bytes, (n, c) => n + c.bytes) > maxSavedBytes) {
      throw const ClipStorageException(
        'Biblioteca llena. No se han sustituido ejercicios existentes.',
      );
    }
    _text(metadata.name, 80);
    _text(metadata.memo, 2000);
    _text(metadata.session, 80);
    _tags(metadata.tags);
    _offset(metadata.offsetUs);
    _uncertainty(metadata.clockUncertaintyUs);
    if (notes.length > 100) throw const FormatException('Too many annotations');
    final noteData = jsonEncode({
      'schema': 1,
      'notes': notes.map((n) => n.toJson()).toList(),
    });
    if (utf8.encode(noteData).length > 512 * 1024) {
      throw const FormatException('Annotations too large');
    }
    final primary = File(metadata.path);
    final mainBytes = await primary.length();
    if (mainBytes <= 0 ||
        mainBytes > maxClipBytes ||
        metadata.bytes != mainBytes + metadata.secondaryBytes) {
      throw const FormatException('Invalid media size');
    }
    if (metadata.hasSecondAngle &&
        (metadata.secondaryBytes <= 0 ||
            metadata.secondaryBytes > maxClipBytes ||
            await File(metadata.secondaryPath!).length() !=
                metadata.secondaryBytes)) {
      throw const FormatException('Invalid second angle');
    }
    String id;
    do {
      id = '${DateTime.now().microsecondsSinceEpoch}_${_sequence++}';
    } while (await File('${dir.path}/$id.mp4').exists());
    var committed = false;
    try {
      await primary.copy('${dir.path}/$id.mp4');
      if (metadata.hasSecondAngle) {
        await File(metadata.secondaryPath!).copy('${dir.path}/$id.angle.mp4');
      }
      await File('${dir.path}/$id.notes.json')
          .writeAsString(noteData, flush: true);
      await _publish(dir, id, {
        'schema': 1,
        'createdAt': metadata.createdAt.toUtc().toIso8601String(),
        'elapsedUs': metadata.elapsed.inMicroseconds,
        'bytes': metadata.bytes,
        'saved': true,
        'name': metadata.name,
        'memo': metadata.memo,
        'favorite': metadata.favorite,
        'markers': metadata.markers.map((m) => m.inMilliseconds).toList(),
        'session': metadata.session,
        'tags': metadata.tags,
        'secondaryBytes': metadata.secondaryBytes,
        'offsetUs': metadata.offsetUs,
        'clockUncertaintyUs': metadata.clockUncertaintyUs,
      });
      committed = true;
      return (await _load(dir)).firstWhere((c) => c.id == id);
    } finally {
      if (!committed) await _remove(dir, id);
    }
  });
}
