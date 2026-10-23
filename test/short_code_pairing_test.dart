import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/connection/connection_screen.dart';
import 'package:acrostella_analytics/src/connection/pair_controller.dart';
import 'package:acrostella_analytics/src/connection/pairing_auth.dart';
import 'package:acrostella_analytics/src/connection/peer_discovery.dart';
import 'package:acrostella_analytics/src/connection/secure_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lan_pair_test.dart' show DiskCamera;

class FakeDiscovery implements PeerDiscovery {
  void Function(List<CameraPeer>)? changed;
  int searches = 0, stopped = 0, withdrawn = 0;
  String? advertised;
  bool fail = false;
  @override
  Future<void> advertise(String name, int port) async => advertised = name;
  @override
  Future<void> browse(void Function(List<CameraPeer>) callback) async {
    searches++;
    if (fail) throw StateError('Unavailable');
    changed = callback;
  }

  @override
  Future<void> stopBrowsing() async {
    stopped++;
  }

  @override
  Future<void> stopAdvertising() async {
    withdrawn++;
  }
}

void main() {
  test('SRP authenticates leading-zero codes with fresh keys and rejects a replayed proof', () async {
    final identity = await PairingIdentity.create('000042');
    final transcript = <Map<String, dynamic>>[];
    Future<List<Uint8List>> exchange() async {
      final toServer = StreamController<Map<String, dynamic>>();
      final toClient = StreamController<Map<String, dynamic>>();
      final serverInput = StreamIterator(toServer.stream);
      final clientInput = StreamIterator(toClient.stream);
      Future<Map<String, dynamic>> read(
        StreamIterator<Map<String, dynamic>> input,
      ) async {
        if (!await input.moveNext()) throw StateError('Closed');
        return input.current;
      }

      try {
        return await Future.wait([
          identity.accept(() => read(serverInput), (m) async {
            transcript.add(m);
            toClient.add(m);
          }, Uint8List.fromList(SecureChannel.randomBytes(32))),
          PairingIdentity.join('000042', () => read(clientInput), (m) async {
            transcript.add(m);
            toServer.add(m);
          }, Uint8List.fromList(SecureChannel.randomBytes(32))),
        ]);
      } finally {
        await serverInput.cancel();
        await clientInput.cancel();
        await toServer.close();
        await toClient.close();
      }
    }

    try {
      final first = await exchange();
      expect(first[0], first[1]);
      final oldProof = transcript.singleWhere((m) => m['type'] == 'proof');
      final second = await exchange();
      expect(second[0], second[1]);
      expect(second[0], isNot(first[0]));
      expect(jsonEncode(transcript), isNot(contains('000042')));
      final messages = <Map<String, dynamic>>[];
      await expectLater(
        identity.accept(
          () async => oldProof,
          (m) async => messages.add(m),
          Uint8List.fromList(SecureChannel.randomBytes(32)),
        ),
        throwsA(isA<PairingCodeRejected>()),
      );
      expect(messages.last['type'], 'rejected');
      await expectLater(
        identity.accept(
          () async => {
            'type': 'proof',
            'public': base64Encode(Uint8List(385)),
            'proof': base64Encode(Uint8List(32)),
          },
          (_) async {},
          Uint8List.fromList(SecureChannel.randomBytes(32)),
        ),
        throwsFormatException,
      );
    } finally {
      identity.erase();
    }
  });

  test('numeric LAN pairing retries a wrong code, then locks five failures and expires', () async {
    final root = await Directory.systemTemp.createTemp('pairing-short-');
    final capture = CaptureSession(
      DiskCamera(root, 1),
      clips: FileClipStore(
        () async => Directory('${root.path}/clips'),
        durable: true,
      ),
    );
    final host = PairController(capture, () async => root, port: 0);
    final clientCapture = CaptureSession(DiskCamera(root, 2));
    final client = PairController(clientCapture, () async => root);
    try {
      await host.host();
      expect(host.pairingCode, isNotNull, reason: host.status);
      final code = host.pairingCode!;
      final endpoint = '127.0.0.1:${host.addresses.first.split(':').last}';
      final wrong = code == '111111' ? '222222' : '111111';
      await client.join(endpoint, wrong);
      expect(client.connected, isFalse);
      expect(client.status, contains('Código incorrecto'));
      expect(host.pairingCode, code);
      await client.join(endpoint, code);
      expect(client.connected, isTrue, reason: client.status);
      await client.disconnect();
      await host.host();
      final endpoint2 = '127.0.0.1:${host.addresses.first.split(':').last}';
      final wrong2 = host.pairingCode == '111111' ? '222222' : '111111';
      for (var i = 0; i < 5; i++) {
        await client.join(endpoint2, wrong2);
      }
      for (var i = 0; i < 50 && host.pairingCode != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(host.pairingCode, isNull);
      expect(host.status, contains('bloqueado'));
      await host.disconnect();
      final expiring = PairController(
        capture,
        () async => root,
        port: 0,
        codeLifetime: const Duration(milliseconds: 50),
      );
      try {
        await expiring.host();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(expiring.pairingCode, isNull);
        expect(expiring.status, contains('caducado'));
      } finally {
        await expiring.disconnect();
        expiring.dispose();
      }
    } finally {
      await client.disconnect();
      await host.disconnect();
      client.dispose();
      host.dispose();
      await capture.stop();
      await clientCapture.stop();
      capture.dispose();
      clientCapture.dispose();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('discovery updates found/lost peers, ignores stale callbacks and offers IP fallback', () async {
    final discovery = FakeDiscovery();
    final capture = CaptureSession(DiskCamera(Directory.systemTemp, 1));
    final pair = PairController(
      capture,
      () async => Directory.systemTemp,
      discovery: discovery,
    );
    try {
      expect(discovery.searches, 0);
      await pair.search();
      discovery.changed!([
        const CameraPeer('Camera', '192.168.43.1', 45872),
        const CameraPeer('External', '8.8.8.8', 45872),
      ]);
      expect(pair.peers.single.address, '192.168.43.1');
      discovery.changed!([]);
      expect(pair.peers, isEmpty);
      await pair.stopSearch();
      discovery.changed!([const CameraPeer('Stale', '192.168.1.2', 45872)]);
      expect(pair.peers, isEmpty);
      expect(pair.discoveryStatus, contains('manual'));
      discovery.fail = true;
      await pair.search();
      expect(pair.searching, isFalse);
      expect(pair.discoveryStatus, contains('IP'));
      await pair.join('8.8.8.8', '000123');
      expect(pair.status, contains('IP local'));
      await pair.join('192.168.1.2', 'abc');
      expect(pair.status, contains('seis cifras'));
      expect(PairController.parseEndpoint('192.168.43.1'), (
        '192.168.43.1',
        45872,
      ));
    } finally {
      await pair.disconnect();
      pair.dispose();
      capture.dispose();
    }
  });

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(1366, 1024),
  ]) {
    testWidgets('pairing has readable six-digit and manual controls at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = CaptureSession(DiskCamera(Directory.systemTemp, 1));
      final pair = PairController(capture, () async => Directory.systemTemp);
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionScreen(pair: pair, installedVersion: '0.5.1 (6)'),
        ),
      );
      expect(find.text('Instalada: 0.5.1 (6)'), findsOneWidget);
      expect(find.text('Conecta con seis cifras.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Código de seis cifras'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(find.byType(TextField).last, '000 123');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '000123',
      );
      expect(tester.takeException(), isNull);
      pair.hosting = true;
      pair.pairingCode = '000123';
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: ConnectionScreen(pair: pair)));
      expect(find.text('000 123'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      pair.dispose();
      capture.dispose();
    });
  }
}
