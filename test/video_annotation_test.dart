import 'dart:ui';

import 'package:acrostella_analytics/src/clips/video_annotation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VideoAnnotation angle() => VideoAnnotation(
    tool: AnnotationTool.angle,
    points: const [Offset(.25, .25), Offset(.5, .5), Offset(.75, .25)],
    start: const Duration(seconds: 2),
    end: const Duration(seconds: 5),
  );

  test(
    'angle uses image aspect ratio rather than normalized square coordinates',
    () {
      expect(angle().degrees(const Size(100, 100)), closeTo(90, .001));
      expect(angle().degrees(const Size(200, 100)), closeTo(126.869897, .001));
      expect(
        angle().degrees(const Size(400, 200)),
        angle().degrees(const Size(200, 100)),
      );
    },
  );
  test('annotation is visible only within its media time interval', () {
    final note = angle();
    expect(note.visibleAt(const Duration(milliseconds: 1999)), isFalse);
    expect(note.visibleAt(const Duration(seconds: 2)), isTrue);
    expect(note.visibleAt(const Duration(seconds: 5)), isTrue);
    expect(note.visibleAt(const Duration(milliseconds: 5001)), isFalse);
  });
  test('round trip retains normalized coordinates and timing', () {
    final restored = VideoAnnotation.fromJson(angle().toJson());
    expect(restored.points, angle().points);
    expect(restored.start, angle().start);
    expect(restored.end, angle().end);
  });
  test('rejects degenerate geometry and coordinates outside the image', () {
    for (final points in [
      [const Offset(.5, .5), const Offset(.5, .5), const Offset(1, 1)],
      [const Offset(-1, 0), const Offset(.5, .5), const Offset(1, 1)],
    ]) {
      expect(
        () => VideoAnnotation(
          tool: AnnotationTool.angle,
          points: points,
          start: Duration.zero,
          end: const Duration(seconds: 3),
        ),
        throwsFormatException,
      );
    }
  });
  test(
    'normalization scales with the actual video surface and clamps edges',
    () {
      expect(
        normalizeVideoPoint(const Offset(320, 180), const Size(640, 360)),
        const Offset(.5, .5),
      );
      expect(
        normalizeVideoPoint(const Offset(640, 360), const Size(1280, 720)),
        const Offset(.5, .5),
      );
      expect(
        normalizeVideoPoint(const Offset(-1, 400), const Size(640, 360)),
        const Offset(0, 1),
      );
    },
  );
  test('freehand shapes styles and full exercise lifetime round-trip', () {
    for (final tool in AnnotationTool.values) {
      final note = VideoAnnotation(
        tool: tool,
        points: tool == AnnotationTool.angle
            ? const [Offset(.1, .2), Offset(.3, .5), Offset(.7, .8)]
            : const [Offset(.1, .2), Offset(.7, .8)],
        start: Duration.zero,
        end: const Duration(minutes: 2),
        color: 0xffff6b6b,
        width: .012,
      );
      expect(VideoAnnotation.fromJson(note.toJson()).toJson(), note.toJson());
    }
  });
  test('bounded freehand and styles reject malformed persisted values', () {
    for (final points in [
      <Offset>[const Offset(.2, .2)],
      List.filled(513, const Offset(.2, .2)),
    ]) {
      expect(
        () => VideoAnnotation(
          tool: AnnotationTool.freehand,
          points: points,
          start: Duration.zero,
          end: const Duration(seconds: 3),
        ),
        throwsFormatException,
      );
    }
    final json = angle().toJson()..['width'] = double.nan;
    expect(() => VideoAnnotation.fromJson(json), throwsFormatException);
  });
  test('old v03 drawings load with their original default style', () {
    final json = angle().toJson()
      ..remove('color')
      ..remove('width');
    final restored = VideoAnnotation.fromJson(json);
    expect(restored.color, 0xff66dab5);
    expect(restored.width, .006);
  });
}
