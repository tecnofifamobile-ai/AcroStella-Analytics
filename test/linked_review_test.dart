import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:acrostella_analytics/src/clips/clip_player_screen.dart';
import 'package:acrostella_analytics/src/clips/clip_library_screen.dart';
import 'package:acrostella_analytics/src/clips/clip_store.dart';
import 'package:acrostella_analytics/src/clips/linked_playback.dart';
import 'package:acrostella_analytics/src/clips/review_viewport.dart';
import 'package:acrostella_analytics/src/clips/video_annotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'clip_player_screen_test.dart' show flushNativeDisposal;
import 'support/recording_fakes.dart';

class TwoVideoPlatform extends VideoPlayerPlatform {
  int next = 0;
  final streams = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  final speeds = <int, double>{};
  final playing = <int, bool>{};
  final disposed = <int>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++next;
    streams[id] = StreamController<VideoEvent>()
      ..add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: Duration(seconds: id == 1 ? 10 : 8),
          size: const Size(1280, 720),
        ),
      );
    positions[id] = Duration.zero;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) => streams[id]!.stream;
  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
    await streams[id]!.close();
  }

  @override
  Future<void> setLooping(int id, bool looping) async {}
  @override
  Future<void> setVolume(int id, double volume) async {}
  @override
  Future<void> play(int id) async {
    playing[id] = true;
  }

  @override
  Future<void> pause(int id) async {
    playing[id] = false;
  }

  @override
  Future<void> seekTo(int id, Duration p) async {
    positions[id] = p;
  }

  @override
  Future<void> setPlaybackSpeed(int id, double speed) async {
    speeds[id] = speed;
  }

  @override
  Future<Duration> getPosition(int id) async => positions[id]!;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => ColoredBox(
    color: options.playerId == 1
        ? const Color(0xFF253646)
        : const Color(0xFF31453C),
    child: Center(
      child: Text(
        'VÍDEO SINTÉTICO ${options.playerId}',
        style: const TextStyle(color: Colors.white38),
      ),
    ),
  );
}

void main() {
  late TwoVideoPlatform platform;
  late VideoPlayerPlatform previous;
  setUp(() {
    previous = VideoPlayerPlatform.instance;
    platform = TwoVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() {
    VideoPlayerPlatform.instance = previous;
  });

  testWidgets(
    'common interval, serialized scrubs, speed, drift correction and buffering affect both decoders',
    (tester) async {
      final a = VideoPlayerController.file(File('/fake/a.mp4')),
          b = VideoPlayerController.file(File('/fake/b.mp4'));
      await a.initialize();
      await b.initialize();
      final linked = LinkedPlayback(a, b, offsetUs: -1000000);
      expect(linked.start, const Duration(seconds: 1));
      expect(linked.end, const Duration(seconds: 9));
      await linked.seek(Duration.zero);
      expect(platform.positions[1], const Duration(seconds: 1));
      expect(platform.positions[2], Duration.zero);
      await Future.wait([
        linked.seek(const Duration(seconds: 3)),
        linked.seek(const Duration(seconds: 5)),
      ]);
      expect(platform.positions[1], const Duration(seconds: 5));
      expect(platform.positions[2], const Duration(seconds: 4));
      await linked.speed(.5);
      await linked.play();
      expect(platform.playing.values, everyElement(isTrue));
      expect(platform.speeds.values, everyElement(.5));
      platform.positions[2] = const Duration(seconds: 6);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pump();
      await tester.pump();
      expect(platform.positions[2], const Duration(seconds: 4));
      b.value = b.value.copyWith(isBuffering: true);
      await tester.pump();
      expect(platform.playing.values, everyElement(isFalse));
      await expectLater(linked.align(20000000), throwsStateError);
      expect(linked.offsetUs, -1000000);
      linked.dispose();
      final closing = Future.wait([a.dispose(), b.dispose()]);
      await flushNativeDisposal(tester);
      await closing;
    },
  );

  for (final size in [
    const Size(393, 852),
    const Size(852, 393),
    const Size(1366, 1024),
  ]) {
    testWidgets(
      'dual review zoom, drawing on second angle and immersive back retain grouped media at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryClipStore();
        store.clips.add(
          LocalClip(
            id: 'pair',
            path: '/fake/a.mp4',
            secondaryPath: '/fake/b.mp4',
            secondaryBytes: 100,
            bytes: 200,
            saved: true,
            createdAt: DateTime.utc(2026),
            elapsed: const Duration(seconds: 8),
            name: 'Equilibrio · dos ángulos',
            offsetUs: 0,
            clockUncertaintyUs: 20000,
          ),
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: RepaintBoundary(
              key: boundary,
              child: ClipPlayerScreen(store: store, clipId: 'pair'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReviewViewport), findsNWidgets(2));
        expect(platform.next, 2);
        final viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer).first,
        );
        viewer.transformationController!.value = Matrix4.identity()
          ..scaleByDouble(2, 2, 1, 1);
        await tester.pump();
        await tester.ensureVisible(find.text('Dibujar en Android'));
        await tester.tap(find.text('Dibujar en Android'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Dibujar línea'));
        await tester.tap(find.byTooltip('Dibujar línea'));
        await tester.pumpAndSettle();
        final rect = tester.getRect(
          find.byKey(const Key('annotation-surface')).last,
        );
        await tester.tapAt(
          rect.center + Offset(-rect.width * .15, -rect.height * .1),
        );
        await tester.pump();
        await tester.tapAt(
          rect.center + Offset(rect.width * .15, rect.height * .1),
        );
        await tester.pumpAndSettle();
        expect(store.savedNotes['pair']!.single.angle, 1);
        expect(store.savedNotes['pair']!.single.tool, AnnotationTool.line);
        await tester.tap(find.byTooltip('Ocultar controles'));
        await tester.pumpAndSettle();
        expect(find.text('Guardar ejercicio'), findsNothing);
        expect(find.byTooltip('Mostrar controles'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Ocultar controles'), findsOneWidget);
        expect(store.readers['pair'], 1);
        expect(tester.takeException(), isNull);
        if (size.width == 1366 &&
            Platform.environment['ACROSTELLA_SCREENSHOT'] == '1') {
          await tester.pump();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('artifacts/review-v05-synthetic.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await flushNativeDisposal(tester);
        await tester.pump();
        expect(store.readers, isEmpty);
        expect(platform.disposed.toSet(), {1, 2});
      },
    );
  }
  testWidgets(
    'library compares two attempts without changing files or retaining decoder leases',
    (tester) async {
      final store = MemoryClipStore();
      await store.add(
        '/fake/a.mp4',
        DateTime.utc(2026),
        const Duration(seconds: 10),
      );
      await store.add(
        '/fake/b.mp4',
        DateTime.utc(2026),
        const Duration(seconds: 8),
      );
      await store.updateDetails('clip-1', saved: true, name: 'Intento A');
      await store.updateDetails('clip-2', saved: true, name: 'Intento B');
      await tester.pumpWidget(
        MaterialApp(home: ClipLibraryScreen(store: store)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Comparar intentos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Comparar'));
      await tester.pumpAndSettle();
      expect(platform.next, 2);
      expect(store.readers, {'clip-1': 1, 'clip-2': 1});
      expect(find.text('Intento B'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await flushNativeDisposal(tester);
      await tester.pumpAndSettle();
      expect(store.readers, isEmpty);
      expect(store.clips, hasLength(2));
      expect(store.clips.every((c) => c.saved && !c.hasSecondAngle), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
