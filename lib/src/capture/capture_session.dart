import 'dart:async';

import 'package:flutter/foundation.dart';

import '../clips/clip_store.dart';
import 'capture_device.dart';

enum CaptureStatus { idle, opening, live, suspended, failed }

enum ClipRecordingStatus { idle, starting, recording, finishing }

/// Application-owned camera lifecycle, independent of the visible layout.
class CaptureSession extends ChangeNotifier {
  CaptureSession(
    this._device, {
    this.clips,
    this.maxClipDuration = const Duration(seconds: 30),
  }) {
    if (maxClipDuration <= Duration.zero) {
      throw ArgumentError.value(maxClipDuration, 'maxClipDuration');
    }
  }

  final CaptureDevice _device;
  final ClipStore? clips;
  final Duration maxClipDuration;
  Future<void> _pending = Future<void>.value();
  bool _requested = false;
  bool _foreground = true;
  bool _opened = false;
  bool _disposed = false;

  CaptureStatus _status = CaptureStatus.idle;
  CaptureStatus get status => _status;
  CaptureFormat? _format;
  CaptureFormat? get format => _format;
  CaptureFailure? _failure;
  CaptureFailure? get failure => _failure;

  ClipRecordingStatus _recordingStatus = ClipRecordingStatus.idle;
  ClipRecordingStatus get recordingStatus => _recordingStatus;
  bool get isRecording => _recordingStatus == ClipRecordingStatus.recording;
  bool get clipBusy => _recordingStatus != ClipRecordingStatus.idle;
  bool get canRecord =>
      !_disposed &&
      _foreground &&
      _requested &&
      _status == CaptureStatus.live &&
      !clipBusy &&
      _device is VideoCaptureDevice &&
      clips != null;
  final _clipClock = Stopwatch();
  Duration get clipElapsed => _clipClock.elapsed;
  Timer? _clipLimit;
  Timer? _clipTick;
  bool _nativeRecording = false;
  bool _finishQueued = false;
  DateTime? _clipStartedAt;
  String? _clipMessage;
  String? get clipMessage => _clipMessage;
  LocalClip? _completedClip;
  LocalClip? takeCompletedExercise() {
    final clip = _completedClip;
    _completedClip = null;
    return clip;
  }

  Future<void> startClip() {
    if (!canRecord) return Future<void>.value();
    _recordingStatus = ClipRecordingStatus.starting;
    _clipMessage = null;
    _notify();
    return _enqueue(() async {
      if (!_requested || !_foreground || _disposed || !_opened) {
        _recordingStatus = ClipRecordingStatus.idle;
        _notify();
        return;
      }
      // Storage failure does not require closing a healthy preview owner.
      try {
        await clips!.list();
      } catch (_) {
        _recordingStatus = ClipRecordingStatus.idle;
        _clipMessage = 'No se pudo preparar el almacenamiento temporal.';
        _notify();
        return;
      }
      if (!_requested || !_foreground || _disposed || !_opened) {
        _recordingStatus = ClipRecordingStatus.idle;
        _notify();
        return;
      }
      try {
        await (_device as VideoCaptureDevice).startRecording();
        _nativeRecording = true;
        _clipStartedAt = DateTime.now();
        _clipClock
          ..reset()
          ..start();
        _recordingStatus = ClipRecordingStatus.recording;
        if (!_requested || !_foreground || _disposed) {
          await _finishClip(interrupted: true);
        } else {
          _clipLimit = Timer(maxClipDuration, () {
            unawaited(finishClip());
          });
          _clipTick = Timer.periodic(
            const Duration(seconds: 1),
            (_) => _notify(),
          );
          _notify();
        }
      } catch (_) {
        // A native start may have partially allocated an encoder. Close this
        // owner before allowing a manual reopen; never open a second camera.
        await _failRecording(
          'No se pudo iniciar el clip. Vuelve a activar la cámara.',
        );
      }
    });
  }

  Future<void> finishClip() {
    if (_disposed || !clipBusy || _finishQueued) return Future<void>.value();
    _finishQueued = true;
    return _enqueue(() async {
      try {
        await _finishClip();
      } finally {
        _finishQueued = false;
      }
    });
  }

  void _cancelClipTimers() {
    _clipLimit?.cancel();
    _clipTick?.cancel();
    _clipLimit = null;
    _clipTick = null;
    _clipClock.stop();
  }

  Future<void> _failRecording(String message) async {
    _cancelClipTimers();
    _requested = false;
    try {
      await _device.close();
    } catch (_) {
      // Still expose the recording failure and prevent reuse of this owner.
    }
    _nativeRecording = false;
    _opened = false;
    _format = null;
    _recordingStatus = ClipRecordingStatus.idle;
    _clipMessage = message;
    _failure = CaptureFailure('recording_failed', message);
    _update(CaptureStatus.failed);
  }

  Future<void> _finishClip({bool interrupted = false}) async {
    if (!_nativeRecording) return;
    _cancelClipTimers();
    _recordingStatus = ClipRecordingStatus.finishing;
    _notify();
    String source;
    try {
      source = await (_device as VideoCaptureDevice).stopRecording();
      _nativeRecording = false;
    } catch (_) {
      await _failRecording(
        'No se pudo finalizar el vídeo. Vuelve a activar la cámara.',
      );
      return;
    }
    try {
      _completedClip = await clips!.add(
        source,
        _clipStartedAt!,
        _clipClock.elapsed,
      );
      _clipMessage = interrupted
          ? 'Ejercicio interrumpido. Puedes revisarlo en la biblioteca.'
          : 'Ejercicio listo para revisar.';
    } on ClipStorageException catch (error) {
      _clipMessage = error.message;
    } catch (_) {
      _clipMessage =
          'No se pudo conservar el clip. Comprueba el espacio disponible.';
    } finally {
      _recordingStatus = ClipRecordingStatus.idle;
      _notify();
    }
  }

  Future<void> start() {
    if (_disposed) return Future<void>.value();
    _requested = true;
    return _schedule();
  }

  Future<void> stop() {
    if (_disposed) return Future<void>.value();
    _requested = false;
    _failure = null;
    return _schedule();
  }

  Future<void> setForeground(bool foreground) {
    if (_disposed) return Future<void>.value();
    _foreground = foreground;
    return _schedule();
  }

  Future<void> _schedule() {
    // Serializes native calls, including a lifecycle event during permission UI.
    return _enqueue(_reconcile);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _pending.then((_) => operation());
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _reconcile() async {
    try {
      final shouldOpen = _requested && _foreground && !_disposed;
      if (!shouldOpen) {
        await _finishClip(interrupted: true);
        if (_opened) {
          try {
            await _device.close();
          } finally {
            _opened = false;
          }
        }
        _format = null;
        _update(
          _requested
              ? CaptureStatus.suspended
              : _failure != null
              ? CaptureStatus.failed
              : CaptureStatus.idle,
        );
        return;
      }
      if (_opened) return;

      _failure = null;
      _update(CaptureStatus.opening);
      _format = await _device.open();
      _opened = true;

      // A stop/dispose/background request can arrive while opening the camera.
      if (!_requested || !_foreground || _disposed) {
        try {
          await _device.close();
        } finally {
          _opened = false;
        }
        _format = null;
        _update(_requested ? CaptureStatus.suspended : CaptureStatus.idle);
      } else {
        _update(CaptureStatus.live);
      }
    } catch (error) {
      _requested = false;
      _format = null;
      _failure = error is CaptureFailure
          ? error
          : const CaptureFailure(
              'camera_error',
              'No se pudo abrir la cámara. Vuelve a intentarlo.',
            );
      _update(CaptureStatus.failed);
    }
  }

  void _update(CaptureStatus value) {
    _status = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelClipTimers();
    _requested = false;
    unawaited(_schedule());
    super.dispose();
  }
}
