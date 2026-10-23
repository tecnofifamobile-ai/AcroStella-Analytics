import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../capture/capture_session.dart';
import '../clips/clip_store.dart';
import 'secure_channel.dart';
import 'pairing_auth.dart';
import 'peer_discovery.dart';

class PairController extends ChangeNotifier {
  PairController(
    this.capture,
    this.temporaryDirectory, {
    this.discovery,
    this.codeLifetime = const Duration(minutes: 5),
    this.port = 45872,
  }) {
    capture.addListener(_captureChanged);
  }
  final CaptureSession capture;
  final PeerDiscovery? discovery;
  final Duration codeLifetime;
  final int port;
  PairingIdentity? _identity;
  Socket? _pendingSocket;
  Timer? _expiryTimer, _searchTimer;
  int _generation = 0, _searchGeneration = 0;
  String? pairingCode;
  String? cameraName;
  DateTime? codeExpiresAt;
  List<String> addresses = [];
  List<CameraPeer> peers = [];
  bool searching = false;
  String discoveryStatus =
      'Busca el Android o introduce su IP en conexión manual.';
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

  Future<void> search() async {
    if (searching || connected || hosting || busy) return;
    final generation = ++_searchGeneration;
    searching = true;
    peers = [];
    discoveryStatus = 'Buscando cámaras en tu red…';
    _notify();
    try {
      if (discovery == null) throw UnsupportedError('Discovery unavailable');
      await discovery!
          .browse((found) {
            if (_disposed || generation != _searchGeneration) return;
            peers = found.where((p) => localAddress(p.address)).toList();
            discoveryStatus = peers.isEmpty
                ? 'Buscando… Prepara la segunda cámara en el Android.'
                : 'Selecciona tu cámara e introduce sus seis cifras.';
            _notify();
          })
          .timeout(const Duration(seconds: 8));
      if (generation != _searchGeneration) return;
      _searchTimer = Timer(const Duration(seconds: 30), () {
        unawaited(stopSearch());
      });
    } catch (_) {
      if (generation != _searchGeneration) return;
      searching = false;
      _searchGeneration++;
      try {
        await discovery?.stopBrowsing().timeout(const Duration(seconds: 3));
      } catch (_) {
        /* Manual IP remains available. */
      }
      discoveryStatus = 'No se pudo buscar. Permite la red local en Ajustes o utiliza conexión manual por IP.';
      _notify();
    }
  }

  Future<void> stopSearch() async {
    _searchGeneration++;
    _searchTimer?.cancel();
    _searchTimer = null;
    searching = false;
    try {
      await discovery?.stopBrowsing().timeout(const Duration(seconds: 3));
    } catch (_) {
      /* Manual IP remains available. */
    }
    if (peers.isEmpty) {
      discoveryStatus = 'Sin cámaras encontradas. Comprueba la misma Wi-Fi/hotspot y el permiso de red local, o usa conexión manual.';
    }
    _notify();
  }

  Future<void> _stopAdvertising() async {
    try {
      await discovery?.stopAdvertising().timeout(const Duration(seconds: 3));
    } catch (_) {
      /* TCP is closed independently. */
    }
  }

  Future<void> _expireCode(int generation, String message) async {
    if (generation != _generation || connected) return;
    pairingCode = null;
    codeExpiresAt = null;
    _identity?.erase();
    _identity = null;
    final server = _server;
    _server = null;
    _pendingSocket?.destroy();
    _pendingSocket = null;
    status = message;
    _notify();
    await server?.close();
    await _stopAdvertising();
  }

  Future<void> host() async {
    if (capture.clipBusy || busy) return;
    busy = true;
    await disconnect();
    final generation = _generation;
    hosting = true;
    status = 'Preparando cámara y código…';
    _notify();
    try {
      await capture.start();
      if (!capture.canRecord) throw StateError('Camera unavailable');
      if (generation != _generation) return;
      final code = SecureChannel.newCode();
      final identity = await PairingIdentity.create(code);
      if (generation != _generation) {
        identity.erase();
        return;
      }
      _identity = identity;
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      if (generation != _generation) {
        await server.close();
        return;
      }
      _server = server;
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      if (generation != _generation) return;
      final ordered = interfaces.toList()
        ..sort((a, b) {
          int rank(String n) =>
              RegExp(r'^(wlan|ap|swlan|bridge|br|en)').hasMatch(n) ? 0 : 1;
          return rank(a.name).compareTo(rank(b.name));
        });
      addresses = [
        for (final interface in ordered)
          if (!RegExp(r'^(rmnet|ccmni|pdp|tun|utun)').hasMatch(interface.name))
            for (final ip in interface.addresses)
              if (localAddress(ip.address) && !ip.isLoopback)
                '${ip.address}:${server.port}',
      ];
      if (addresses.isEmpty) throw const SocketException('No local network');
      _attempts = 0;
      pairingCode = code;
      codeExpiresAt = DateTime.now().add(codeLifetime);
      _expiryTimer = Timer(codeLifetime, () {
        unawaited(
          _expireCode(
            generation,
            'El código ha caducado. Genera otro para conectar.',
          ),
        );
      });
      status = 'Cámara preparada. Busca este Android desde el iPad e introduce las seis cifras.';
      _notify();
      server.listen((socket) async {
        if (generation != _generation ||
            _server != server ||
            pairingCode == null ||
            _candidate ||
            connected ||
            _attempts >= 5 ||
            !DateTime.now().isBefore(codeExpiresAt!)) {
          socket.destroy();
          return;
        }
        _attempts++;
        _candidate = true;
        _pendingSocket = socket;
        try {
          final channel = await SecureChannel.connect(
            socket,
            code,
            server: true,
            identity: identity,
          );
          if (_server != server ||
              generation != _generation ||
              _disposed ||
              pairingCode == null) {
            channel.close();
            return;
          }
          _channel = channel;
          _expiryTimer?.cancel();
          pairingCode = null;
          codeExpiresAt = null;
          identity.erase();
          _identity = null;
          status = 'iPad conectado · cámara preparada';
          _notify();
          unawaited(_stopAdvertising());
          unawaited(_listen(channel));
        } catch (_) {
          socket.destroy();
          if (generation == _generation && !connected && pairingCode != null) {
            status = 'Intento rechazado. Comprueba el código del Android en el iPad.';
            if (_attempts >= 5) {
              await _expireCode(
                generation,
                'Código bloqueado tras cinco intentos. Genera otro.',
              );
            }
            _notify();
          }
        } finally {
          if (_pendingSocket == socket) _pendingSocket = null;
          if (generation == _generation) _candidate = false;
        }
      });
      try {
        cameraName =
            'AcroStella Camera ${SecureChannel.randomBytes(3).map((n) => n.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
        if (generation == _generation && !connected && pairingCode != null) {
          await discovery
              ?.advertise(cameraName!, server.port)
              .timeout(const Duration(seconds: 8));
        }
      } catch (_) {
        await _stopAdvertising();
        if (generation == _generation && !connected && pairingCode != null) {
          status = 'Cámara preparada. La búsqueda automática no está disponible: usa la IP de conexión manual y las seis cifras.';
        }
      }
    } catch (error) {
      if (generation == _generation) {
        await disconnect();
        status = error is SocketException
            ? 'No se pudo abrir la conexión local. Activa Wi-Fi/hotspot; si otra app ocupa el puerto 45872, ciérrala e inténtalo de nuevo.'
            : 'No se pudo preparar la cámara. Comprueba su permiso e inténtalo de nuevo.';
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  static (String, int) parseEndpoint(String endpoint) {
    final parts = endpoint.trim().split(':');
    final port = parts.length == 1 ? 45872 : int.tryParse(parts.last);
    if (parts.length > 2 ||
        !localAddress(parts.first) ||
        port == null ||
        port < 1 ||
        port > 65535) {
      throw const FormatException('Local IPv4 required');
    }
    return (parts.first, port);
  }

  Future<void> join(String endpoint, String code) async {
    if (capture.clipBusy || busy) return;
    final normalized = code.replaceAll(RegExp(r'\s'), '');
    // Validate before touching sockets or an existing session.
    late final (String, int) target;
    try {
      if (!PairingIdentity.validCode(normalized)) {
        status = 'Escribe las seis cifras del Android, incluidos los ceros iniciales.';
        _notify();
        return;
      }
      target = parseEndpoint(endpoint);
    } on FormatException {
      status = 'Selecciona una cámara o escribe su IP local, por ejemplo 192.168.43.1.';
      _notify();
      return;
    }
    busy = true;
    await disconnect();
    final generation = _generation;
    status = 'Conectando y comprobando el código…';
    _notify();
    try {
      final socket = await Socket.connect(
        target.$1,
        target.$2,
        timeout: const Duration(seconds: 8),
      );
      if (generation != _generation) {
        socket.destroy();
        return;
      }
      _pendingSocket = socket;
      final channel = await SecureChannel.connect(
        socket,
        normalized,
        server: false,
      );
      if (generation != _generation) {
        channel.close();
        return;
      }
      _pendingSocket = null;
      _channel = channel;
      unawaited(_listen(channel));
      await _syncClocks();
      if (generation != _generation) return;
      _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        if (connected && !busy) {
          unawaited(
            _request('clock')
                .then<void>((_) {}, onError: (Object _, StackTrace _) {}),
          );
        }
      });
      status = 'Android conectado · listo para dos ángulos';
    } catch (error) {
      if (generation == _generation) {
        await disconnect();
        status = switch (error) {
          PairingCodeRejected() => 'Código incorrecto. Comprueba las seis cifras que muestra el Android.',
          TimeoutException() => 'Sin respuesta. Mantén ambas apps abiertas, comprueba Wi-Fi/hotspot y permite la red local en el iPad.',
          FormatException() => 'Conexión incompatible. Actualiza ambos dispositivos a 0.5.1 o posterior y genera otro código.',
          SocketException(osError: OSError(errorCode: 1 || 13)) =>
            'Acceso a la red denegado. Permite Red local en Ajustes del iPad.',
          SocketException() => 'No se alcanza la cámara. Prepara el Android, comprueba su IP y conecta ambos a la misma Wi-Fi/hotspot.',
          _ => 'No se pudo verificar la cámara. Genera otro código y comprueba que ambos están actualizados.',
        };
      }
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
    _generation++;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _pendingSocket?.destroy();
    _pendingSocket = null;
    _candidate = false;
    _identity?.erase();
    _identity = null;
    pairingCode = null;
    codeExpiresAt = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    final old = _channel;
    _channel = null;
    old?.close();
    final server = _server;
    _server = null;
    await server?.close();
    await stopSearch();
    await _stopAdvertising();
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
    addresses = [];
    cameraName = null;
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
