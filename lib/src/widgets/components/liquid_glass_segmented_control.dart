import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// A segmented control rendered on top of liquid glass.
///
/// The capsule itself is a single [LiquidGlass] surface; the selected
/// segment is highlighted with a brighter inner pill that animates
/// across. Tapping a segment reports its index via [onChanged]. The
/// widget is stateless on purpose — the parent owns [selectedIndex].
///
/// Customizable across size, glass look, border, corner radius, the
/// selection-pill color/border, and the segment label styling.
class LiquidGlassSegmentedControl extends LiquidGlass {
  LiquidGlassSegmentedControl({
    required super.position,
    required List<String> segments,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    super.width = 320,
    super.height = 36,
    super.controller,

    /// Corner radius of the capsule. Defaults to a full pill
    /// (`height / 2`).
    double? cornerRadius,

    /// Translucent glass tint of the capsule.
    Color glassColor = const Color(0x14FFFFFF), // white, alpha 20
    super.blur = const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
    super.distortion = 0.06,
    super.distortionWidth = 22,
    super.chromaticAberration = 0.002,
    super.magnification = 1,

    // ── Border ─────────────────────────────────────────────
    double borderWidth = 1.0,
    double lightIntensity = 1.0,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.1,
      ambientIntensity: 1.0,
      borderSolidity: 0.25,
    ),

    // ── Selection pill ─────────────────────────────────────
    /// Fill color of the moving selection pill.
    Color selectionColor = const Color(0x3CFFFFFF), // white, alpha 60

    /// Border color of the moving selection pill.
    Color selectionBorderColor = const Color(0x50FFFFFF), // alpha 80

    /// Slide duration of the selection pill between segments.
    Duration selectionDuration = const Duration(milliseconds: 220),

    // ── Labels ─────────────────────────────────────────────
    /// Color of segment labels.
    Color labelColor = Colors.white,

    /// Font size of segment labels.
    double fontSize = 13,
    super.draggable = false,
    super.outOfBoundaries = false,
  })  : assert(segments.length >= 2, 'Need at least two segments'),
        assert(selectedIndex >= 0 && selectedIndex < segments.length),
        super(
          color: glassColor,
          shape: RoundedRectangleShape(
            cornerRadius: cornerRadius ?? height / 2,
            borderWidth: borderWidth,
            lightIntensity: lightIntensity,
            lightDirection: lightDirection,
            borderType: borderType,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: LayoutBuilder(builder: (context, constraints) {
              final segWidth = constraints.maxWidth / segments.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: selectionDuration,
                    curve: Curves.easeOut,
                    left: selectedIndex * segWidth,
                    top: 0,
                    bottom: 0,
                    width: segWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: selectionColor,
                        borderRadius: BorderRadius.circular(height / 2),
                        border: Border.all(
                          color: selectionBorderColor,
                          width: 0.6,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (int i = 0; i < segments.length; i++)
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(height / 2),
                              onTap: () => onChanged(i),
                              child: Center(
                                child: Text(
                                  segments[i],
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: fontSize,
                                    fontWeight: i == selectedIndex
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
}
