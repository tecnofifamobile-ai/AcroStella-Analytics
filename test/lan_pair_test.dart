import 'dart:io';
import 'dart:typed_data';

import 'package:acrostella_analytics/src/capture/capture_device.dart';
import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/connection/pair_controller.dart';
import 'package:acrostella_analytics/src/connection/secure_channel.dart';
import 'package:flutter_test/flutter_test.dart';

class DiskCamera implements VideoCaptureDevice {
  DiskCamera(this.dir, this.value);
  final Directory dir;
  final int value;
  int opens = 0, recordings = 0, stops = 0;
  @override
  Future<CaptureFormat> open() async {
    opens++;
    return const CaptureFormat(
      width: 1920,
      height: 1080,
      cameraName: 'synthetic',
    );
  }

  @override
  Future<void> close() async {}
  @override
  Future<void> startRecording() async {
    recordings++;
  }

  @override
  Future<String> stopRecording() async {
    stops++;
    final f = File('${dir.path}/native-$recordings.mp4');
    await f.writeAsBytes(List.filled(160 * 1024, value));
    return f.path;
  }
}

void main() {
  test(
    'clock estimation accounts for remote processing and chooses lowest RTT',
    () {
      final a = ClockEstimate.sample(1000, 1600, 1800, 1600);
      expect(a.offsetUs, 400);
      expect(a.roundTripUs, 400);
      final b = ClockEstimate.sample(1000, 1510, 1520, 1030);
      expect(ClockEstimate.best([a, b]), same(b));
      expect(() => ClockEstimate.sample(2, 0, 1, 1), throwsFormatException);
      expect(PairController.localAddress('192.168.43.1'), isTrue);
      expect(PairController.localAddress('172.16.0.1'), isTrue);
      expect(PairController.localAddress('8.8.8.8'), isFalse);
      expect(PairController.localAddress('example.com'), isFalse);
    },
  );

  Future<(SecureChannel, SecureChannel, ServerSocket)> channels({
    bool wrongCode = false,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final accepted = server.first;
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      server.port,
    );
    final other = await accepted;
    final code = SecureChannel.newCode();
    try {
      final pair = await Future.wait([
        SecureChannel.connect(other, code, server: true),
        SecureChannel.connect(
          socket,
          wrongCode ? SecureChannel.newCode() : code,
          server: false,
        ),
      ]);
      return (pair[0], pair[1], server);
    } catch (_) {
      socket.destroy();
      other.destroy();
      await server.close();
      rethrow;
    }
  }

  test('encrypted TCP carries ordered messages in both directions and bounds frames', () async {
    final (a, b, server) = await channels();
    try {
      await b.send({'type': 'test', 'value': 'private synthetic message'});
      expect((await a.receive())['value'], 'private synthetic message');
      await a.send({'type': 'reply', 'value': 42});
      expect((await b.receive())['value'], 42);
      b.socket.add(
        Uint8List(4)
          ..buffer.asByteData().setUint32(0, SecureChannel.maxFrame + 1),
      );
      await b.socket.flush();
      await expectLater(a.receive(), throwsFormatException);
    } finally {
      a.close();
      b.close();
      await server.close();
    }
  });
  test('incorrect pairing secret cannot authenticate', () async {
    await expectLater(channels(wrongCode: true), throwsA(anything));
  });

  test('two camera owners coordinate, transfer verified media and retain grouped library across reopen', () async {
    final root = await Directory.systemTemp.createTemp('acrostella-pair-');
    final remoteDir = await Directory('${root.path}/remote').create();
    final localDir = await Directory('${root.path}/local').create();
    FileClipStore store(Directory d) => FileClipStore(
      () async => Directory('${d.path}/library'),
      durable: true,
      maxClipBytes: 1024 * 1024,
      maxBytes: 4 * 1024 * 1024,
    );
    final remoteStore = store(remoteDir), localStore = store(localDir);
    final remoteCamera = DiskCamera(remoteDir, 72),
        localCamera = DiskCamera(localDir, 31);
    final remoteCapture = CaptureSession(remoteCamera, clips: remoteStore),
        localCapture = CaptureSession(localCamera, clips: localStore);
    final host = PairController(remoteCapture, () async => remoteDir);
    final center = PairController(localCapture, () async => localDir);
    try {
      await host.host();
      expect(host.invitation, isNotNull, reason: host.status);
      final uri = Uri.parse(host.invitation!).replace(host: '127.0.0.1');
      await center.join(uri.toString());
      expect(center.connected, isTrue, reason: center.status);
      await center.startExercise();
      expect(center.recording, isTrue, reason: center.status);
      expect(remoteCapture.isRecording, isTrue);
      await center.finishExercise();
      final paired = center.takeCompleted();
      expect(paired, isNotNull, reason: center.status);
      expect(paired!.hasSecondAngle, isTrue, reason: center.status);
      expect(paired.saved, isFalse);
      expect((await File(paired.path).readAsBytes()).first, 31);
      expect((await File(paired.secondaryPath!).readAsBytes()).first, 72);
      expect((await remoteStore.list()).single.saved, isTrue);
      expect((await store(localDir).list()).single.secondaryBytes, 160 * 1024);
      expect(remoteCamera.opens, 1);
      expect(localCamera.opens, 1);
      await center.startExercise();
      expect(center.recording, isTrue, reason: center.status);
      await center.finishExercise();
      expect(center.takeCompleted()!.hasSecondAngle, isTrue);
      expect(remoteCamera.opens, 1);
      expect(localCamera.opens, 1);
      expect((await localStore.list()).length, 2);
    } finally {
      await center.disconnect();
      await host.disconnect();
      center.dispose();
      host.dispose();
      await remoteCapture.stop();
      await localCapture.stop();
      remoteCapture.dispose();
      localCapture.dispose();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 45)));
  test('disconnect during recording preserves local exercise and allows an explicit return to solo capture', () async {
    final root = await Directory.systemTemp.createTemp(
      'acrostella-disconnect-',
    );
    final a = await Directory('${root.path}/a').create(),
        b = await Directory('${root.path}/b').create();
    final firstStore = FileClipStore(
      () async => Directory('${a.path}/library'),
      durable: true,
      maxClipBytes: 1024 * 1024,
      maxBytes: 4 * 1024 * 1024,
    );
    final secondStore = FileClipStore(
      () async => Directory('${b.path}/library'),
      durable: true,
      maxClipBytes: 1024 * 1024,
      maxBytes: 4 * 1024 * 1024,
    );
    final first = CaptureSession(DiskCamera(a, 1), clips: firstStore),
        second = CaptureSession(DiskCamera(b, 2), clips: secondStore);
    final host = PairController(first, () async => a),
        center = PairController(second, () async => b);
    try {
      await host.host();
      await center.join(
        Uri.parse(host.invitation!).replace(host: '127.0.0.1').toString(),
      );
      await center.startExercise();
      expect(center.recording, isTrue, reason: center.status);
      await host.disconnect();
      // Wait for local finalization and failed paired transfer to settle.
      for (var i = 0; i < 100 && (center.recording || center.busy); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final saved = await secondStore.list();
      expect(saved, hasLength(1));
      expect(saved.single.saved, isTrue);
      expect(saved.single.hasSecondAngle, isFalse);
      expect((await firstStore.list()).single.saved, isTrue);
      await center.keepLocal();
      expect(center.transferPending, isFalse);
      expect(second.canRecord, isTrue);
    } finally {
      await center.disconnect();
      await host.disconnect();
      center.dispose();
      host.dispose();
      await first.stop();
      await second.stop();
      first.dispose();
      second.dispose();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
