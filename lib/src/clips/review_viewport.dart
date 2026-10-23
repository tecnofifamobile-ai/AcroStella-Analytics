import 'package:flutter/material.dart';

/// Transforms the video and its annotation surface together. Flutter maps
/// pointer positions back into the transformed child for normalized drawings.
class ReviewViewport extends StatefulWidget {
  const ReviewViewport({
    required this.child,
    required this.explore,
    required this.aspectRatio,
    this.label,
    super.key,
  });
  final Widget child;
  final bool explore;
  final double aspectRatio;
  final String? label;
  @override
  State<ReviewViewport> createState() => _ReviewViewportState();
}

class _ReviewViewportState extends State<ReviewViewport> {
  final _transform = TransformationController();
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: widget.explore
                ? InteractiveViewer(
                    transformationController: _transform,
                    minScale: 1,
                    maxScale: 6,
                    scaleEnabled: widget.explore,
                    panEnabled: widget.explore,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: widget.aspectRatio,
                        child: widget.child,
                      ),
                    ),
                  )
                : ValueListenableBuilder<Matrix4>(
                    valueListenable: _transform,
                    builder: (_, matrix, child) =>
                        Transform(transform: matrix, child: child),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: widget.aspectRatio,
                        child: widget.child,
                      ),
                    ),
                  ),
          ),
          if (widget.label != null)
            Positioned(
              left: 12,
              top: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      widget.label!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filledTonal(
              tooltip: 'Restablecer zoom',
              onPressed: () => _transform.value = Matrix4.identity(),
              icon: const Icon(Icons.fit_screen),
            ),
          ),
        ],
      ),
    ),
  );
}
