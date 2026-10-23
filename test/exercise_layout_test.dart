import 'package:acrostella_analytics/src/clips/clip_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'clip_player_screen_test.dart'
    show FileVideoPlatform, flushNativeDisposal;
import 'support/recording_fakes.dart';

void main() {
  for (final size in [
    const Size(393, 852),
    const Size(852, 393),
    const Size(1366, 1024),
  ]) {
    testWidgets('review and drawing tools fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = FileVideoPlatform();
      addTearDown(() => VideoPlayerPlatform.instance = previous);
      final store = MemoryClipStore();
      await store.add(
        '/fake/video.mp4',
        DateTime.now(),
        const Duration(seconds: 10),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: RepaintBoundary(
            key: boundary,
            child: ClipPlayerScreen(store: store, clipId: 'clip-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Dibujo libre'));
      await tester.tap(find.byTooltip('Dibujo libre'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byKey(const Key('annotation-surface')));
      expect(rect.width, greaterThan(150));
      expect(rect.height, greaterThan(80));
      await tester.dragFrom(
        rect.centerLeft + const Offset(25, 0),
        Offset(rect.width * .6, 20),
      );
      await tester.pumpAndSettle();
      expect(store.savedNotes['clip-1'], hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await flushNativeDisposal(tester);
      expect(store.readers, isEmpty);
    });
  }
}
