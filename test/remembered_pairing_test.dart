import 'dart:convert';
import 'dart:io';

import 'package:acrostella_analytics/src/capture/capture_device.dart';
import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/connection/pair_controller.dart';
import 'package:acrostella_analytics/src/connection/secure_channel.dart';
import 'package:acrostella_analytics/src/connection/trusted_devices.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lan_pair_test.dart' show DiskCamera;

class MemoryTrust implements TrustStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async => value = next;
}

class DelayedEncoder extends DiskCamera implements FrameTimedCaptureDevice {
  DelayedEncoder(super.dir, super.value, this.ackDelay);
  final Duration ackDelay;
  final frames = Stopwatch();
  @override
  Future<void> startRecording() async {
    await super.startRecording();
    frames
      ..reset()
      ..start();
    await Future<void>.delayed(ackDelay);
  }

  @override
  Future<int?> firstFrameAgeUs() async => frames.elapsedMicroseconds;
}

Future<void> eventually(bool Function() condition) async {
  for (var i = 0; i < 150 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

void main() {
  test(
    'trusted identities and keys survive reload; forgetting removes trust',
    () async {
      final memory = MemoryTrust();
      final store = TrustedDevices(memory);
      await store.load();
      final id = store.id;
      final peer = TrustedDevice(
        id: 'a' * 32,
        name: 'Cámara',
        endpoint: '192.168.1.1:45872',
        secret: base64Encode(SecureChannel.randomBytes(32)),
      );
      await store.remember(peer, 'center');
      final reopened = TrustedDevices(memory);
      await reopened.load();
      expect(reopened.id, id);
      expect(reopened.devices[peer.id]!.secret, peer.secret);
      expect(reopened.lastPeer, peer.id);
      await reopened.forget(peer.id);
      final forgotten = TrustedDevices(memory);
      await forgotten.load();
      expect(forgotten.devices, isEmpty);
      expect(forgotten.role, isNull);
    },
  );

  Future<void> resumeHandshake({
    bool wrongKey = false,
    bool wrongIdentity = false,
    bool unknown = false,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = server.first;
    final client = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    final incoming = await accepted;
    final key = base64Encode(SecureChannel.randomBytes(32));
    try {
      final channels = await Future.wait([
        SecureChannel.connect(
          incoming,
          '',
          server: true,
          localId: 'a' * 32,
          trustedKey: (id) => id == 'b' * 32 && !unknown ? key : null,
        ),
        SecureChannel.connect(
          client,
          '',
          server: false,
          localId: 'b' * 32,
          expectedPeer: (wrongIdentity ? 'c' : 'a') * 32,
          resumeKey: wrongKey
              ? base64Encode(SecureChannel.randomBytes(32))
              : key,
        ),
      ]);
      expect(channels.every((c) => c.resumed), isTrue);
      await channels.first.send({'type': 'test', 'value': 8});
      expect((await channels.last.receive())['value'], 8);
      for (final channel in channels) {
        channel.close();
      }
    } finally {
      client.destroy();
      incoming.destroy();
      await server.close();
    }
  }

  test('remembered resumption proves the key and both identities with fresh session keys', () async {
    await resumeHandshake();
    await resumeHandshake();
    await expectLater(resumeHandshake(wrongKey: true), throwsA(anything));
    await expectLater(resumeHandshake(wrongIdentity: true), throwsA(anything));
    await expectLater(resumeHandshake(unknown: true), throwsA(anything));
  });

  test('background preserves trust and completed angles; foreground resumes without a code and restores group', () async {
    final root = await Directory.systemTemp.createTemp('remembered-pair-');
    final hostDir = await Directory('${root.path}/host').create();
    final clientDir = await Directory('${root.path}/client').create();
    final hostStore = FileClipStore(
      () async => Directory('${hostDir.path}/clips'),
      durable: true,
    );
    final clientStore = FileClipStore(
      () async => Directory('${clientDir.path}/clips'),
      durable: true,
    );
    final hostCapture = CaptureSession(
      DelayedEncoder(hostDir, 11, const Duration(milliseconds: 300)),
      clips: hostStore,
    );
    final clientCapture = CaptureSession(
      DelayedEncoder(clientDir, 22, const Duration(milliseconds: 5)),
      clips: clientStore,
    );
    final hostTrust = TrustedDevices(MemoryTrust()),
        clientTrust = TrustedDevices(MemoryTrust());
    final host = PairController(
      hostCapture,
      () async => hostDir,
      trust: hostTrust,
      recoveryDirectory: () async => hostDir,
      port: 0,
    );
    final client = PairController(
      clientCapture,
      () async => clientDir,
      trust: clientTrust,
      recoveryDirectory: () async => clientDir,
    );
    try {
      await host.host();
      final endpoint = '127.0.0.1:${host.addresses.first.split(':').last}';
      await client.join(endpoint, host.pairingCode!);
      expect(client.connected, isTrue, reason: client.status);
      await eventually(() => host.remembered);
      expect(
        hostTrust.devices.values.single.secret,
        clientTrust.devices.values.single.secret,
      );
      await client.startExercise();
      expect(client.recording, isTrue, reason: client.status);
      await client.suspend();
      await host.suspend();
      expect(client.connected, isFalse);
      expect(client.transferPending, isTrue);
      expect((await clientStore.list()).single.saved, isTrue);
      expect((await hostStore.list()).single.saved, isTrue);
      await host.resume();
      expect(host.pairingCode, isNull);
      final nextEndpoint = '127.0.0.1:${host.addresses.first.split(':').last}';
      await client.reconnect(client.trusted.single, endpoint: nextEndpoint);
      expect(client.connected, isTrue, reason: client.status);
      expect(host.pairingCode, isNull);
      final group = (await clientStore.list()).single;
      expect(group.secondaryPath, isNotNull, reason: client.status);
      // Encoder acknowledgement delay differs by 295 ms. Alignment uses the
      // first accepted native frame, not the acknowledgement midpoint.
      expect(group.offsetUs.abs(), lessThan(100000));
      expect(group.clockUncertaintyUs, lessThan(100000));
      expect(client.transferPending, isFalse);
      expect(client.takeCompleted()?.id, group.id);
    } finally {
      await client.disconnect();
      await host.disconnect();
      client.dispose();
      host.dispose();
      await clientCapture.stop();
      await hostCapture.stop();
      clientCapture.dispose();
      hostCapture.dispose();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 40)));
}
