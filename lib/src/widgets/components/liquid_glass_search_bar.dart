import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// Spotlight-style liquid-glass search pill.
///
/// A thin, fully rounded glass capsule with a search glyph and
/// placeholder text. Tap forwards to [onTap] — no internal text
/// state is held so the parent can decide what to do (open a search
/// route, show a sheet, focus a `TextField`, etc.).
///
/// Customizable across size, glass look, border, corner radius, the
/// leading/trailing icons (and their visibility), and the
/// placeholder text styling.
class LiquidGlassSearchBar extends LiquidGlass {
  LiquidGlassSearchBar({
    required super.position,
    super.controller,
    super.width = 280,
    super.height = 44,
    String placeholder = 'Search',
    VoidCallback? onTap,

    /// Corner radius of the capsule. Defaults to a full pill
    /// (`height / 2`).
    double? cornerRadius,

    /// Translucent glass tint of the capsule.
    Color glassColor = const Color(0x14FFFFFF), // white, alpha 20
    super.blur = const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
    super.distortion = 0.07,
    super.distortionWidth = 28,
    super.chromaticAberration = 0.002,
    super.magnification = 1,

    // ── Border ─────────────────────────────────────────────
    double borderWidth = 1,
    double lightIntensity = 1.1,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.1,
      ambientIntensity: 1.0,
      borderSolidity: 0.3,
    ),

    // ── Content ────────────────────────────────────────────
    /// Leading glyph. Defaults to a search icon. Pass `null` to hide.
    IconData? leadingIcon = Icons.search_rounded,

    /// Trailing glyph. Defaults to a mic icon. Pass `null` to hide.
    IconData? trailingIcon = Icons.mic_rounded,

    /// Color of the icons and placeholder text.
    Color foregroundColor = Colors.white70,

    /// Placeholder font size.
    double fontSize = 16,

    /// Icon size for the leading/trailing glyphs.
    double iconSize = 20,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          color: glassColor,
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
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(
                        leadingIcon,
                        color: foregroundColor,
                        size: iconSize,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      placeholder,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    if (trailingIcon != null)
                      Icon(
                        trailingIcon,
                        color: foregroundColor,
                        size: iconSize,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
}
