import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// A compact one-touch control tile rendered as liquid glass.
///
/// Designed for boolean toggles (Wi-Fi, Bluetooth, Airplane Mode,
/// Flashlight, etc.). The tile flips to an "on" tint when [active]
/// is true. Provide [icon], an optional [label], and an [onTap]
/// handler — the widget is stateless on purpose so the parent owns
/// the boolean state.
class LiquidGlassControlTile extends LiquidGlass {
  LiquidGlassControlTile({
    required super.position,
    required IconData icon,
    required bool active,
    String? label,
    Color activeColor = const Color(0xFF34C759),
    VoidCallback? onTap,
    double size = 80,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          width: size,
          height: size,
          magnification: 1,
          distortion: 0.08,
          distortionWidth: 30,
          chromaticAberration: 0.002,
          color: active
              ? activeColor.withAlpha(180)
              : Colors.white.withAlpha(30),
          blur: const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
          shape: RoundedRectangleShape(
            cornerRadius: size * 0.32,
            borderWidth: 1.2,
            lightIntensity: active ? 1.6 : 1.1,
            lightDirection: 60,
            borderType: const OpticalBorder(
              borderSaturation: 1.2,
              ambientIntensity: 1.0,
              borderSolidity: 0.35,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(size * 0.32),
              onTap: onTap,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: size * 0.42,
                    ),
                    if (label != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
}
