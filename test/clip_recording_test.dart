import 'dart:async';

import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_fakes.dart';

void main() {
  late RecordingCamera camera;
  late MemoryClipStore store;
  late CaptureSession session;

  setUp(() {
    camera = RecordingCamera();
    store = MemoryClipStore();
    session = CaptureSession(camera, clips: store);
  });

  tearDown(() async {
    await session.stop();
    session.dispose();
  });

  test('recording requires an explicitly activated camera', () async {
    await session.startClip();
    expect(camera.events, isEmpty);
    expect(session.canRecord, isFalse);
  });

  test(
    'concurrent starts use one owner and finalizing preserves preview',
    () async {
      await session.start();
      await Future.wait([
        session.startClip(),
        session.startClip(),
        session.startClip(),
      ]);
      expect(camera.events, ['open', 'record']);
      expect(session.isRecording, isTrue);
      await Future.wait([session.finishClip(), session.finishClip()]);
      expect(camera.events, ['open', 'record', 'finalize']);
      expect(store.writes, 1);
      expect(session.status, CaptureStatus.live);
      expect(session.canRecord, isTrue);
    },
  );

  test(
    'background during native start finalizes before releasing camera',
    () async {
      await session.start();
      camera.starting = Completer<void>();
      final start = session.startClip();
      await Future<void>.delayed(Duration.zero);
      final background = session.setForeground(false);
      camera.starting!.complete();
      await Future.wait([start, background]);
      expect(camera.events, ['open', 'record', 'finalize', 'close']);
      expect(session.status, CaptureStatus.suspended);
      expect(store.writes, 1);
      await session.setForeground(true);
      expect(camera.count('record'), 1);
      expect(session.clipBusy, isFalse);
    },
  );

  test(
    'leaving during storage preparation does not start native recording',
    () async {
      await session.start();
      store.loading = Completer<void>();
      final start = session.startClip();
      await Future<void>.delayed(Duration.zero);
      final stop = session.stop();
      store.loading!.complete();
      await Future.wait([start, stop]);
      expect(camera.events, ['open', 'close']);
      expect(session.clipBusy, isFalse);
    },
  );

  test('background during finalization cannot finalize a clip twice', () async {
    await session.start();
    await session.startClip();
    camera.stopping = Completer<String>();
    final finish = session.finishClip();
    await Future<void>.delayed(Duration.zero);
    final background = session.setForeground(false);
    camera.stopping!.complete('fake.mp4');
    await Future.wait([finish, background]);
    expect(camera.events, ['open', 'record', 'finalize', 'close']);
    expect(store.writes, 1);
  });

  test(
    'dispose during native start cleans up late result without notifying',
    () async {
      await session.start();
      camera.starting = Completer<void>();
      var notifications = 0;
      session.addListener(() => notifications++);
      final start = session.startClip();
      await Future<void>.delayed(Duration.zero);
      session.dispose();
      final beforeCompletion = notifications;
      camera.starting!.complete();
      await start;
      await Future<void>.delayed(Duration.zero);
      expect(camera.events, ['open', 'record', 'finalize', 'close']);
      expect(store.writes, 1);
      expect(notifications, beforeCompletion);
    },
  );

  test(
    'a failed native start releases owner and permits manual recovery',
    () async {
      await session.start();
      camera.failStart = true;
      await session.startClip();
      expect(session.status, CaptureStatus.failed);
      expect(camera.count('close'), 1);
      camera.failStart = false;
      await session.start();
      await session.startClip();
      expect(session.isRecording, isTrue);
    },
  );

  test('native finalization failure closes camera and is visible', () async {
    await session.start();
    await session.startClip();
    camera.failStop = true;
    await session.finishClip();
    expect(camera.events, ['open', 'record', 'finalize', 'close']);
    expect(session.status, CaptureStatus.failed);
    expect(session.failure?.code, 'recording_failed');
    expect(store.writes, 0);
  });

  test(
    'storage failure leaves preview live and next clip can succeed',
    () async {
      await session.start();
      await session.startClip();
      store.failWrite = true;
      await session.finishClip();
      expect(session.clipMessage, 'Sin espacio disponible.');
      expect(session.status, CaptureStatus.live);
      expect(camera.count('close'), 0);
      store.failWrite = false;
      await session.startClip();
      await session.finishClip();
      expect(store.clips, hasLength(1));
    },
  );

  test(
    'unavailable storage never starts recording or closes healthy preview',
    () async {
      await session.start();
      store.failList = true;
      await session.startClip();
      expect(session.clipBusy, isFalse);
      expect(session.clipMessage, contains('almacenamiento'));
      expect(camera.events, ['open']);
      expect(session.status, CaptureStatus.live);
    },
  );

  test('duration limit finalizes without closing the camera', () async {
    session.dispose();
    session = CaptureSession(
      camera,
      clips: store,
      maxClipDuration: const Duration(milliseconds: 10),
    );
    final finished = Completer<void>();
    session.addListener(() {
      if (!session.clipBusy && store.writes == 1 && !finished.isCompleted) {
        finished.complete();
      }
    });
    await session.start();
    await session.startClip();
    await finished.future.timeout(const Duration(seconds: 5));
    expect(camera.events, ['open', 'record', 'finalize']);
    expect(store.writes, 1);
    expect(session.status, CaptureStatus.live);
    expect(session.clipBusy, isFalse);
  });
}
