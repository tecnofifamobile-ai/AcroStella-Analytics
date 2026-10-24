import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_channel.dart';

abstract interface class TrustStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureTrustStorage implements TrustStorage {
  const SecureTrustStorage();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: 'acrostella.trusted.v1');
  @override
  Future<void> write(String value) =>
      _storage.write(key: 'acrostella.trusted.v1', value: value);
}

class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.secret,
  });
  final String id, name, endpoint, secret;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'endpoint': endpoint,
    'secret': secret,
  };
  factory TrustedDevice.fromJson(Map<String, dynamic> json) {
    final device = TrustedDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      endpoint: json['endpoint'] as String,
      secret: json['secret'] as String,
    );
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(device.id) ||
        base64Decode(device.secret).length != 32 ||
        device.name.length > 100 ||
        device.endpoint.length > 80) {
      throw const FormatException('Invalid trusted device');
    }
    return device;
  }
}

/// Secrets live in Keychain / Android encrypted storage. Discovery publishes
/// only a random public identifier, never a pairing or resumption secret.
class TrustedDevices {
  TrustedDevices(this.storage);
  final TrustStorage storage;
  String? _id;
  String get id => _id!;
  String? role, lastPeer;
  final Map<String, TrustedDevice> devices = {};
  Future<void>? _loading;
  Future<void> _writing = Future.value();
  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    final raw = await storage.read();
    if (raw == null) {
      _id = SecureChannel.randomBytes(16)
          .map((n) => n.toRadixString(16).padLeft(2, '0'))
          .join();
      await save();
      return;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final id = data['id'] as String;
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw const FormatException('Invalid local identity');
    }
    _id = id;
    role = data['role'] as String?;
    lastPeer = data['lastPeer'] as String?;
    final entries = data['devices'] as List;
    if (entries.length > 8) {
      throw const FormatException('Too many trusted devices');
    }
    for (final entry in entries) {
      final device = TrustedDevice.fromJson(entry as Map<String, dynamic>);
      devices[device.id] = device;
    }
  }

  Future<void> remember(TrustedDevice device, String nextRole) async {
    await load();
    if (!devices.containsKey(device.id) && devices.length >= 8) {
      throw StateError('Forget a device before adding another');
    }
    devices[device.id] = device;
    role = nextRole;
    lastPeer = device.id;
    await save();
  }

  Future<void> forget(String peer) async {
    await load();
    devices.remove(peer);
    if (lastPeer == peer) {
      lastPeer = null;
      role = null;
    }
    await save();
  }

  Future<void> save() {
    final value = jsonEncode({
      'id': id,
      'role': role,
      'lastPeer': lastPeer,
      'devices': devices.values.map((d) => d.toJson()).toList(),
    });
    final operation = _writing.then((_) => storage.write(value));
    _writing = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
