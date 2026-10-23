import 'dart:io';

import 'package:acrostella_analytics/src/capture/capture_session.dart';
import 'package:acrostella_analytics/src/updates/update_controller.dart';
import 'package:acrostella_analytics/src/updates/update_screen.dart';
import 'package:acrostella_analytics/src/updates/update_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_fakes.dart';
import 'update_controller_test.dart'
    show MemoryUpdatePreferences, TestUpdateInstaller;
import 'update_source_test.dart' show testRelease;

class WidgetUpdateSource implements UpdateSource {
  @override
  Future<UpdateRelease?> latest(UpdateCancellation cancellation) async =>
      testRelease();
  @override
  Future<File> download(
    UpdateRelease release,
    Directory directory,
    UpdateCancellation cancellation,
    void Function(int) progress,
  ) async {
    progress(3);
    return File('/fake/verified.apk');
  }
}

void main() {
  testWidgets(
    'downloads without browser and disables install while a clip is active',
    (tester) async {
      final installer = TestUpdateInstaller();
      final updates = UpdateController(
        source: WidgetUpdateSource(),
        installer: installer,
        preferences: MemoryUpdatePreferences(),
        downloadDirectory: () async => Directory('/fake'),
      );
      final capture = CaptureSession(
        RecordingCamera(),
        clips: MemoryClipStore(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: UpdateScreen(updates: updates, capture: capture),
        ),
      );
      await tester.tap(find.text('Buscar actualizaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Nueva versión 0.4.0'), findsOneWidget);
      await tester.tap(find.text('Descargar actualización'));
      await tester.pumpAndSettle();
      expect(find.text('Instalador verificado'), findsOneWidget);
      expect(installer.calls, ['verify']);
      await capture.start();
      await capture.startClip();
      await tester.pump();
      final install = find.widgetWithText(
        FilledButton,
        'Instalar actualización',
      );
      expect(tester.widget<FilledButton>(install).onPressed, isNull);
      expect(find.text('Finaliza el clip antes de instalar.'), findsOneWidget);
      await capture.finishClip();
      await tester.pump();
      await tester.tap(install);
      await tester.pump();
      expect(installer.calls, ['verify', 'install']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await capture.stop();
      capture.dispose();
      updates.dispose();
    },
  );
}
