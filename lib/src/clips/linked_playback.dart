import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Shared media timeline with measured decoder drift, not a guarantee of
/// simultaneous physical display or sensor exposure on different cameras.
class LinkedPlayback extends ChangeNotifier {
  LinkedPlayback(this.primary, this.secondary, {required this.offsetUs}) {
    primary.addListener(_observe);
    secondary.addListener(_observe);
    _monitor = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(_sample()),
    );
  }
  final VideoPlayerController primary, secondary;
  int offsetUs;
  int driftMs = 0;
  bool _busy = false, _disposed = false, _playing = false, _sampling = false;
  int _generation = 0;
  late final Timer _monitor;
  Future<void> _pending = Future.value();
  DateTime _lastCorrection = DateTime.fromMillisecondsSinceEpoch(0);
  String? error;
  Duration get start => Duration(microseconds: math.max(0, -offsetUs));
  Duration get end => Duration(
    microseconds: math.min(
      primary.value.duration.inMicroseconds,
      secondary.value.duration.inMicroseconds - offsetUs,
    ),
  );
  bool get hasOverlap => end > start;
  Duration clamp(Duration p) => Duration(
    microseconds: p.inMicroseconds.clamp(
      start.inMicroseconds,
      math.max(start.inMicroseconds, end.inMicroseconds),
    ),
  );
  Duration other(Duration p) =>
      Duration(microseconds: p.inMicroseconds + offsetUs);
  Future<void> _both(Future<void> Function(VideoPlayerController) action) =>
      Future.wait([action(primary), action(secondary)]);
  Future<void> _enqueue(Future<void> Function() action) {
    _generation++;
    final next = _pending.then((_) async {
      if (_disposed) return;
      _busy = true;
      try {
        await action();
      } finally {
        _busy = false;
      }
    });
    _pending = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _pauseNative() async {
    _playing = false;
    await _both((c) => c.pause());
  }

  Future<void> _seekNative(Duration at) async {
    final p = clamp(at);
    await Future.wait([primary.seekTo(p), secondary.seekTo(other(p))]);
  }

  Future<void> pause() => _enqueue(_pauseNative);
  Future<void> seek(Duration at) => _enqueue(() async {
    await _pauseNative();
    await _seekNative(at);
  });
  Future<void> _playNative() async {
    if (!hasOverlap) throw StateError('No shared interval');
    await _pauseNative();
    await _seekNative(
      primary.value.position >= end ? start : primary.value.position,
    );
    await secondary.setPlaybackSpeed(primary.value.playbackSpeed);
    try {
      await _both((c) => c.play());
      _playing = true;
    } catch (_) {
      await _pauseNative();
      rethrow;
    }
  }

  Future<void> play() => _enqueue(_playNative);
  Future<void> speed(double speed) => _enqueue(() async {
    final resume = _playing;
    await _pauseNative();
    await _both((c) => c.setPlaybackSpeed(speed));
    if (resume) await _playNative();
  });
  Future<void> align(int value) => _enqueue(() async {
    final newStart = math.max(0, -value),
        newEnd = math.min(
          primary.value.duration.inMicroseconds,
          secondary.value.duration.inMicroseconds - value,
        );
    if (value.abs() > 30000000 || newEnd <= newStart) {
      throw StateError('No shared interval');
    }
    await _pauseNative();
    offsetUs = value;
    await _seekNative(primary.value.position);
    if (!_disposed) notifyListeners();
  });
  void _observe() {
    if (_disposed || _busy || !_playing) return;
    if (primary.value.hasError ||
        secondary.value.hasError ||
        primary.value.isBuffering ||
        secondary.value.isBuffering ||
        primary.value.position >= end) {
      _playing = false;
      unawaited(
        pause().catchError((Object _) {
          error = 'Reproducción interrumpida.';
        }),
      );
    }
  }

  Future<void> _sample() async {
    if (_disposed || _busy || !_playing || _sampling) return;
    _sampling = true;
    final generation = _generation;
    final elapsed = Stopwatch()..start();
    try {
      final positions = await Future.wait([
        primary.position,
        secondary.position,
      ]);
      if (_disposed ||
          _busy ||
          !_playing ||
          generation != _generation ||
          positions.any((p) => p == null) ||
          elapsed.elapsedMilliseconds > 80) {
        return;
      }
      driftMs =
          ((positions[1]!.inMicroseconds -
                      positions[0]!.inMicroseconds -
                      offsetUs) /
                  1000)
              .round();
      if (driftMs.abs() > 80 &&
          DateTime.now().difference(_lastCorrection) >
              const Duration(seconds: 1)) {
        _lastCorrection = DateTime.now();
        final at = positions[0]!;
        await _enqueue(() async {
          await _pauseNative();
          await _seekNative(at);
          await _playNative();
        });
      }
      if (!_disposed) notifyListeners();
    } catch (_) {
      error =
          'No se pudo alinear la reproducción. Pausa y vuelve a intentarlo.';
      if (!_disposed) notifyListeners();
    } finally {
      _sampling = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _monitor.cancel();
    primary.removeListener(_observe);
    secondary.removeListener(_observe);
    super.dispose();
  }
}
