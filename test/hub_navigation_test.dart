import 'dart:io';

import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/capture/flutter_camera_device.dart';
import 'package:acrostella_analytics/src/clips/clip_player_screen.dart';
import 'package:acrostella_analytics/src/connection/pair_controller.dart';
import 'package:acrostella_analytics/src/files/document_store.dart';
import 'package:acrostella_analytics/src/hub/hub_screen.dart';
import 'package:acrostella_analytics/src/remote/workspace_controller.dart';
import 'package:acrostella_analytics/src/remote/workspace_store.dart';
import 'package:acrostella_analytics/src/training/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'clip_player_screen_test.dart'
    show FileVideoPlatform, flushNativeDisposal;
import 'workspace_test.dart' show TestWorkspaceEngine;
import 'support/recording_fakes.dart';

void main() {
  for (final size in [
    const Size(393, 852),
    const Size(852, 393),
    const Size(1366, 1024),
  ]) {
    testWidgets('Hub switches modules at $size without stopping an exercise', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final camera = RecordingCamera(), store = MemoryClipStore();
      final capture = CaptureSession(camera, clips: store);
      final pair = PairController(capture, () async => Directory.systemTemp);
      final engine = TestWorkspaceEngine()..supported = false;
      final workspace = WorkspaceController(
        store: WorkspaceStore(() async => Directory.systemTemp),
        engine: engine,
        capture: capture,
        pair: pair,
      );
      workspace.loading = false;
      try {
        await capture.start();
        await tester.pumpWidget(
          MaterialApp(
            home: AcroStellaHub(
              capture: capture,
              device: FlutterCameraDevice(),
              pair: pair,
              workspace: workspace,
              documents: DocumentStore(() async => Directory.systemTemp),
              onToggleTheme: () {},
            ),
          ),
        );
        await tester.pump();
        expect(find.text('AcroStella Hub'), findsOneWidget);
        await tester.tap(find.text('Analytics'));
        await tester.pump(const Duration(milliseconds: 300));
        final state = tester.state(find.byType(TrainingScreen));
        await tester.tap(find.text('Iniciar ejercicio'));
        await tester.pump(const Duration(milliseconds: 100));
        expect(capture.isRecording, isTrue);
        final events = List.of(camera.events);
        await tester.tap(find.text('Workspace'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Remote Workspace'), findsOneWidget);
        expect(capture.isRecording, isTrue);
        expect(camera.events, events);
        await tester.tap(find.text('Dispositivos'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Device Center'), findsOneWidget);
        expect(capture.isRecording, isTrue);
        await tester.tap(find.text('Analytics'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.state(find.byType(TrainingScreen)), same(state));
        expect(camera.count('open'), 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        workspace.dispose();
        await pair.disconnect();
        pair.dispose();
        await capture.stop();
        capture.dispose();
        await engine.output.close();
      }
    });
  }
  testWidgets(
    'hidden analysis pauses its decoder and returns to the same review state',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = VideoPlayerPlatform.instance,
          video = FileVideoPlatform();
      VideoPlayerPlatform.instance = video;
      final camera = RecordingCamera(), store = MemoryClipStore();
      final clip = await store.add(
        '/fake/exercise.mp4',
        DateTime.now(),
        const Duration(seconds: 10),
      );
      await store.updateDetails(clip.id, saved: true);
      final capture = CaptureSession(camera, clips: store),
          pair = PairController(
            CaptureSession(RecordingCamera()),
            () async => Directory.systemTemp,
          );
      final engine = TestWorkspaceEngine()..supported = false;
      final workspace = WorkspaceController(
        store: WorkspaceStore(() async => Directory.systemTemp),
        engine: engine,
        capture: capture,
        pair: pair,
      )..loading = false;
      try {
        await capture.start();
        await tester.pumpWidget(
          MaterialApp(
            home: AcroStellaHub(
              capture: capture,
              device: FlutterCameraDevice(),
              pair: pair,
              workspace: workspace,
              documents: DocumentStore(() async => Directory.systemTemp),
              onToggleTheme: () {},
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Último ejercicio disponible'));
        await tester.pumpAndSettle();
        final state = tester.state(find.byType(ClipPlayerScreen));
        await tester.tap(find.byTooltip('Reproducir vídeo'));
        await tester.pump();
        expect(video.calls, contains('play'));
        final before = video.calls.where((e) => e == 'pause').length;
        await tester.tap(find.text('Workspace'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          video.calls.where((e) => e == 'pause').length,
          greaterThan(before),
        );
        expect(video.calls, isNot(contains('dispose')));
        await tester.tap(find.text('Analytics'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.state(find.byType(ClipPlayerScreen)), same(state));
        expect(camera.count('open'), 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await flushNativeDisposal(tester);
        workspace.dispose();
        await pair.disconnect();
        pair.capture.dispose();
        pair.dispose();
        await capture.stop();
        capture.dispose();
        await engine.output.close();
        VideoPlayerPlatform.instance = previous;
      }
    },
  );
}
