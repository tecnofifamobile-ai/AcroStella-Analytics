import 'dart:convert';
import 'dart:typed_data';

import 'package:dsrp/dsrp.dart' as srp;

/// SRP-6a authenticates a short, temporary code without transmitting it or a
/// password-derived encryption key. Parameters are fixed locally, never chosen
/// by the network peer. No verifier is persisted or advertised through Bonjour.
class PairingIdentity {
  PairingIdentity._(this._verification);
  final srp.SaltedVerificationKey _verification;
  static const _user = 'AcroStella LAN v2';
  static final _generator = BigInt.from(5);
  // RFC 5054, appendix A, 3072-bit group (generator 5).
  static final _prime = BigInt.parse(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF',
    radix: 16,
  );
  static bool validCode(String code) => RegExp(r'^\d{6}$').hasMatch(code);

  static Future<PairingIdentity> create(String code) async {
    if (!validCode(code)) throw const FormatException('Six digits required');
    return PairingIdentity._(
      await srp.User.createSaltedVerificationKey(
        userId: _user,
        password: code,
        generator: _generator,
        safePrime: _prime,
        kdf: srp.KdfChoice.sha256,
      ),
    );
  }

  Future<Uint8List> accept(
    Future<Map<String, dynamic>> Function() receive,
    Future<void> Function(Map<String, dynamic>) send,
    Uint8List ephemeral,
  ) async {
    final server = srp.Server(
      userId: _user,
      salt: _verification.salt,
      verifierKey: _verification.key,
      generator: _generator,
      safePrime: _prime,
      hashFunction: srp.HashFunctionChoice.sha256,
    );
    final challenge = await server.createChallenge(
      ephemeralServerPrivateKeyBytes: ephemeral,
    );
    await send({
      'type': 'srp-3072-sha256-v2',
      'salt': base64Encode(challenge.verifierKeySalt),
      'public': base64Encode(challenge.ephemeralServerPublicKey),
    });
    final proof = await receive();
    if (proof['type'] != 'proof') {
      throw const FormatException('Pairing protocol');
    }
    try {
      final verification = await server.verifySession(
        ephemeralUserPublicKey: _public(proof['public']),
        userSessionKeyVerifier: _bytes(proof['proof'], 32, 32),
      );
      await send({'type': 'verified', 'proof': base64Encode(verification)});
      return server.sessionKey!;
    } on srp.AuthenticationFailure {
      await send({'type': 'rejected'});
      throw const PairingCodeRejected();
    }
  }

  static Future<Uint8List> join(
    String code,
    Future<Map<String, dynamic>> Function() receive,
    Future<void> Function(Map<String, dynamic>) send,
    Uint8List ephemeral,
  ) async {
    if (!validCode(code)) throw const FormatException('Six digits required');
    final message = await receive();
    if (message['type'] != 'srp-3072-sha256-v2') {
      throw const FormatException('Pairing protocol');
    }
    final user = await srp.User.fromUserCredsAndChallenge(
      userId: _user,
      password: code,
      kdf: srp.KdfChoice.sha256,
      ephemeralUserPrivateKey: ephemeral,
      challenge: srp.Challenge.fromServer(
        generator: _generator,
        safePrime: _prime,
        hashFunctionChoice: srp.HashFunctionChoice.sha256,
        ephemeralServerPublicKey: _public(message['public']),
        verifierKeySalt: _bytes(message['salt'], 32, 32),
      ),
    );
    final proof = user.getUserSessionVerifiers();
    await send({
      'type': 'proof',
      'public': base64Encode(proof.ephemeralUserPublicKey),
      'proof': base64Encode(proof.sessionKeyVerifier),
    });
    final response = await receive();
    if (response['type'] == 'rejected') throw const PairingCodeRejected();
    if (response['type'] != 'verified') {
      throw const FormatException('Pairing protocol');
    }
    try {
      await user.verifySession(_bytes(response['proof'], 32, 32));
    } on srp.AuthenticationFailure {
      throw const PairingCodeRejected();
    }
    return user.sessionKey;
  }

  static Uint8List _bytes(dynamic value, int min, int max) {
    if (value is! String || value.length > ((max + 2) ~/ 3) * 4) {
      throw const FormatException('Pairing field size');
    }
    final bytes = base64Decode(value);
    if (bytes.length < min || bytes.length > max) {
      throw const FormatException('Pairing field size');
    }
    return bytes;
  }

  static Uint8List _public(dynamic value) {
    final bytes = _bytes(value, 1, 384);
    final key = bytes.toBigInt();
    if (key <= BigInt.zero || key >= _prime) {
      throw const FormatException('Invalid public key');
    }
    return bytes;
  }

  void erase() => _verification.erase();
}

class PairingCodeRejected implements Exception {
  const PairingCodeRejected();
}
