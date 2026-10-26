import 'dart:async';
import 'dart:io';

import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/connection/pair_controller.dart';
import 'package:acrostella_analytics/src/remote/apollo_probe.dart';
import 'package:acrostella_analytics/src/remote/remote_models.dart';
import 'package:acrostella_analytics/src/remote/workspace_controller.dart';
import 'package:acrostella_analytics/src/remote/workspace_engine.dart';
import 'package:acrostella_analytics/src/remote/workspace_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_fakes.dart';

class TestWorkspaceEngine implements WorkspaceEngine {
  final output = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  int starts = 0, stops = 0;
  bool supported = true, failStop = false;
  Completer<void>? closing;
  @override
  Stream<Map<String, dynamic>> get events => output.stream;
  @override
  Future<WorkspaceCapabilities> capabilities() async => WorkspaceCapabilities(
    platform: 'test',
    integrated: supported,
    h264Hardware: true,
    hevcHardware: true,
  );
  @override
  Future<void> pair(WorkspaceHost host) async {}
  @override
  Future<WorkspaceApplications> applications(WorkspaceHost host) async =>
      const WorkspaceApplications(
        apps: [
          {'id': '1', 'name': 'Desktop'},
        ],
        permission: 0,
      );
  @override
  Future<void> connect({
    required WorkspaceHost host,
    required String appId,
    required RemoteProfile profile,
    bool virtualDisplay = false,
  }) async {
    starts++;
  }

  @override
  Future<void> disconnect() async {
    stops++;
    if (failStop) throw StateError('not closed');
    await closing?.future;
  }

  @override
  Future<void> input(Map<String, dynamic> event) async {}
  @override
  Future<void> keyboard(bool visible) async {}
}

void main() {
  test('profiles and hosts round trip; invalid input never overwrites prior settings', () async {
    final dir = await Directory.systemTemp.createTemp('workspace-store-');
    try {
      final store = WorkspaceStore(() async => dir);
      final defaults = await store.read();
      expect(defaults.selectedProfile, 'balanced');
      const profile = RemoteProfile(
        id: 'wifi',
        name: 'Mi Wi-Fi',
        width: 2732,
        height: 2048,
        bitrateMbps: 8,
      );
      const host = WorkspaceHost(
        id: 'pc1',
        name: 'Apollo',
        address: '100.64.0.8:47989',
      );
      await store.write(
        const WorkspacePreferences(
          hosts: [host],
          customProfiles: [profile],
          selectedProfile: 'wifi',
        ),
      );
      final loaded = await WorkspaceStore(() async => dir).read();
      expect(loaded.customProfiles.single.width, 2732);
      expect(loaded.hosts.single.address, host.address);
      final original = await File('${dir.path}/workspace-v1.json')
          .readAsString();
      await expectLater(
        store.write(
          const WorkspacePreferences(
            customProfiles: [
              RemoteProfile(
                id: 'bad',
                name: 'Bad',
                width: 2733,
                height: 2048,
                bitrateMbps: 8,
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        await File('${dir.path}/workspace-v1.json').readAsString(),
        original,
      );
    } finally {
      await dir.delete(recursive: true);
    }
  });
  test('endpoints admit LAN and tailnet, reject credentials/public addresses and distinguish probe time', () {
    for (final input in [
      '192.168.1.2',
      '100.64.2.3:47990',
      'pc.tailnet.ts.net',
      'apollo.local',
      '[fd7a:115c:a1e0::1]:47989',
    ]) {
      expect(WorkspaceEndpoint.parse(input).port, greaterThan(0));
    }
    for (final input in [
      '8.8.8.8',
      'https://pc.ts.net',
      'http://user:pass@192.168.1.2',
      '192.168.1.2/launch',
      'example.com',
      '192.168.1.2?key=x',
    ]) {
      expect(
        () => WorkspaceEndpoint.parse(input),
        throwsFormatException,
        reason: input,
      );
    }
    const xml =
        '<root status_code="200"><hostname>Mi PC</hostname><uniqueid>server1</uniqueid><appversion>7.1</appversion><Permission>0</Permission></root>';
    final info = ApolloObservation.parse(xml, const Duration(milliseconds: 38));
    expect(info.queryMilliseconds, 38);
    expect(info.serverId, 'server1');
    expect(
      () => ApolloObservation.parse('<!DOCTYPE a><root/>', Duration.zero),
      throwsFormatException,
    );
    expect(
      RemoteMetrics.fromNative({'receivedFps': 59.8, 'decodeMs': double.nan})
          .decodeMs,
      isNull,
    );
    expect(RemoteMetrics.fromNative({}).networkRttMs, isNull);
  });
  test('real local HTTP probe bounds content, rejects redirects and parses GameStream without trusting pairing', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final listener = server.listen((request) async {
      expect(request.uri.path, '/serverinfo');
      request.response.write(
        '<root status_code="200"><hostname>Loopback Apollo</hostname><uniqueid>synthetic</uniqueid><appversion>7.1</appversion><PairStatus>1</PairStatus></root>',
      );
      await request.response.close();
    });
    try {
      final value = await ApolloProbe().inspect(
        WorkspaceEndpoint('127.0.0.1', server.port),
      );
      expect(value.name, 'Loopback Apollo');
      expect(value.codecModes, isNull);
    } finally {
      await server.close(force: true);
      await listener.cancel();
    }
  });
  for (final activeRecording in [true, false]) {
    test(
      'desktop start preserves ${activeRecording ? 'recording' : 'paired camera'} and does not allocate its engine',
      () async {
        final dir = await Directory.systemTemp.createTemp('workspace-guard-');
        final camera = RecordingCamera(), store = MemoryClipStore();
        final capture = CaptureSession(camera, clips: store);
        final pair = PairController(capture, () async => dir);
        final engine = TestWorkspaceEngine();
        final controller = WorkspaceController(
          store: WorkspaceStore(() async => dir),
          engine: engine,
          capture: capture,
          pair: pair,
        );
        try {
          await controller.load();
          await capture.start();
          if (activeRecording) {
            await capture.startClip();
          } else {
            pair.hosting = true;
          }
          final before = List.of(camera.events);
          await controller.connect(
            const WorkspaceHost(
              id: 'pc',
              name: 'PC',
              address: '127.0.0.1:47989',
            ),
            '1',
          );
          expect(engine.starts, 0);
          expect(camera.events, before);
          expect(controller.state, WorkspaceState.idle);
          if (activeRecording) expect(capture.isRecording, isTrue);
        } finally {
          pair.hosting = false;
          controller.dispose();
          await pair.disconnect();
          pair.dispose();
          await capture.stop();
          capture.dispose();
          await engine.output.close();
          await dir.delete(recursive: true);
        }
      },
    );
  }
  test('every desktop close caller waits for native teardown before camera restoration', () async {
    final dir = await Directory.systemTemp.createTemp('workspace-close-');
    final camera = RecordingCamera();
    final capture = CaptureSession(camera, clips: MemoryClipStore());
    final pair = PairController(capture, () async => dir),
        engine = TestWorkspaceEngine();
    final controller = WorkspaceController(
      store: WorkspaceStore(() async => dir),
      engine: engine,
      capture: capture,
      pair: pair,
    );
    try {
      await controller.load();
      await capture.start();
      await controller.connect(
        const WorkspaceHost(id: 'pc', name: 'PC', address: '127.0.0.1:47989'),
        '1',
      );
      expect(capture.status, CaptureStatus.idle);
      expect(controller.connected, isFalse);
      engine.output.add({'type': 'state', 'state': 'connected'});
      expect(controller.connected, isTrue);
      engine.closing = Completer<void>();
      var secondClosed = false;
      final first = controller.disconnect(),
          second = controller.disconnect().then((_) => secondClosed = true);
      await Future<void>.delayed(Duration.zero);
      expect(secondClosed, isFalse);
      expect(camera.count('open'), 1);
      engine.closing!.complete();
      await Future.wait([first, second]);
      expect(camera.count('open'), 2);
      expect(engine.stops, 1);
      expect(controller.state, WorkspaceState.idle);
    } finally {
      controller.dispose();
      await pair.disconnect();
      pair.dispose();
      await capture.stop();
      capture.dispose();
      await engine.output.close();
      await dir.delete(recursive: true);
    }
  });
  test('unconfirmed native shutdown quarantines the desktop and does not reopen the camera', () async {
    final dir = await Directory.systemTemp.createTemp('workspace-failed-');
    final camera = RecordingCamera();
    final capture = CaptureSession(camera, clips: MemoryClipStore());
    final pair = PairController(capture, () async => dir),
        engine = TestWorkspaceEngine();
    final controller = WorkspaceController(
      store: WorkspaceStore(() async => dir),
      engine: engine,
      capture: capture,
      pair: pair,
    );
    try {
      await controller.load();
      await capture.start();
      await controller.connect(
        const WorkspaceHost(id: 'pc', name: 'PC', address: '127.0.0.1:47989'),
        '1',
      );
      engine.failStop = true;
      await controller.disconnect();
      expect(controller.state, WorkspaceState.failed);
      expect(camera.count('open'), 1);
      engine.failStop = false;
      await controller.disconnect();
      expect(camera.count('open'), 2);
    } finally {
      controller.dispose();
      await pair.disconnect();
      pair.dispose();
      await capture.stop();
      capture.dispose();
      await engine.output.close();
      await dir.delete(recursive: true);
    }
  });
}
