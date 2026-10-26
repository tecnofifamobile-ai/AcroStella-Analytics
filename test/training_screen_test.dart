import 'package:acrostella_analytics/src/app.dart';
import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/capture/flutter_camera_device.dart';
import 'package:acrostella_analytics/src/training/training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_session_test.dart' show TestCamera;

void main() {
  for (final size in [
    const Size(1366, 1024),
    const Size(393, 852),
    const Size(852, 393),
  ]) {
    testWidgets('initial layout fits $size without requesting access', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const AcroStellaApp());
      expect(find.text('AcroStella Hub'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Cámara remota'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cambiar modo claro u oscuro'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('changing layout preserves the application camera owner', (
    tester,
  ) async {
    final camera = TestCamera();
    final session = CaptureSession(camera);
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
    await tester.tap(find.byTooltip('Mostrar ambas vistas'));
    await tester.pump();
    expect(find.text('Cámara remota'), findsOneWidget);
    await tester.tap(find.byTooltip('Ampliar cámara local'));
    await tester.pump();
    expect(find.text('Cámara remota'), findsNothing);
    expect(camera.opens, 1);
    expect(camera.closes, 0);
    expect(session.status, CaptureStatus.live);
    await tester.pumpWidget(const SizedBox.shrink());
    await session.stop();
    session.dispose();
  });
}
