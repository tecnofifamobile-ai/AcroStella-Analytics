import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'clip_store.dart';
import 'video_annotation.dart';

/// Streaming container of already-compressed media: bounded metadata followed
/// by length/hash checked blobs. No archive paths, executable files or ZIP bombs.
class ExerciseBackup {
  static final _magic = ascii.encode('ACROSTELLA1\n');
  static const maxBytes = 2 * 1024 * 1024 * 1024;
  static const maxVideo = 256 * 1024 * 1024;

  static Future<File> export(ClipStore store, File output) async {
    final clips = (await store.list()).where((c) => c.saved).toList();
    if (clips.isEmpty) {
      throw const ClipStorageException(
        'No hay ejercicios guardados para exportar.',
      );
    }
    final leased = <LocalClip>[];
    RandomAccessFile? writer;
    var done = false;
    try {
      for (final clip in clips) {
        leased.add(await store.acquire(clip.id));
      }
      final records = <Map<String, dynamic>>[];
      for (final c in leased) {
        final files = <Map<String, dynamic>>[];
        for (final path in [
          c.path,
          if (c.secondaryPath != null) c.secondaryPath!,
        ]) {
          final f = File(path);
          files.add({
            'bytes': await f.length(),
            'hash': (await sha256.bind(f.openRead()).first).toString(),
          });
        }
        records.add({
          'createdAt': c.createdAt.toIso8601String(),
          'elapsedUs': c.elapsed.inMicroseconds,
          'name': c.name,
          'memo': c.memo,
          'session': c.session,
          'tags': c.tags,
          'favorite': c.favorite,
          'markers': c.markers.map((m) => m.inMilliseconds).toList(),
          'offsetUs': c.offsetUs,
          'clockUncertaintyUs': c.clockUncertaintyUs,
          'notes': (await store.annotations(c.id))
              .map((n) => n.toJson())
              .toList(),
          'files': files,
        });
      }
      final manifest = utf8.encode(
        jsonEncode({'schema': 1, 'records': records}),
      );
      if (manifest.length > 20 * 1024 * 1024 ||
          leased.fold(0, (n, c) => n + c.bytes) > maxBytes) {
        throw const ClipStorageException('Copia demasiado grande.');
      }
      writer = await output.open(mode: FileMode.write);
      await writer.writeFrom(_magic);
      await writer.writeFrom(
        Uint8List(4)..buffer.asByteData().setUint32(0, manifest.length),
      );
      await writer.writeFrom(manifest);
      for (final c in leased) {
        for (final path in [
          c.path,
          if (c.secondaryPath != null) c.secondaryPath!,
        ]) {
          await for (final bytes in File(path).openRead()) {
            await writer.writeFrom(bytes);
          }
        }
      }
      await writer.flush();
      done = true;
      return output;
    } finally {
      try {
        await writer?.close();
      } finally {
        for (final c in leased) {
          await store.release(c.id);
        }
        if (!done && await output.exists()) await output.delete();
      }
    }
  }

  static Future<Uint8List> _read(RandomAccessFile file, int count) async {
    final data = await file.read(count);
    if (data.length != count) throw const FormatException('Incomplete backup');
    return data;
  }

  static Future<int> restore(
    FileClipStore store,
    File input,
    Directory staging,
  ) async {
    final length = await input.length();
    if (length < _magic.length + 4 ||
        length > maxBytes + 20 * 1024 * 1024 + 100) {
      throw const FormatException('Invalid backup size');
    }
    final reader = await input.open();
    final prepared = <(LocalClip, List<VideoAnnotation>)>[];
    var imported = 0;
    await staging.create(recursive: true);
    try {
      if (ascii.decode(await _read(reader, _magic.length)) !=
          ascii.decode(_magic)) {
        throw const FormatException('Invalid backup');
      }
      final headerLength = (await _read(
        reader,
        4,
      )).buffer.asByteData().getUint32(0);
      if (headerLength < 1 || headerLength > 20 * 1024 * 1024) {
        throw const FormatException('Invalid manifest size');
      }
      final header = jsonDecode(
        utf8.decode(await _read(reader, headerLength)),
      ) as Map<String, dynamic>;
      final records = header['records'] as List;
      if (header['schema'] != 1 || records.isEmpty || records.length > 200) {
        throw const FormatException('Invalid records');
      }
      var total = 0;
      for (var i = 0; i < records.length; i++) {
        final r = records[i] as Map<String, dynamic>;
        final files = r['files'] as List;
        if (files.isEmpty || files.length > 2) {
          throw const FormatException('Invalid angles');
        }
        final paths = <String>[];
        final sizes = <int>[];
        for (var a = 0; a < files.length; a++) {
          final f = files[a] as Map<String, dynamic>;
          final size = f['bytes'] as int;
          total += size;
          if (size <= 0 ||
              size > maxVideo ||
              total > maxBytes ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(f['hash'] as String)) {
            throw const FormatException('Invalid media');
          }
          final path = '${staging.path}/$i-$a.mp4';
          final writer = await File(path).open(mode: FileMode.write);
          try {
            var left = size;
            while (left > 0) {
              final bytes = await _read(reader, math.min(64 * 1024, left));
              await writer.writeFrom(bytes);
              left -= bytes.length;
            }
          } finally {
            await writer.close();
          }
          if ((await sha256.bind(File(path).openRead()).first).toString() !=
              f['hash']) {
            throw const FormatException('Media hash mismatch');
          }
          paths.add(path);
          sizes.add(size);
        }
        String text(String key, int max) {
          final s = r[key] as String;
          if (s.length > max) throw const FormatException('Invalid text');
          return s;
        }

        final tags = (r['tags'] as List).cast<String>();
        final markers = (r['markers'] as List).cast<int>();
        final offset = r['offsetUs'] as int,
            uncertainty = r['clockUncertaintyUs'] as int,
            elapsed = r['elapsedUs'] as int;
        if (tags.length > 8 ||
            tags.any((t) => t.length > 32) ||
            markers.length > 50 ||
            markers.any((m) => m < 0 || m > 86400000) ||
            offset.abs() > 30000000 ||
            uncertainty < 0 ||
            uncertainty > 30000000 ||
            elapsed < 0 ||
            elapsed > 86400000000) {
          throw const FormatException('Invalid metadata');
        }
        final notes = (r['notes'] as List)
            .map((n) => VideoAnnotation.fromJson(n as Map<String, dynamic>))
            .toList();
        if (notes.length > 100 ||
            utf8.encode(jsonEncode(r['notes'])).length > 512 * 1024) {
          throw const FormatException('Invalid annotations');
        }
        final clip = LocalClip(
          id: '',
          path: paths.first,
          createdAt: DateTime.parse(r['createdAt'] as String),
          elapsed: Duration(microseconds: elapsed),
          bytes: sizes.reduce((a, b) => a + b),
          saved: true,
          name: text('name', 80),
          memo: text('memo', 2000),
          session: text('session', 80),
          tags: tags,
          favorite: r['favorite'] == true,
          markers: markers.map((m) => Duration(milliseconds: m)).toList(),
          secondaryPath: paths.length == 2 ? paths.last : null,
          secondaryBytes: sizes.length == 2 ? sizes.last : 0,
          offsetUs: offset,
          clockUncertaintyUs: uncertainty,
        );
        prepared.add((clip, notes));
      }
      if (await reader.position() != length) {
        throw const FormatException('Unexpected trailing data');
      }
      final existing = (await store.list()).where((c) => c.saved).toList();
      if (existing.length + prepared.length > store.maxSavedClips ||
          existing.fold(total, (n, c) => n + c.bytes) > store.maxSavedBytes) {
        throw const ClipStorageException(
          'No hay espacio para importar la copia completa. Tus ejercicios actuales se conservan.',
        );
      }
      for (final (clip, notes) in prepared) {
        await store.importExercise(clip, notes);
        imported++;
      }
      return imported;
    } catch (_) {
      if (imported > 0) {
        throw ClipStorageException(
          'Importados $imported ejercicios. La operación se interrumpió; los existentes se conservan.',
        );
      }
      rethrow;
    } finally {
      await reader.close();
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
}
