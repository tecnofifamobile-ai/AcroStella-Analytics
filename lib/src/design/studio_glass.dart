import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

/// A controls material, never a filter over the analysis footage itself.
/// UIKit owns the system effect on iOS; Android uses the reviewed Impeller
/// renderer. Software rendering / accessibility use an opaque surface.
class StudioGlass extends StatelessWidget {
  const StudioGlass({required this.child, this.radius = 28, super.key});
  final Widget child;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final opaque =
        media.highContrast ||
        media.disableAnimations ||
        media.accessibleNavigation;
    final border = BorderRadius.circular(radius);
    if (opaque) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: border,
        ),
        child: child,
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return ClipRRect(
        borderRadius: border,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: UiKitView(
                  key: ValueKey('studio-glass-$dark'),
                  viewType: 'acrostella/liquid-glass',
                  creationParams: {'dark': dark, 'radius': radius},
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              ),
            ),
            child,
          ],
        ),
      );
    }
    if (ui.ImageFilter.isShaderFilterSupported) {
      return LiquidGlass.withOwnLayer(
        shape: LiquidRoundedSuperellipse(borderRadius: radius),
        settings: LiquidGlassSettings(
          glassColor: (dark ? const Color(0xFF253442) : Colors.white)
              .withValues(alpha: .30),
          thickness: 16,
          blur: 5,
          chromaticAberration: .005,
          refractiveIndex: 1.12,
        ),
        child: child,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: border,
      ),
      child: child,
    );
  }
}
