import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_app_icon.dart';

/// Lightweight description of a single entry in [LiquidGlassDock].
class LiquidGlassDockApp {
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const LiquidGlassDockApp({
    required this.icon,
    this.gradient = const [Color(0xFF4FB3FF), Color(0xFF1E69DE)],
    this.onTap,
  });
}

/// A horizontal dock of app icons inside a single liquid-glass blob
/// with a soft optical rim — the home-screen dock pattern popularised
/// by iOS / iPadOS.
class LiquidGlassDock extends LiquidGlass {
  LiquidGlassDock({
    required super.position,
    required List<LiquidGlassDockApp> apps,
    super.controller,
    double iconSize = 52,
    double spacing = 14,
    double horizontalPadding = 14,
    double verticalPadding = 12,
    super.draggable = false,
    super.outOfBoundaries = false,
    super.blur = const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  }) : super(
          width: apps.length * iconSize +
              (apps.length - 1) * spacing +
              horizontalPadding * 2,
          height: iconSize + verticalPadding * 2,
          magnification: 1,
          distortion: 0.08,
          distortionWidth: 36,
          chromaticAberration: 0.002,
          color: Colors.white.withAlpha(28),
          shape: const RoundedRectangleShape(
            cornerRadius: 30,
            borderWidth: 1.2,
            lightIntensity: 1.2,
            lightDirection: 70,
            borderType: OpticalBorder(
              borderSaturation: 1.3,
              ambientIntensity: 1.0,
              borderSolidity: 0.4,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < apps.length; i++) ...[
                  LiquidGlassAppIcon(
                    icon: apps[i].icon,
                    gradient: apps[i].gradient,
                    size: iconSize,
                    onTap: apps[i].onTap,
                  ),
                  if (i != apps.length - 1) SizedBox(width: spacing),
                ],
              ],
            ),
          ),
        );
}
