import 'dart:math' as math;
import 'dart:ui';

enum AnnotationTool { line, angle }

class VideoAnnotation {
  VideoAnnotation({
    required this.tool,
    required List<Offset> points,
    required this.start,
    required this.end,
  }) : points = List.unmodifiable(points) {
    if (points.length != (tool == AnnotationTool.line ? 2 : 3) ||
        points.any(
          (p) =>
              !p.dx.isFinite ||
              !p.dy.isFinite ||
              p.dx < 0 ||
              p.dx > 1 ||
              p.dy < 0 ||
              p.dy > 1,
        ) ||
        start.isNegative ||
        end < start ||
        end - start > const Duration(seconds: 60)) {
      throw const FormatException('Invalid video annotation');
    }
    if ((points[0] - points[1]).distance < 0.001 ||
        (tool == AnnotationTool.angle &&
            (points[2] - points[1]).distance < 0.001)) {
      throw const FormatException('Choose different points');
    }
  }
  final AnnotationTool tool;
  final List<Offset> points;
  final Duration start;
  final Duration end;

  bool visibleAt(Duration position) => position >= start && position <= end;

  // Coordinates are normalized, but angles must be measured in the original
  // image aspect ratio, not in a square normalized coordinate system.
  double? degrees(Size video) {
    if (tool != AnnotationTool.angle || video.isEmpty) return null;
    Offset pixel(Offset p) => Offset(p.dx * video.width, p.dy * video.height);
    final a = pixel(points[0]) - pixel(points[1]);
    final b = pixel(points[2]) - pixel(points[1]);
    return (math
            .atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy)
            .abs() *
        180 /
        math.pi);
  }

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'points': [
      for (final p in points) [p.dx, p.dy],
    ],
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
  };

  factory VideoAnnotation.fromJson(Map<String, dynamic> json) =>
      VideoAnnotation(
        tool: AnnotationTool.values.byName(json['tool'] as String),
        points: [
          for (final p in json['points'] as List)
            Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        start: Duration(milliseconds: json['startMs'] as int),
        end: Duration(milliseconds: json['endMs'] as int),
      );
}

/// Mounted inside the video's AspectRatio, so letterbox bars never become
/// annotation coordinates. The same coordinates survive layout/size changes.
Offset normalizeVideoPoint(Offset point, Size surface) {
  if (surface.isEmpty) throw ArgumentError('Empty video surface');
  return Offset(
    (point.dx / surface.width).clamp(0, 1),
    (point.dy / surface.height).clamp(0, 1),
  );
}
