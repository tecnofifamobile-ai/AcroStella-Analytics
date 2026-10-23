import 'package:acrostella_analytics/src/clips/clip_library_screen.dart';
import 'package:acrostella_analytics/src/clips/clip_player_screen.dart';
import 'package:acrostella_analytics/src/clips/video_annotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'clip_player_screen_test.dart'
    show FileVideoPlatform, flushNativeDisposal;
import 'support/recording_fakes.dart';

void main() {
  late MemoryClipStore store;
  late FileVideoPlatform platform;
  late VideoPlayerPlatform previous;
  setUp(() async {
    store = MemoryClipStore();
    await store.add(
      '/fake/exercise.mp4',
      DateTime.now(),
      const Duration(seconds: 10),
    );
    previous = VideoPlayerPlatform.instance;
    platform = FileVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  tearDown(() => VideoPlayerPlatform.instance = previous);
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClipPlayerScreen(store: store, clipId: 'clip-1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await flushNativeDisposal(tester);
    expect(store.readers, isEmpty);
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'freehand gesture persists normalized path and undo redo retain style',
    (tester) async {
      await open(tester);
      await tapVisible(tester, find.byTooltip('Dibujo libre'));
      await tapVisible(tester, find.byTooltip('Color coral'));
      final rect = tester.getRect(find.byKey(const Key('annotation-surface')));
      await tester.dragFrom(
        rect.topLeft + Offset(rect.width * .2, rect.height * .4),
        Offset(rect.width * .5, rect.height * .2),
      );
      await tester.pumpAndSettle();
      final note = store.savedNotes['clip-1']!.single;
      expect(note.tool, AnnotationTool.freehand);
      expect(note.points.length, greaterThan(2));
      expect(note.points.first.dx, inInclusiveRange(0, 1));
      expect(note.color, 0xffff6b6b);
      await tapVisible(tester, find.byTooltip('Deshacer dibujo'));
      expect(store.savedNotes['clip-1'], isEmpty);
      await tapVisible(tester, find.byTooltip('Rehacer dibujo'));
      expect(store.savedNotes['clip-1']!.single.toJson(), note.toJson());
      await tapVisible(tester, find.byTooltip('Ocultar dibujos'));
      expect(store.savedNotes['clip-1']!.length, 1);
      expect(find.byTooltip('Mostrar dibujos'), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets('pending back prompts and later preserves review in library', (
    tester,
  ) async {
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
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('¿Qué hacemos con este ejercicio?'), findsOneWidget);
    await tester.tap(find.text('Decidir después'));
    await tester.pump();
    await flushNativeDisposal(tester);
    await tester.pumpAndSettle();
    expect(store.clips.single.saved, isFalse);
    expect(find.text('Abrir'), findsOneWidget);
    await close(tester);
  });
  testWidgets(
    'failed saving keeps pending exercise and shows retryable review',
    (tester) async {
      await open(tester);
      store.failWrite = true;
      await tester.tap(find.text('Guardar ejercicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(store.clips.single.saved, isFalse);
      expect(find.text('Sin espacio disponible.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Guardar ejercicio'),
            )
            .onPressed,
        isNotNull,
      );
      await close(tester);
    },
  );
  testWidgets('moments persist and A B repetition seeks back to A', (
    tester,
  ) async {
    await open(tester);
    await tapVisible(tester, find.text('Repetición y momentos'));
    await tapVisible(tester, find.text('Marcar momento'));
    expect(store.clips.single.markers, [Duration.zero]);
    await tapVisible(tester, find.text('A · Inicio'));
    // Real controller seek/position notifications, with a fake file decoder.
    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(platform.position, greaterThan(Duration.zero));
    final b = platform.position;
    await tapVisible(tester, find.text('B · Final'));
    await tapVisible(tester, find.text('Repetir A–B'));
    expect(platform.position, Duration.zero);
    expect(platform.calls, contains('play'));
    platform.position = b;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(platform.position, Duration.zero);
    await close(tester);
  });
  testWidgets(
    'library searches notes and filters favorites independently of pending',
    (tester) async {
      await store.updateDetails(
        'clip-1',
        saved: true,
        name: 'Equilibrio',
        memo: 'Recepción alta',
        favorite: true,
      );
      final other = await store.add(
        '/fake/other.mp4',
        DateTime.now(),
        const Duration(seconds: 4),
      );
      await store.updateDetails(other.id, saved: true, name: 'Salto');
      await store.add(
        '/fake/pending.mp4',
        DateTime.now(),
        const Duration(seconds: 2),
      );
      await tester.pumpWidget(
        MaterialApp(home: ClipLibraryScreen(store: store)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Equilibrio'), findsOneWidget);
      expect(find.text('Salto'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'recepción');
      await tester.pumpAndSettle();
      expect(find.text('Equilibrio'), findsOneWidget);
      expect(find.text('Salto'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      expect(find.text('Salto'), findsNothing);
      await tester.tap(find.text('Pendientes (1)'));
      await tester.pumpAndSettle();
      expect(find.text('No hay ejercicios con estos filtros.'), findsOneWidget);
      await tester.tap(find.text('Favoritos'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pending_actions), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets(
    'cancelled freehand is discarded and loaded drawings can be erased then undone',
    (tester) async {
      final existing = VideoAnnotation(
        tool: AnnotationTool.rectangle,
        points: const [Offset(.2, .2), Offset(.8, .8)],
        start: Duration.zero,
        end: const Duration(seconds: 3),
      );
      await store.saveAnnotations('clip-1', [existing]);
      await open(tester);
      await tapVisible(tester, find.byTooltip('Dibujo libre'));
      final rect = tester.getRect(find.byKey(const Key('annotation-surface')));
      final gesture = await tester.startGesture(rect.center);
      await gesture.moveBy(const Offset(35, 10));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(store.savedNotes['clip-1']!.length, 1);
      await tapVisible(tester, find.byTooltip('Borrar dibujos visibles'));
      expect(store.savedNotes['clip-1'], isEmpty);
      await tapVisible(tester, find.byTooltip('Deshacer dibujo'));
      expect(store.savedNotes['clip-1']!.single.toJson(), existing.toJson());
      await close(tester);
    },
  );
}
