import 'dart:async';

import 'package:flutter/foundation.dart';

import 'capture_device.dart';

enum CaptureStatus { idle, opening, live, suspended, failed }

/// Application-owned camera lifecycle, independent of the visible layout.
class CaptureSession extends ChangeNotifier {
  CaptureSession(this._device);

  final CaptureDevice _device;
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
    final next = _pending.then((_) => _reconcile());
    _pending = next;
    return next;
  }

  Future<void> _reconcile() async {
    try {
      final shouldOpen = _requested && _foreground && !_disposed;
      if (!shouldOpen) {
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
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _requested = false;
    unawaited(_schedule());
    super.dispose();
  }
}
