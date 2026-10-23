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
    await tester.ensureVisible(find.byTooltip('Medir ángulo'));
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
      'start stop automatically reviews and delete releases decoder at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        store.clips.clear();
        store.writes = 0;
        final camera = RecordingCamera();
        final session = CaptureSession(camera, clips: store);
        await tester.pumpWidget(
          MaterialApp(
            home: TrainingScreen(
              capture: session,
              device: FlutterCameraDevice(),
              onToggleTheme: () {},
            ),
          ),
        );
        // Starting the exercise also activates the camera: one deliberate tap.
        await tester.tap(find.text('Iniciar ejercicio'));
        await tester.pumpAndSettle();
        expect(camera.events, ['open', 'record']);
        await tester.tap(find.textContaining('Revisar ·'));
        await tester.pumpAndSettle();
        expect(find.text('Revisar ejercicio'), findsOneWidget);
        expect(platform.calls, contains('play'));
        expect(store.readers['clip-1'], 1);
        expect(camera.events, ['open', 'record', 'finalize']);
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await tester.pump();
        await flushNativeDisposal(tester);
        await tester.pumpAndSettle();
        expect(store.clips, isEmpty);
        expect(store.readers, isEmpty);
        expect(platform.calls, contains('dispose'));
        expect(find.text('Iniciar ejercicio'), findsOneWidget);
        expect(camera.count('close'), 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await session.stop();
        session.dispose();
      },
    );
  }

  testWidgets(
    'save from immediate review preserves annotations and another exercise reuses owner',
    (tester) async {
      store.clips.clear();
      store.writes = 0;
      final camera = RecordingCamera();
      final session = CaptureSession(camera, clips: store);
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(
            capture: session,
            device: FlutterCameraDevice(),
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.tap(find.text('Iniciar ejercicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Revisar ·'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar ejercicio'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Equilibrio 3');
      await tester.enterText(
        find.byType(TextField).last,
        'Revisar la recepción',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(store.clips.single.saved, isTrue);
      expect(store.clips.single.name, 'Equilibrio 3');
      expect(store.clips.single.memo, 'Revisar la recepción');
      await tester.tap(find.text('Otro ejercicio'));
      await tester.pump();
      await flushNativeDisposal(tester);
      await tester.pumpAndSettle();
      expect(camera.events, ['open', 'record', 'finalize', 'record']);
      expect(session.isRecording, isTrue);
      expect(store.clips.single.saved, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.stop();
      session.dispose();
    },
  );

  testWidgets('file playback seek and slow motion preserve camera owner', (
    tester,
  ) async {
    await store.updateDetails('clip-1', saved: true);
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
    await tester.tap(find.byTooltip('Mi biblioteca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();
    expect(platform.source?.sourceType, DataSourceType.file);
    expect(store.readers['clip-1'], 1);
    await tester.tap(find.byTooltip('Pausar vídeo'));
    await tester.pump();
    final speeds = find.byType(DropdownButton<double>).first;
    await tester.tap(speeds);
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.5×').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reproducir vídeo'));
    await tester.pump();
    expect(platform.calls, contains('speed:0.5'));
    await tester.tap(find.byTooltip('Pausar vídeo'));
    await tester.pump();
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pump();
    expect(platform.calls, contains('seek'));
    expect(platform.position, greaterThan(Duration.zero));
    expect(camera.events, ['open']);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await flushNativeDisposal(tester);
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
  testWidgets(
    'automatic limit opens exactly one review without a second button',
    (tester) async {
      store.clips.clear();
      store.writes = 0;
      final camera = RecordingCamera();
      final session = CaptureSession(
        camera,
        clips: store,
        maxClipDuration: const Duration(seconds: 2),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TrainingScreen(
            capture: session,
            device: FlutterCameraDevice(),
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.tap(find.text('Iniciar ejercicio'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(ClipPlayerScreen), findsOneWidget);
      expect(camera.count('finalize'), 1);
      expect(store.writes, 1);
      expect(session.takeCompletedExercise(), isNull);
      expect(camera.count('close'), 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await flushNativeDisposal(tester);
      await session.stop();
      session.dispose();
    },
  );
  testWidgets(
    'back during decoder initialization preserves pending video until cleanup',
    (tester) async {
      platform.creation = Completer<int>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ClipPlayerScreen(store: store, clipId: 'clip-1'),
                  ),
                ),
                child: const Text('Abrir revisión'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir revisión'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.readers['clip-1'], 1);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Abrir revisión'), findsOneWidget);
      expect(store.clips, hasLength(1));
      expect(store.readers['clip-1'], 1);
      platform.creation!.complete(1);
      await tester.pump();
      await flushNativeDisposal(tester);
      await tester.pumpAndSettle();
      expect(store.readers, isEmpty);
      expect(store.clips, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
