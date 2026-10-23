import 'dart:async';

import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/capture/flutter_camera_device.dart';
import 'package:acrostella_analytics/src/clips/clip_player_screen.dart';
import 'package:acrostella_analytics/src/clips/video_annotation.dart';
import 'package:acrostella_analytics/src/training/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/recording_fakes.dart';

// video_player awaits native subscription cancellation outside the widget
// test's fake clock, as in the plugin's own disposal tests.
Future<void> flushNativeDisposal(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

class FileVideoPlatform extends VideoPlayerPlatform {
  Completer<int>? creation;
  Completer<void>? disposal;
  DataSource? source;
  final calls = <String>[];
  Duration position = Duration.zero;
  late StreamController<VideoEvent> events;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    source = options.dataSource;
    final id = await (creation?.future ?? Future.value(1));
    events = StreamController<VideoEvent>();
    events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(1280, 720),
      ),
    );
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await disposal?.future;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
    calls.add('seek');
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async =>
      calls.add('speed:$speed');

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.black);
}

void main() {
  late FileVideoPlatform platform;
  late VideoPlayerPlatform previous;
  late MemoryClipStore store;

  setUp(() async {
    previous = VideoPlayerPlatform.instance;
    platform = FileVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    store = MemoryClipStore();
    await store.add(
      '/fake/clip.mp4',
      DateTime.utc(2026, 10, 22),
      const Duration(seconds: 10),
    );
  });

  tearDown(() => VideoPlayerPlatform.instance = previous);

  testWidgets('draws a timed angle in video coordinates and undo persists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClipPlayerScreen(store: store, clipId: 'clip-1'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Medir ángulo'));
    await tester.pump();
    final rect = tester.getRect(find.byKey(const Key('annotation-surface')));
    for (final point in const [
      Offset(.2, .7),
      Offset(.5, .4),
      Offset(.8, .7),
    ]) {
      await tester.tapAt(
        rect.topLeft + Offset(point.dx * rect.width, point.dy * rect.height),
      );
      await tester.pump();
    }
    final note = store.savedNotes['clip-1']!.single;
    expect(note.tool, AnnotationTool.angle);
    expect(note.points[0].dx, closeTo(.2, .001));
    expect(note.points[0].dy, closeTo(.7, .001));
    expect(note.start, Duration.zero);
    expect(note.end, const Duration(seconds: 3));
    expect(platform.calls, contains('pause'));
    await tester.tap(find.byTooltip('Deshacer dibujo'));
    await tester.pump();
    expect(store.savedNotes['clip-1'], isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await flushNativeDisposal(tester);
    expect(store.readers, isEmpty);
  });

  for (final size in [const Size(393, 852), const Size(852, 393)]) {
    testWidgets(
      'recording controls and cache navigation fit $size without stopping capture',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        store.clips.clear();
        final camera = RecordingCamera();
        final session = CaptureSession(camera, clips: store);
        await session.start();
        await tester.pumpWidget(
          MaterialApp(
            home: TrainingScreen(
              capture: session,
              device: FlutterCameraDevice(),
              onToggleTheme: () {},
            ),
          ),
        );
        await tester.tap(find.text('Grabar clip'));
        await tester.pump();
        expect(find.textContaining('Finalizar clip'), findsOneWidget);
        expect(camera.events, ['open', 'record']);
        await tester.tap(find.text('Clips locales'));
        await tester.pumpAndSettle();
        expect(session.isRecording, isTrue);
        await tester.pump(const Duration(seconds: 30));
        expect(session.clipBusy, isFalse);
        await tester.tap(find.byTooltip('Actualizar clips'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
        await tester.tap(find.byTooltip('Eliminar clip'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();
        expect(store.clips, isEmpty);
        expect(camera.events, ['open', 'record', 'finalize']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await session.stop();
        session.dispose();
      },
    );
  }

  testWidgets('file playback, seek and slow motion preserve the camera owner', (
    tester,
  ) async {
    final camera = RecordingCamera();
    final session = CaptureSession(camera, clips: store);
    await session.start();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingScreen(
          capture: session,
          device: FlutterCameraDevice(),
          onToggleTheme: () {},
        ),
      ),
    );
    await tester.tap(find.text('Clips locales'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();
    expect(platform.source?.sourceType, DataSourceType.file);
    expect(store.readers['clip-1'], 1);
    await tester.tap(find.byTooltip('Reproducir clip'));
    await tester.pump();
    expect(platform.calls, contains('play'));
    await tester.tap(find.byTooltip('Pausar clip'));
    await tester.pump();
    await tester.tap(find.byType(DropdownButton<double>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.5×').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reproducir clip'));
    await tester.pump();
    expect(platform.calls, contains('speed:0.5'));
    await tester.tap(find.byTooltip('Pausar clip'));
    await tester.pump();
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pump();
    expect(platform.calls, contains('seek'));
    expect(platform.position, greaterThan(Duration.zero));
    expect(camera.events, ['open']);
    await tester.tap(find.text('Volver al directo'));
    await tester.pumpAndSettle();
    await flushNativeDisposal(tester);
    expect(find.text('Grabar clip'), findsOneWidget);
    expect(store.readers, isEmpty);
    expect(platform.calls, contains('dispose'));
    expect(camera.events, ['open']);
    await tester.pumpWidget(const SizedBox.shrink());
    await session.stop();
    session.dispose();
  });

  testWidgets(
    'closing during native initialization pins until decoder disposal completes',
    (tester) async {
      platform.creation = Completer<int>();
      platform.disposal = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: ClipPlayerScreen(store: store, clipId: 'clip-1'),
        ),
      );
      await tester.pump();
      expect(store.readers['clip-1'], 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(store.readers['clip-1'], 1);
      platform.creation!.complete(1);
      await tester.pumpAndSettle();
      await flushNativeDisposal(tester);
      expect(platform.calls, contains('dispose'));
      expect(store.readers['clip-1'], 1);
      platform.disposal!.complete();
      await tester.pump();
      expect(store.readers, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
