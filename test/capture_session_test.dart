import 'dart:async';

import 'package:acrostella_analytics/src/capture/capture_device.dart';
import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:flutter_test/flutter_test.dart';

class TestCamera implements CaptureDevice {
  int opens = 0;
  int closes = 0;
  CaptureFailure? nextFailure;
  Completer<CaptureFormat>? opening;

  @override
  Future<CaptureFormat> open() async {
    opens++;
    final failure = nextFailure;
    nextFailure = null;
    if (failure != null) throw failure;
    return opening?.future ??
        const CaptureFormat(width: 1920, height: 1080, cameraName: 'test');
  }

  @override
  Future<void> close() async => closes++;
}

void main() {
  late TestCamera camera;
  late CaptureSession session;

  setUp(() {
    camera = TestCamera();
    session = CaptureSession(camera);
  });

  tearDown(() async {
    await session.stop();
    session.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test('does not request camera access on construction', () {
    expect(camera.opens, 0);
    expect(session.status, CaptureStatus.idle);
  });

  test('concurrent start requests open exactly one camera', () async {
    await Future.wait([session.start(), session.start(), session.start()]);
    expect(camera.opens, 1);
    expect(session.status, CaptureStatus.live);
    expect(session.format?.width, 1920);
  });

  test('stop during initialization closes the late native result', () async {
    camera.opening = Completer<CaptureFormat>();
    final start = session.start();
    await Future<void>.delayed(Duration.zero);
    expect(session.status, CaptureStatus.opening);
    final stop = session.stop();
    camera.opening!.complete(
      const CaptureFormat(width: 1280, height: 720, cameraName: 'test'),
    );
    await Future.wait([start, stop]);
    expect(session.status, CaptureStatus.idle);
    expect(session.format, isNull);
    expect(camera.closes, 1);
  });

  test('background suspension resumes only a requested camera', () async {
    await session.start();
    await session.setForeground(false);
    expect(session.status, CaptureStatus.suspended);
    expect(session.format, isNull);
    expect(camera.closes, 1);
    await session.setForeground(true);
    expect(session.status, CaptureStatus.live);
    expect(camera.opens, 2);
  });

  test('returning to foreground does not activate a stopped camera', () async {
    await session.start();
    await session.stop();
    await session.setForeground(false);
    await session.setForeground(true);
    expect(camera.opens, 1);
    expect(session.status, CaptureStatus.idle);
  });

  test('foreground notification does not reopen an active camera', () async {
    await session.start();
    await session.setForeground(true);
    expect(camera.opens, 1);
    expect(camera.closes, 0);
  });

  test(
    'permission failure is visible and a manual retry can recover',
    () async {
      camera.nextFailure = const CaptureFailure(
        'permission_denied',
        'Denegado',
      );
      await session.start();
      expect(session.status, CaptureStatus.failed);
      expect(session.failure?.code, 'permission_denied');
      await session.setForeground(true);
      expect(camera.opens, 1);
      expect(session.status, CaptureStatus.failed);
      await session.start();
      expect(session.status, CaptureStatus.live);
      expect(session.failure, isNull);
      expect(camera.opens, 2);
    },
  );

  test(
    'disposing during native opening releases the result without notifying',
    () async {
      camera.opening = Completer<CaptureFormat>();
      var notifications = 0;
      session.addListener(() => notifications++);
      final opening = session.start();
      await Future<void>.delayed(Duration.zero);
      session.dispose();
      final beforeCompletion = notifications;
      camera.opening!.complete(
        const CaptureFormat(width: 1920, height: 1080, cameraName: 'test'),
      );
      await opening;
      await Future<void>.delayed(Duration.zero);
      expect(camera.closes, 1);
      expect(notifications, beforeCompletion);
    },
  );
}
