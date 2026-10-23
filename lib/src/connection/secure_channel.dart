import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'pairing_auth.dart';

/// Bounded, authenticated LAN messages. Pairing secrets never leave the device
/// in cleartext. Fresh challenges derive independent keys for each direction.
class SecureChannel {
  SecureChannel._(this.socket) : _input = StreamIterator(socket);
  final Socket socket;
  late String peerId;
  late String rememberKey;
  bool resumed = false;
  final StreamIterator<Uint8List> _input;
  final _cipher = AesGcm.with256bits();
  late SecretKey _tx, _rx;
  Uint8List _chunk = Uint8List(0);
  int _at = 0, _sent = 0, _received = 0;
  Future<void> _writing = Future.value();
  static const maxFrame = 100 * 1024;
  static final _random = Random.secure();
  static List<int> randomBytes(int count) =>
      List.generate(count, (_) => _random.nextInt(256));
  static String newCode() =>
      _random.nextInt(1000000).toString().padLeft(6, '0');

  static Future<SecureChannel> connect(
    Socket socket,
    String code, {
    required bool server,
    PairingIdentity? identity,
    String? localId,
    String? expectedPeer,
    String? resumeKey,
    String? Function(String peerId)? trustedKey,
  }) async {
    final channel = SecureChannel._(socket);
    final oursId =
        localId ??
        randomBytes(16).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    PairingIdentity? temporaryIdentity;
    try {
      Future<void> authenticate() async {
        late String clientId, serverId;
        String? shared = resumeKey;
        if (server) {
          final intro = await channel._receiveHandshake();
          clientId = intro['id'] as String;
          if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(clientId) ||
              intro['protocol'] != 3) {
            throw const FormatException('Invalid introduction');
          }
          serverId = oursId;
          channel.resumed = intro['mode'] == 'resume';
          if (channel.resumed) {
            if (intro['peer'] != serverId) {
              throw const FormatException('Wrong device');
            }
            shared = trustedKey?.call(clientId);
            if (shared == null) {
              throw const FormatException('Unknown trusted device');
            }
          } else if (intro['mode'] != 'pair') {
            throw const FormatException('Invalid authentication mode');
          }
        } else {
          clientId = oursId;
          serverId = expectedPeer ?? '';
          channel.resumed = shared != null;
          await channel._sendHandshake({
            'protocol': 3,
            'id': oursId,
            'peer': serverId,
            'mode': channel.resumed ? 'resume' : 'pair',
          });
        }
        late List<int> secret;
        if (channel.resumed) {
          final key = base64Decode(shared!);
          if (key.length != 32) {
            throw const FormatException('Invalid trust key');
          }
          final ours = randomBytes(32);
          await channel._sendHandshake({'nonce': base64Encode(ours)});
          final nonce = await channel._receiveHandshake();
          final theirs = base64Decode(nonce['nonce'] as String);
          if (theirs.length != 32) {
            throw const FormatException('Invalid challenge');
          }
          final transcript = utf8.encode(
            jsonEncode([
              'AcroStella resume v3',
              clientId,
              serverId,
              base64Encode(server ? ours : theirs),
              base64Encode(server ? theirs : ours),
            ]),
          );
          final hmac = Hmac.sha256();
          List<int> proofInput(bool fromServer) => [
            ...transcript,
            ...utf8.encode(fromServer ? 'server' : 'client'),
          ];
          final proof = await hmac.calculateMac(
            proofInput(server),
            secretKey: SecretKey(key),
          );
          await channel._sendHandshake({'proof': base64Encode(proof.bytes)});
          final reply = await channel._receiveHandshake();
          final expected = await hmac.calculateMac(
            proofInput(!server),
            secretKey: SecretKey(key),
          );
          final valid = expected == Mac(base64Decode(reply['proof'] as String));
          if (!valid) {
            throw const FormatException('Trust authentication failed');
          }
          secret =
              await (await Hkdf(
                    hmac: Hmac.sha256(),
                    outputLength: 32,
                  ).deriveKey(
                    secretKey: SecretKey(key),
                    nonce: transcript,
                    info: utf8.encode('session'),
                  ))
                  .extractBytes();
          key.fillRange(0, key.length, 0);
          channel.rememberKey = shared;
        } else {
          if (!PairingIdentity.validCode(code)) {
            throw const FormatException('Six digits required');
          }
          final ephemeral = Uint8List.fromList(randomBytes(32));
          if (server && identity == null) {
            temporaryIdentity = await PairingIdentity.create(code);
          }
          secret = server
              ? await (identity ?? temporaryIdentity!).accept(
                  channel._receiveHandshake,
                  channel._sendHandshake,
                  ephemeral,
                )
              : await PairingIdentity.join(
                  code,
                  channel._receiveHandshake,
                  channel._sendHandshake,
                  ephemeral,
                );
          if (server) channel.rememberKey = base64Encode(randomBytes(32));
        }
        if (channel.resumed) secret = Uint8List.fromList(secret);
        final ours = randomBytes(32);
        socket.add(ours);
        await socket.flush();
        final theirs = await channel._read(32);
        final salt = server ? [...ours, ...theirs] : [...theirs, ...ours];
        final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
        Future<SecretKey> key(String direction) => hkdf.deriveKey(
          secretKey: SecretKey(secret),
          nonce: salt,
          info: utf8.encode('AcroStella LAN v3 $direction'),
        );
        channel._tx = await key(
          server ? 'camera-to-center' : 'center-to-camera',
        );
        channel._rx = await key(
          server ? 'center-to-camera' : 'camera-to-center',
        );
        secret.fillRange(0, secret.length, 0);
        await channel.send({
          'type': 'hello',
          'protocol': 3,
          'id': oursId,
          if (server) 'peer': clientId,
          if (server && !channel.resumed) 'remember': channel.rememberKey,
        });
        final hello = await channel.receive();
        if (hello['type'] != 'hello' ||
            hello['protocol'] != 3 ||
            !RegExp(r'^[a-f0-9]{32}$').hasMatch(hello['id'] as String) ||
            (server && hello['id'] != clientId) ||
            (!server && hello['peer'] != oursId) ||
            (expectedPeer != null && hello['id'] != expectedPeer)) {
          throw const FormatException('Invalid authenticated identity');
        }
        channel.peerId = hello['id'] as String;
        if (!server && !channel.resumed) {
          channel.rememberKey = hello['remember'] as String;
          if (base64Decode(channel.rememberKey).length != 32) {
            throw const FormatException('Invalid trust key');
          }
        }
      }

      await authenticate().timeout(const Duration(seconds: 12));
      return channel;
    } catch (_) {
      channel.close();
      rethrow;
    } finally {
      temporaryIdentity?.erase();
    }
  }

  Future<void> _sendHandshake(Map<String, dynamic> message) async {
    final bytes = utf8.encode(jsonEncode(message));
    if (bytes.length > 2048) throw const FormatException('Handshake too large');
    socket.add(Uint8List(4)..buffer.asByteData().setUint32(0, bytes.length));
    socket.add(bytes);
    await socket.flush();
  }

  Future<Map<String, dynamic>> _receiveHandshake() async {
    final header = await _read(4);
    final length = header.buffer.asByteData().getUint32(0);
    if (length < 2 || length > 2048) {
      throw const FormatException('Pairing protocol or frame size');
    }
    return jsonDecode(utf8.decode(await _read(length))) as Map<String, dynamic>;
  }

  Future<Uint8List> _read(int count) async {
    final output = Uint8List(count);
    var written = 0;
    while (written < count) {
      if (_at == _chunk.length) {
        if (!await _input.moveNext()) {
          throw const SocketException('Connection closed');
        }
        _chunk = _input.current;
        _at = 0;
      }
      final n = min(count - written, _chunk.length - _at);
      output.setRange(written, written + n, _chunk, _at);
      written += n;
      _at += n;
    }
    return output;
  }

  Uint8List _nonce(int sequence) =>
      Uint8List(12)..buffer.asByteData().setUint64(4, sequence);

  Future<void> send(Map<String, dynamic> message) {
    final operation = _writing.then((_) async {
      final bytes = utf8.encode(jsonEncode(message));
      if (bytes.length > maxFrame - 28) {
        throw const FormatException('Message too large');
      }
      final box = await _cipher.encrypt(
        bytes,
        secretKey: _tx,
        nonce: _nonce(_sent++),
      );
      final frame = [...box.nonce, ...box.cipherText, ...box.mac.bytes];
      final header = Uint8List(4)
        ..buffer.asByteData().setUint32(0, frame.length);
      socket.add(header);
      socket.add(frame);
      await socket.flush();
    });
    _writing = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<Map<String, dynamic>> receive() async {
    final header = await _read(4);
    final length = header.buffer.asByteData().getUint32(0);
    if (length < 28 || length > maxFrame) {
      throw const FormatException('Invalid frame length');
    }
    final frame = await _read(length);
    final expected = _nonce(_received++);
    for (var i = 0; i < 12; i++) {
      if (frame[i] != expected[i]) {
        throw const FormatException('Invalid sequence');
      }
    }
    final plain = await _cipher.decrypt(
      SecretBox(
        frame.sublist(12, length - 16),
        nonce: frame.sublist(0, 12),
        mac: Mac(frame.sublist(length - 16)),
      ),
      secretKey: _rx,
    );
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }

  void close() {
    socket.destroy();
    unawaited(_input.cancel());
  }
}

/// Clock offset (remote - local) estimated by a four-timestamp exchange.
/// This measures control clocks, not exposure or encoded frame timestamps.
class ClockEstimate {
  const ClockEstimate(this.offsetUs, this.roundTripUs);
  final int offsetUs, roundTripUs;
  factory ClockEstimate.sample(int t0, int t1, int t2, int t3) {
    if (t3 < t0 || t2 < t1) throw const FormatException('Invalid clocks');
    return ClockEstimate(
      ((t1 - t0 + t2 - t3) / 2).round(),
      max(0, t3 - t0 - (t2 - t1)),
    );
  }
  static ClockEstimate best(List<ClockEstimate> values) =>
      values.reduce((a, b) => a.roundTripUs <= b.roundTripUs ? a : b);
}
