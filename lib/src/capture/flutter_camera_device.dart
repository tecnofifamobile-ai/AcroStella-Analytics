import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

import 'capture_device.dart';

/// The single native camera owner. One track feeds preview, the bounded native
/// MP4 writer and the LAN WebRTC sender. No raw video frames enter Dart.
class FlutterCameraDevice
    implements VideoCaptureDevice, FrameTimedCaptureDevice {
  MediaStream? _stream;
  RTCVideoRenderer? _renderer;
  MediaRecorder? _recorder;
  String? _path;
  MediaStream? get stream => _stream;
  bool get ready => _renderer?.renderVideo == true;
  Widget preview() => _renderer == null
      ? const SizedBox.shrink()
      : RTCVideoView(
          _renderer!,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        );

  @override
  Future<CaptureFormat> open() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      throw const CaptureFailure(
        'unsupported_platform',
        'La cámara está disponible en iPad y Android.',
      );
    }
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'environment',
          'width': 1920,
          'height': 1080,
          'frameRate': 30,
        },
      });
      _stream = stream;
      if (stream.getVideoTracks().length != 1) {
        throw const CaptureFailure(
          'camera_unavailable',
          'No se encontró una cámara trasera disponible.',
        );
      }
      final renderer = RTCVideoRenderer();
      _renderer = renderer;
      await renderer.initialize();
      renderer.srcObject = stream;
      final settings = stream.getVideoTracks().single.getSettings();
      return CaptureFormat(
        width: (settings['width'] as num?)?.round() ?? 1920,
        height: (settings['height'] as num?)?.round() ?? 1080,
        cameraName: stream.getVideoTracks().single.label ?? 'Cámara trasera',
      );
    } catch (error) {
      await close();
      if (error is CaptureFailure) rethrow;
      final permission =
          error.toString().toLowerCase().contains('permission') ||
          error.toString().contains('NotAllowed');
      throw CaptureFailure(
        permission ? 'permission_denied' : 'camera_unavailable',
        permission
            ? 'Permite la cámara en Ajustes y vuelve a intentarlo.'
            : 'No se pudo activar la cámara. Vuelve a intentarlo.',
      );
    }
  }

  @override
  Future<void> startRecording() async {
    final stream = _stream;
    if (stream == null || _recorder != null) {
      throw const CaptureFailure(
        'camera_closed',
        'Activa la cámara antes de grabar.',
      );
    }
    final directory = await getTemporaryDirectory();
    _path =
        '${directory.path}/acro-${DateTime.now().microsecondsSinceEpoch}.mp4';
    final recorder = MediaRecorder();
    _recorder = recorder;
    await recorder.start(_path!, videoTrack: stream.getVideoTracks().single);
    // Do not announce a recording until a native frame has actually reached
    // its encoder. An empty MP4 is never admitted to the exercise library.
    final deadline = Stopwatch()..start();
    while (deadline.elapsed < const Duration(seconds: 5)) {
      if (await firstFrameAgeUs() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 15));
    }
    throw const CaptureFailure(
      'no_recording_frames',
      'La cámara no pudo grabar imágenes. Actívala de nuevo.',
    );
  }

  @override
  Future<int?> firstFrameAgeUs() async {
    if (_path == null || _recorder == null) return null;
    final info = await WebRTC.invokeMethod<Map<dynamic, dynamic>, dynamic>(
      'recordingInfo',
      {'path': _path},
    );
    final age = info?['first_frame_age_us'];
    return age is num && age >= 0 ? age.round() : null;
  }

  @override
  Future<String> stopRecording() async {
    final recorder = _recorder, path = _path;
    if (recorder == null || path == null) {
      throw const CaptureFailure('no_recording', 'No hay un ejercicio activo.');
    }
    try {
      await recorder.stop().timeout(const Duration(seconds: 12));
    } finally {
      _recorder = null;
      _path = null;
    }
    return path;
  }

  @override
  Future<void> close() async {
    if (_recorder != null) {
      final abandoned = _path;
      try {
        await stopRecording();
      } catch (_) {
        /* Pending media stays private. */
      }
      if (abandoned != null) {
        try {
          final file = File(abandoned);
          if (await file.exists()) await file.delete();
        } catch (_) {
          /* OS may already have removed it. */
        }
      }
    }
    final stream = _stream, renderer = _renderer;
    _stream = null;
    _renderer = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }
    await renderer?.dispose();
  }
}
