import 'dart:async';

import 'package:acrostella_analytics/src/capture/capture_device.dart';
import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/clips/video_annotation.dart';

class RecordingCamera implements VideoCaptureDevice {
  final events = <String>[];
  Completer<void>? starting;
  Completer<String>? stopping;
  bool failStart = false;
  bool failStop = false;

  int count(String event) => events.where((entry) => entry == event).length;

  @override
  Future<CaptureFormat> open() async {
    events.add('open');
    return const CaptureFormat(width: 1920, height: 1080, cameraName: 'fake');
  }

  @override
  Future<void> close() async => events.add('close');

  @override
  Future<void> startRecording() async {
    events.add('record');
    if (failStart) throw StateError('native start failed');
    await starting?.future;
  }

  @override
  Future<String> stopRecording() async {
    events.add('finalize');
    if (failStop) throw StateError('native finalization failed');
    return stopping?.future ?? 'fake-native.mp4';
  }
}

class MemoryClipStore implements ClipStore {
  final savedNotes = <String, List<VideoAnnotation>>{};
  final clips = <LocalClip>[];
  final readers = <String, int>{};
  int writes = 0;
  bool failWrite = false;
  bool failList = false;
  Completer<void>? loading;

  @override
  Future<List<LocalClip>> list() async {
    await loading?.future;
    if (failList) throw StateError('storage unavailable');
    return List.of(clips);
  }

  @override
  Future<LocalClip> add(
    String source,
    DateTime createdAt,
    Duration elapsed,
  ) async {
    writes++;
    if (failWrite) throw const ClipStorageException('Sin espacio disponible.');
    final clip = LocalClip(
      id: 'clip-$writes',
      path: source,
      createdAt: createdAt,
      elapsed: elapsed,
      bytes: 100,
    );
    clips.add(clip);
    return clip;
  }

  @override
  Future<void> delete(String id) async {
    if (readers.containsKey(id)) throw StateError('decoder still reading');
    clips.removeWhere((clip) => clip.id == id);
    savedNotes.remove(id);
  }

  @override
  Future<LocalClip> acquire(String id) async {
    readers.update(id, (count) => count + 1, ifAbsent: () => 1);
    return clips.firstWhere((clip) => clip.id == id);
  }

  @override
  Future<void> release(String id) async {
    final count = readers[id] ?? 0;
    if (count > 1) {
      readers[id] = count - 1;
    } else {
      readers.remove(id);
    }
  }

  @override
  Future<List<VideoAnnotation>> annotations(String id) async =>
      List.of(savedNotes[id] ?? []);

  @override
  Future<void> saveAnnotations(String id, List<VideoAnnotation> notes) async {
    savedNotes[id] = List.of(notes);
  }

  @override
  Future<LocalClip> updateDetails(
    String id, {
    bool? saved,
    String? name,
    String? memo,
    bool? favorite,
    List<Duration>? markers,
  }) async {
    if (failWrite) throw const ClipStorageException('Sin espacio disponible.');
    final index = clips.indexWhere((clip) => clip.id == id);
    final next = clips[index].copyWith(
      saved: saved,
      name: name,
      memo: memo,
      favorite: favorite,
      markers: markers,
    );
    clips[index] = next;
    return next;
  }
}
