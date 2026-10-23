import 'package:flutter/material.dart';

import 'video_annotation.dart';

class AnnotationOverlay extends StatelessWidget {
  const AnnotationOverlay({
    required this.notes,
    required this.position,
    required this.videoSize,
    required this.draft,
    this.onPoint,
    super.key,
  });
  final List<VideoAnnotation> notes;
  final Duration position;
  final Size videoSize;
  final List<Offset> draft;
  final ValueChanged<Offset>? onPoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      key: const Key('annotation-surface'),
      behavior: HitTestBehavior.opaque,
      onTapUp: onPoint == null
          ? null
          : (details) => onPoint!(
              normalizeVideoPoint(details.localPosition, constraints.biggest),
            ),
      child: CustomPaint(
        painter: _AnnotationPainter(
          notes.where((note) => note.visibleAt(position)).toList(),
          videoSize,
          draft,
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter(this.notes, this.videoSize, this.draft);
  final List<VideoAnnotation> notes;
  final Size videoSize;
  final List<Offset> draft;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = const Color(0xFF66FFD1)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    Offset pixel(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);
    void drawPoints(List<Offset> points) {
      for (var i = 0; i < points.length; i++) {
        final point = pixel(points[i]);
        canvas.drawCircle(point, 5, pen);
        if (i > 0) canvas.drawLine(pixel(points[i - 1]), point, pen);
      }
    }

    for (final note in notes) {
      drawPoints(note.points);
      final degrees = note.degrees(videoSize);
      if (degrees != null) {
        final label = TextPainter(
          text: TextSpan(
            text: '${degrees.toStringAsFixed(1)}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final vertex = pixel(note.points[1]);
        final origin = Offset(
          (vertex.dx + 10).clamp(
            0,
            (size.width - label.width - 12).clamp(0, size.width),
          ),
          (vertex.dy - label.height - 12).clamp(
            0,
            (size.height - label.height - 8).clamp(0, size.height),
          ),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              origin.dx,
              origin.dy,
              label.width + 12,
              label.height + 8,
            ),
            const Radius.circular(6),
          ),
          Paint()..color = Colors.black87,
        );
        label.paint(canvas, origin + const Offset(6, 4));
      }
    }
    pen.color = Colors.amberAccent;
    drawPoints(draft);
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
