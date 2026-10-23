import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'capture_device.dart';

/// First local-camera adapter. Frames remain native for the texture preview.
/// WebRTC must not call getUserMedia on this camera while this owner is active.
class FlutterCameraDevice implements VideoCaptureDevice {
  CameraController? _controller;
  CameraController? get controller => _controller;

  @override
  Future<CaptureFormat> open() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      throw const CaptureFailure(
        'unsupported_platform',
        'Esta prueba de cámara está disponible en iPad y Android.',
      );
    }

    CameraController? candidate;
    try {
      final cameras = await availableCameras();
      final rear = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      if (rear.isEmpty) {
        throw const CaptureFailure(
          'rear_camera_unavailable',
          'No se ha encontrado una cámara trasera disponible.',
        );
      }
      candidate = CameraController(
        rear.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        fps: 30,
        videoBitrate: 8000000,
      );
      await candidate.initialize();
      final size = candidate.value.previewSize;
      if (size == null) {
        throw const CaptureFailure(
          'preview_unavailable',
          'La cámara no ha proporcionado una imagen disponible.',
        );
      }
      _controller = candidate;
      return CaptureFormat(
        width: size.width.round(),
        height: size.height.round(),
        cameraName: rear.first.name,
      );
    } on CameraException catch (error) {
      if (candidate != null) await candidate.dispose();
      throw _translate(error);
    } catch (_) {
      if (candidate != null) await candidate.dispose();
      rethrow;
    }
  }

  CaptureFailure _translate(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' => const CaptureFailure(
        'permission_denied',
        'Permite el acceso a la cámara para mostrar el entrenamiento.',
      ),
      'CameraAccessDeniedWithoutPrompt' => const CaptureFailure(
        'permission_settings',
        'Activa el permiso de cámara para AcroStella en Ajustes y vuelve aquí.',
      ),
      'CameraAccessRestricted' => const CaptureFailure(
        'permission_restricted',
        'El sistema tiene restringido el acceso a la cámara.',
      ),
      _ => CaptureFailure(
        error.code,
        'La cámara no está disponible (${error.code}). Vuelve a intentarlo.',
      ),
    };
  }

  @override
  Future<void> startRecording() async {
    final controller = _controller;
    if (controller == null) {
      throw const CaptureFailure('camera_closed', 'Activa primero la cámara.');
    }
    // Uses this controller's existing native capture owner, not getUserMedia
    // or an image stream in Dart. Background recording is not requested.
    await controller.startVideoRecording(enablePersistentRecording: false);
  }

  @override
  Future<String> stopRecording() async {
    final controller = _controller;
    if (controller == null) {
      throw const CaptureFailure('camera_closed', 'La cámara se ha cerrado.');
    }
    return (await controller.stopVideoRecording()).path;
  }

  @override
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
