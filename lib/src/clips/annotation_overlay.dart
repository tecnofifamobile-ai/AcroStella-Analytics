import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'video_annotation.dart';

class AnnotationOverlay extends StatelessWidget {
  const AnnotationOverlay({
    required this.notes,
    required this.position,
    required this.videoSize,
    required this.draft,
    this.tool,
    this.color = 0xff66dab5,
    this.width = 0.006,
    this.onPoint,
    this.onStrokeStart,
    this.onStrokeUpdate,
    this.onStrokeEnd,
    this.onStrokeCancel,
    super.key,
  });
  final List<VideoAnnotation> notes;
  final Duration position;
  final Size videoSize;
  final List<Offset> draft;
  final AnnotationTool? tool;
  final int color;
  final double width;
  final ValueChanged<Offset>? onPoint;
  final ValueChanged<Offset>? onStrokeStart;
  final ValueChanged<Offset>? onStrokeUpdate;
  final VoidCallback? onStrokeEnd;
  final VoidCallback? onStrokeCancel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      Offset point(Offset p) => normalizeVideoPoint(p, constraints.biggest);
      return Listener(
        onPointerCancel: onStrokeCancel == null
            ? null
            : (_) => onStrokeCancel!(),
        child: GestureDetector(
          key: const Key('annotation-surface'),
          behavior: HitTestBehavior.opaque,
          onTapUp: onPoint == null
              ? null
              : (event) => onPoint!(point(event.localPosition)),
          onPanStart: onStrokeStart == null
              ? null
              : (event) => onStrokeStart!(point(event.localPosition)),
          onPanUpdate: onStrokeUpdate == null
              ? null
              : (event) => onStrokeUpdate!(point(event.localPosition)),
          onPanEnd: onStrokeEnd == null ? null : (_) => onStrokeEnd!(),
          onPanCancel: onStrokeCancel,
          child: CustomPaint(
            painter: _AnnotationPainter(
              notes.where((n) => n.visibleAt(position)).toList(),
              videoSize,
              draft,
              tool,
              color,
              width,
            ),
          ),
        ),
      );
    },
  );
}

class _AnnotationPainter extends CustomPainter {
  _AnnotationPainter(
    this.notes,
    this.video,
    this.draft,
    this.tool,
    this.color,
    this.width,
  );
  final List<VideoAnnotation> notes;
  final Size video;
  final List<Offset> draft;
  final AnnotationTool? tool;
  final int color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    for (final note in notes) {
      _draw(
        canvas,
        size,
        note.tool,
        note.points,
        note.color,
        note.width,
        note.degrees(video),
      );
    }
    if (draft.isNotEmpty) {
      _draw(
        canvas,
        size,
        tool ?? AnnotationTool.line,
        draft,
        color,
        width,
        null,
      );
    }
  }

  void _draw(
    Canvas canvas,
    Size size,
    AnnotationTool tool,
    List<Offset> points,
    int color,
    double width,
    double? angle,
  ) {
    final p = points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final paint = Paint()
      ..color = Color(color)
      ..strokeWidth = (size.shortestSide * width).clamp(1.5, 14)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if ((tool == AnnotationTool.rectangle || tool == AnnotationTool.ellipse) &&
        p.length >= 2) {
      final rect = Rect.fromPoints(p[0], p[1]);
      if (tool == AnnotationTool.rectangle) {
        canvas.drawRect(rect, paint);
      } else {
        canvas.drawOval(rect, paint);
      }
    } else {
      final path = Path()..moveTo(p.first.dx, p.first.dy);
      for (final point in p.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      if (tool == AnnotationTool.arrow && p.length == 2) {
        final heading = math.atan2(p[1].dy - p[0].dy, p[1].dx - p[0].dx);
        final length = math.min(22.0, (p[1] - p[0]).distance * 0.35);
        for (final offset in [-0.5, 0.5]) {
          canvas.drawLine(
            p[1],
            p[1] -
                Offset(math.cos(heading + offset), math.sin(heading + offset)) *
                    length,
            paint,
          );
        }
      }
    }
    if (tool != AnnotationTool.freehand) {
      for (final point in p) {
        canvas.drawCircle(point, 3, Paint()..color = Color(color));
      }
    }
    if (angle != null) {
      final text = TextPainter(
        text: TextSpan(
          text: '${angle.toStringAsFixed(1)}°',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          (p[1].dx + 8).clamp(0, math.max(0, size.width - text.width)),
          (p[1].dy - text.height - 6).clamp(
            0,
            math.max(0, size.height - text.height),
          ),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
