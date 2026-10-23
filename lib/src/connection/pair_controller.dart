import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../capture/capture_session.dart';
import '../clips/clip_store.dart';
import 'secure_channel.dart';

class PairController extends ChangeNotifier {
  PairController(this.capture, this.temporaryDirectory) {
    capture.addListener(_captureChanged);
  }
  final CaptureSession capture;
  final Future<Directory> Function() temporaryDirectory;
  final clock = Stopwatch()..start();
  ServerSocket? _server;
  SecureChannel? _channel;
  bool _disposed = false,
      _candidate = false,
      _recording = false,
      _sending = false;
  Timer? _heartbeat;
  bool get transferPending => _run != null && !_recording && !hosting;
  bool busy = false, hosting = false;
  String status =
      'Conecta ambos dispositivos a la misma Wi-Fi o al hotspot del Android.';
  String? invitation;
  List<String> invitations = [];
  double progress = 0;
  ClockEstimate? estimate;
  int _serial = 0, _startBefore = 0, _startAfter = 0;
  int? _remoteBefore, _remoteAfter;
  LocalClip? _hostClip, _localClip, _completed;
  String? _run;
  final _requests = <int, Completer<Map<String, dynamic>>>{};
  RandomAccessFile? _receiving;
  File? _receivedFile;
  String? _transferLease;
  int _expectedBytes = 0, _receivedBytes = 0;
  int _attempts = 0;
  DateTime _attemptWindow = DateTime.now();
  bool get connected => _channel != null;
  bool get satellite => hosting;
  bool get managesCapture => hosting || _run != null || busy;
  bool get recording => _recording;
  LocalClip? takeCompleted() {
    final c = _completed;
    _completed = null;
    return c;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static bool localAddress(String host) {
    final ip = InternetAddress.tryParse(host);
    if (ip == null || ip.type != InternetAddressType.IPv4) return false;
    final p = ip.rawAddress;
    return p[0] == 10 ||
        p[0] == 127 ||
        (p[0] == 192 && p[1] == 168) ||
        (p[0] == 172 && p[1] >= 16 && p[1] <= 31) ||
        (p[0] == 169 && p[1] == 254);
  }

  Future<void> host() async {
    if (capture.clipBusy || busy) return;
    await disconnect();
    busy = true;
    hosting = true;
    _notify();
    try {
      await capture.start();
      if (!capture.canRecord) throw const SocketException('Camera unavailable');
      final code = SecureChannel.newCode();
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      invitations = [
        for (final interface in interfaces)
          for (final ip in interface.addresses)
            if (localAddress(ip.address) && !ip.isLoopback)
              'acrostella://${ip.address}:${_server!.port}/$code',
      ];
      if (invitations.isEmpty) throw const SocketException('No local network');
      invitation = invitations.first;
      status = 'Cámara preparada. Introduce el enlace en el iPad. No compartas este código fuera de tu sesión.';
      _server!.listen((socket) async {
        if (DateTime.now().difference(_attemptWindow) >
            const Duration(minutes: 1)) {
          _attemptWindow = DateTime.now();
          _attempts = 0;
        }
        if (_candidate || connected || ++_attempts > 10) {
          socket.destroy();
          return;
        }
        _candidate = true;
        try {
          final channel = await SecureChannel.connect(
            socket,
            code,
            server: true,
          );
          if (_server == null || _disposed) {
            channel.close();
            return;
          }
          _channel = channel;
          invitation = null;
          invitations = [];
          status = 'iPad conectado · cámara preparada';
          _notify();
          unawaited(_listen(channel));
        } catch (_) {
          socket.destroy();
        } finally {
          _candidate = false;
        }
      });
    } catch (_) {
      await disconnect();
      status = 'No se pudo preparar la cámara. Comprueba la Wi-Fi y el permiso de cámara.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> join(String invitation) async {
    if (capture.clipBusy || busy) return;
    await disconnect();
    busy = true;
    _notify();
    try {
      final uri = Uri.parse(invitation.trim());
      if (uri.scheme != 'acrostella' ||
          !localAddress(uri.host) ||
          !uri.hasPort ||
          uri.port < 1 ||
          uri.port > 65535 ||
          uri.pathSegments.length != 1 ||
          uri.query.isNotEmpty ||
          uri.fragment.isNotEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Invalid invitation');
      }
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 8),
      );
      _channel = await SecureChannel.connect(
        socket,
        uri.pathSegments.single,
        server: false,
      );
      unawaited(_listen(_channel!));
      await _syncClocks();
      _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        if (connected && !busy) {
          unawaited(
            _request('clock')
                .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
      });
      status = 'Android conectado · listo para dos ángulos';
    } catch (_) {
      await disconnect();
      status = 'No se pudo conectar. Comprueba el enlace, la misma red y el permiso de red local del iPad.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<Map<String, dynamic>> _request(
    String command, [
    Map<String, dynamic> data = const {},
    Duration timeout = const Duration(seconds: 15),
  ]) async {
    final channel = _channel;
    if (channel == null) throw const SocketException('Not connected');
    final id = _serial++;
    final result = Completer<Map<String, dynamic>>();
    _requests[id] = result;
    // Register timeout before send so errors cannot become unhandled futures.
    final future = result.future.timeout(timeout);
    try {
      unawaited(
        channel
            .send({'type': 'request', 'id': id, 'command': command, ...data})
            .catchError((Object error, StackTrace stack) {
              if (!result.isCompleted) result.completeError(error, stack);
            }),
      );
      return await future;
    } finally {
      _requests.remove(id);
    }
  }

  Future<void> _listen(SecureChannel channel) async {
    try {
      while (!_disposed && _channel == channel) {
        final message = await channel.receive().timeout(
          const Duration(minutes: 5),
        );
        switch (message['type']) {
          case 'reply':
            final pending = _requests[message['id']];
            if (pending != null && !pending.isCompleted) {
              if (message['ok'] == true) {
                pending.complete(message);
              } else {
                pending.completeError(
                  const SocketException('Remote operation failed'),
                );
              }
            }
          case 'request':
            unawaited(_answer(channel, message));
          case 'chunk':
            if (_receiving == null || message['run'] != _run) {
              throw const FormatException('Unexpected transfer');
            }
            final chunk = base64Decode(message['data'] as String);
            if (chunk.length > 48 * 1024 ||
                _receivedBytes + chunk.length > _expectedBytes) {
              throw const FormatException('Transfer limit');
            }
            await _receiving!.writeFrom(chunk);
            _receivedBytes += chunk.length;
            progress = _receivedBytes / _expectedBytes;
            _notify();
          case 'ended':
            if (!hosting && _recording && !busy) unawaited(finishExercise());
          default:
            throw const FormatException('Unknown message');
        }
      }
    } catch (_) {
      if (_channel == channel) {
        _channel = null;
        channel.close();
        for (final pending in _requests.values) {
          if (!pending.isCompleted) {
            pending.completeError(const SocketException('Disconnected'));
          }
        }
        status = 'Conexión interrumpida. Los vídeos finalizados permanecen en cada dispositivo.';
        if (_recording && !busy) {
          if (hosting) {
            await capture.finishClip();
            _recording = false;
          } else {
            unawaited(finishExercise());
          }
        }
        _notify();
      }
    }
  }

  Future<void> _answer(SecureChannel channel, Map<String, dynamic> m) async {
    try {
      if (!hosting) throw const FormatException('Camera commands only');
      final data = await _command(m);
      await channel.send({'type': 'reply', 'id': m['id'], 'ok': true, ...data});
    } catch (_) {
      try {
        await channel.send({'type': 'reply', 'id': m['id'], 'ok': false});
      } catch (_) {
        /* Disconnection already handled by reader. */
      }
    }
  }

  Future<Map<String, dynamic>> _command(Map<String, dynamic> m) async {
    switch (m['command']) {
      case 'clock':
        final t1 = clock.elapsedMicroseconds;
        return {'t1': t1, 't2': clock.elapsedMicroseconds};
      case 'prepare':
        return {'ready': capture.canRecord && _run == null};
      case 'record':
        final run = m['run'] as String;
        final target = m['target'] as int;
        final delay = target - clock.elapsedMicroseconds;
        if (!capture.canRecord ||
            _run != null ||
            run.length > 64 ||
            delay < 100000 ||
            delay > 5000000) {
          throw const FormatException('Not ready');
        }
        _run = run;
        await Future<void>.delayed(Duration(microseconds: delay));
        if (!connected || !hosting) {
          _run = null;
          throw const SocketException('Disconnected');
        }
        _startBefore = clock.elapsedMicroseconds;
        await capture.startClip();
        _startAfter = clock.elapsedMicroseconds;
        _recording = capture.isRecording;
        if (!_recording) {
          _run = null;
          throw const SocketException('Recording failed');
        }
        status = 'Grabando segundo ángulo · control desde el iPad';
        _notify();
        return {'before': _startBefore, 'after': _startAfter};
      case 'finish':
        if (m['run'] != _run) throw const FormatException('Wrong exercise');
        await capture.finishClip();
        _recording = false;
        _hostClip ??= capture.takeCompletedExercise();
        final clip = _hostClip;
        if (clip == null) throw const SocketException('No video');
        await capture.clips!.updateDetails(clip.id, saved: true);
        final digest = await sha256.bind(File(clip.path).openRead()).first;
        status = 'Vídeo conservado en Android · esperando transferencia';
        _notify();
        return {
          'bytes': clip.bytes,
          'hash': digest.toString(),
          'elapsed': clip.elapsed.inMicroseconds,
          'createdAt': clip.createdAt.toIso8601String(),
          'before': _startBefore,
          'after': _startAfter,
        };
      case 'fetch':
        if (m['run'] != _run || _hostClip == null) {
          throw const FormatException('Wrong transfer');
        }
        if (_sending) throw const FormatException('Transfer already active');
        _sending = true;
        LocalClip? clip;
        try {
          clip = await capture.clips!.acquire(_hostClip!.id);
          final file = await File(clip.path).open();
          try {
            while (true) {
              final bytes = await file.read(48 * 1024);
              if (bytes.isEmpty) break;
              await _channel!.send({
                'type': 'chunk',
                'run': _run,
                'data': base64Encode(bytes),
              });
            }
          } finally {
            await file.close();
          }
        } finally {
          if (clip != null) await capture.clips!.release(clip.id);
          _sending = false;
        }
        return {};
      case 'received':
        if (m['run'] != _run) throw const FormatException('Wrong exercise');
        // Keep the Android safety copy; deleting it is a separate user action.
        _run = null;
        _hostClip = null;
        status = 'Transferencia completada · copia conservada en Android';
        _notify();
        return {};
      default:
        throw const FormatException('Unknown command');
    }
  }

  Future<void> _syncClocks() async {
    final samples = <ClockEstimate>[];
    for (var i = 0; i < 7; i++) {
      final t0 = clock.elapsedMicroseconds;
      final reply = await _request('clock');
      samples.add(
        ClockEstimate.sample(
          t0,
          reply['t1'] as int,
          reply['t2'] as int,
          clock.elapsedMicroseconds,
        ),
      );
    }
    estimate = ClockEstimate.best(samples);
  }

  Future<void> startExercise() async {
    if (hosting || busy || _recording || !connected || _run != null) return;
    busy = true;
    status = 'Preparando ambos ángulos…';
    _notify();
    try {
      if (capture.status != CaptureStatus.live) await capture.start();
      if (!capture.canRecord || (await _request('prepare'))['ready'] != true) {
        throw const SocketException('Camera not ready');
      }
      await _syncClocks();
      _run = SecureChannel.newCode();
      _localClip = null;
      _remoteBefore = null;
      _remoteAfter = null;
      final target = clock.elapsedMicroseconds + 1500000;
      final run = _run;
      Future<Map<String, dynamic>> localStart() async {
        await Future<void>.delayed(
          Duration(
            microseconds: math.max(0, target - clock.elapsedMicroseconds),
          ),
        );
        if (!connected || _run != run) {
          throw const SocketException('Cancelled start');
        }
        _startBefore = clock.elapsedMicroseconds;
        await capture.startClip();
        _startAfter = clock.elapsedMicroseconds;
        return {};
      }

      final results = await Future.wait([
        localStart(),
        _request('record', {
          'run': _run,
          'target': target + estimate!.offsetUs,
        }),
      ]);
      final ack = results.last;
      _remoteBefore = ack['before'] as int;
      _remoteAfter = ack['after'] as int;
      if (!capture.isRecording) {
        throw const SocketException('Local recording failed');
      }
      _recording = true;
      status = 'Grabando ambos ángulos';
    } catch (_) {
      await capture.finishClip();
      _localClip = capture.takeCompletedExercise();
      if (_localClip != null) _completed = _localClip;
      if (connected && _run != null) {
        try {
          await _request('finish', {'run': _run});
        } catch (_) {
          /* Remote also has its own duration limit. */
        }
      }
      _run = null;
      status = 'No se pudieron iniciar ambos ángulos. Se conserva cualquier vídeo finalizado.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> finishExercise() async {
    if (hosting || busy || _run == null) return;
    busy = true;
    _recording = false;
    progress = 0;
    status = 'Finalizando y reuniendo los dos ángulos…';
    _notify();
    try {
      Future<Map<String, dynamic>> localFinish() async {
        await capture.finishClip();
        _localClip ??= capture.takeCompletedExercise();
        if (_localClip == null) {
          throw const SocketException('Local video unavailable');
        }
        if (_transferLease == null) {
          _localClip = await capture.clips!.acquire(_localClip!.id);
          _transferLease = _localClip!.id;
        }
        return {};
      }

      final results = await Future.wait([
        localFinish(),
        _request('finish', {'run': _run}, const Duration(seconds: 45)),
      ]);
      final info = results.last;
      final clip = _localClip!;
      _remoteBefore = info['before'] as int;
      _remoteAfter = info['after'] as int;
      _expectedBytes = info['bytes'] as int;
      if (_expectedBytes <= 0 ||
          _expectedBytes > 256 * 1024 * 1024 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(info['hash'] as String)) {
        throw const FormatException('Invalid remote media');
      }
      final dir = await temporaryDirectory();
      await dir.create(recursive: true);
      _receivedFile = File('${dir.path}/paired-${SecureChannel.newCode()}.mp4');
      _receiving = await _receivedFile!.open(mode: FileMode.write);
      _receivedBytes = 0;
      status = 'Recibiendo segundo ángulo…';
      _notify();
      await _request('fetch', {'run': _run}, const Duration(minutes: 5));
      await _receiving!.flush();
      await _receiving!.close();
      _receiving = null;
      if (_receivedBytes != _expectedBytes ||
          (await sha256.bind(_receivedFile!.openRead()).first).toString() !=
              info['hash']) {
        throw const FormatException('Incomplete media');
      }
      final storage = capture.clips;
      if (storage is! MultiAngleStore) {
        throw const SocketException('Unsupported storage');
      }
      final localMid = (_startBefore + _startAfter) ~/ 2;
      final remoteMid =
          (_remoteBefore! + _remoteAfter!) ~/ 2 - estimate!.offsetUs;
      final uncertainty =
          estimate!.roundTripUs ~/ 2 +
          (_startAfter - _startBefore + _remoteAfter! - _remoteBefore!) ~/ 2;
      _completed = await (storage as MultiAngleStore).attachAngle(
        clip.id,
        _receivedFile!.path,
        offsetUs: localMid - remoteMid,
        clockUncertaintyUs: uncertainty.clamp(0, 30000000),
      );
      try {
        await _request('received', {'run': _run});
      } catch (_) {
        /* Both files already verified and saved locally. */
      }
      _run = null;
      _localClip = null;
      status = 'Ambos ángulos listos para revisar y guardar · comprueba la alineación visual';
    } catch (_) {
      if (_localClip != null) {
        try {
          _localClip = await capture.clips!.updateDetails(
            _localClip!.id,
            saved: true,
          );
        } catch (_) {
          /* Pending retained if saved quota is full. */
        }
      }
      _completed = _localClip;
      status = 'No se completó la transferencia. El vídeo local y la copia del Android se conservan. Puedes reintentar desde Dispositivos.';
    } finally {
      try {
        await _receiving?.close();
      } catch (_) {
        /* Interrupted disk write. */
      }
      _receiving = null;
      try {
        if (_receivedFile != null && await _receivedFile!.exists()) {
          await _receivedFile!.delete();
        }
      } catch (_) {
        /* A temporary partial file can be removed on a later launch. */
      }
      _receivedFile = null;
      if (_transferLease != null) {
        final lease = _transferLease!;
        _transferLease = null;
        await capture.clips!.release(lease);
      }
      busy = false;
      _notify();
    }
  }

  Future<void> keepLocal() async {
    if (busy || _recording || hosting || _run == null) return;
    busy = true;
    _notify();
    try {
      if (_localClip != null) {
        await capture.clips!.updateDetails(_localClip!.id, saved: true);
      }
      if (connected) {
        try {
          await _request('received', {'run': _run});
        } catch (_) {}
      }
      _run = null;
      _localClip = null;
      status = 'Vídeo local conservado. La copia del segundo ángulo permanece en Android.';
    } catch (_) {
      status = 'No se pudo guardar. Revisa el espacio de la biblioteca; el pendiente se conserva.';
    } finally {
      busy = false;
      _notify();
    }
  }

  void _captureChanged() {
    if (_recording && !capture.clipBusy && !busy) {
      if (hosting) {
        _recording = false;
        unawaited(_channel?.send({'type': 'ended'}).catchError((Object _) {}));
      } else {
        unawaited(finishExercise());
      }
    }
    _notify();
  }

  Future<void> disconnect() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    final old = _channel;
    _channel = null;
    old?.close();
    await _server?.close();
    _server = null;
    for (final pending in _requests.values) {
      if (!pending.isCompleted) {
        pending.completeError(const SocketException('Disconnected'));
      }
    }
    if (_recording || capture.clipBusy && _run != null) {
      await capture.finishClip();
    }
    if (_run != null) {
      final finalized =
          _hostClip ?? _localClip ?? capture.takeCompletedExercise();
      if (finalized != null) {
        try {
          await capture.clips!.updateDetails(finalized.id, saved: true);
        } catch (_) {
          /* Keep pending file when library is full. */
        }
      }
    }
    _recording = false;
    _run = null;
    _hostClip = null;
    hosting = false;
    invitation = null;
    invitations = [];
    estimate = null;
    status = 'Sin conexión · tus ejercicios permanecen en este dispositivo.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    capture.removeListener(_captureChanged);
    unawaited(disconnect());
    super.dispose();
  }
}
