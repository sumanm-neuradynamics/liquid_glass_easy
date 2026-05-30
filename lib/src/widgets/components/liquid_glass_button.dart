import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// A pill-shaped action button rendered as liquid glass.
///
/// Pass a [label] and optional [icon]; for tinted call-to-action
/// buttons (e.g. blue "Continue") set [tint]. The button forwards
/// taps to [onPressed].
///
/// Almost everything is customizable — size, glass tint/blur/
/// distortion, border profile, corner radius, and the label/icon
/// styling. Sensible iOS-style defaults are provided so the simplest
/// call is just `label` + `onPressed`.
class LiquidGlassButton extends LiquidGlass {
  LiquidGlassButton({
    required super.position,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,

    /// Solid fill tint for a call-to-action button. When `null` the
    /// button uses the translucent [glassColor] instead.
    Color? tint,
    super.width = 200,
    super.height = 48,
    super.controller,

    /// Corner radius of the capsule. Defaults to a full pill
    /// (`height / 2`).
    double? cornerRadius,

    /// Translucent glass tint used when [tint] is `null`.
    Color glassColor = const Color(0x1CFFFFFF), // white, alpha 28
    super.blur = const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    super.distortion = 0.07,
    super.distortionWidth = 24,
    super.chromaticAberration = 0.002,
    super.magnification = 1,

    // ── Border ─────────────────────────────────────────────
    double borderWidth = 1.1,
    double lightIntensity = 1.2,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.2,
      ambientIntensity: 1.0,
      borderSolidity: 0.35,
    ),

    // ── Content ────────────────────────────────────────────
    /// Color of the label text and icon.
    Color foregroundColor = Colors.white,

    /// Font size of the label.
    double fontSize = 16,

    /// Font weight of the label.
    FontWeight fontWeight = FontWeight.w600,

    /// Size of the leading icon (when [icon] is provided).
    double iconSize = 20,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          color: tint == null ? glassColor : tint.withAlpha(160),
          shape: RoundedRectangleShape(
            cornerRadius: cornerRadius ?? height / 2,
            borderWidth: borderWidth,
            lightIntensity: lightIntensity,
            lightDirection: lightDirection,
            borderType: borderType,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
                  BorderRadius.circular(cornerRadius ?? height / 2),
              onTap: onPressed,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: foregroundColor, size: iconSize),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
}
