import 'package:flutter/material.dart';

import 'liquid_glass_border_mode.dart';
import 'liquid_glass_light_mode.dart';

/// Abstract base border configuration for liquid glass shapes.
///
/// Contains shared border parameters that apply to both classic and optical
/// border modes. Mode-specific parameters are encapsulated in [borderType].
abstract class LiquidGlassShape {
  /// The thickness of the lens border in logical pixels.
  ///
  /// Increasing this value makes the border appear thicker
  /// around the lens perimeter.
  final double borderWidth;

  /// The base color of the lens border.
  ///
  /// If not `null`, this will replace the light and shadow color. It's a solid color.
  final Color? borderColor;

  /// The brightness multiplier for lens lighting and reflections.
  ///
  /// Controls how strongly highlights and shadows appear on the border.
  /// - Typical range: `0.0` (no lighting) → `1.0` (normal brightness) → `>1.0` (strong glow).
  final double lightIntensity;

  /// The primary highlight color applied to illuminated areas of the lens border.
  ///
  /// Used in both classic mode (sweep gradient highlight) and optical mode
  /// (specular boost highlights). Usually a lighter tint such as white or pale yellow.
  final Color lightColor;

  /// The directional angle (in degrees) from which the simulated light hits the lens.
  ///
  /// - `0°` means light comes from the right.
  /// - `90°` means light comes from the top.
  /// - `180°` from the left, and `270°` from the bottom.
  ///
  /// Used to compute where highlights and shadows fall on the border.
  final double lightDirection;

  /// Defines how lighting is calculated along the liquid glass border.
  ///
  /// • [LiquidGlassLightMode.edge] — Uses the shape's edge gradient
  ///   as the surface normal, producing lighting that follows the
  ///   contour of the glass border and the light to expand along
  ///   straight edges. This results in more physically
  ///   accurate edge highlights.
  ///
  /// • [LiquidGlassLightMode.radial] — Uses a radial direction from
  ///   the center of the glass to each fragment, causing the light to expand naturally
  ///   along curved edges creating a uniform,
  ///   lens-like lighting sweep around the border.
  final LiquidGlassLightMode lightMode;

  /// Defines the rendering style and mode-specific parameters for the border.
  ///
  /// - [ClassicBorder] — Sweep gradient with light/shadow colors and softness.
  /// - [OpticalBorder] — Apple-style SDF rim light with ambient tinting and saturation.
  ///
  /// Defaults to [OpticalBorder].
  final LiquidGlassBorderType borderType;

  const LiquidGlassShape({
    this.borderWidth = 1.0,
    this.borderColor,
    this.lightIntensity = 1.0,
    this.lightColor = const Color(0xB2FFFFFF),
    this.lightDirection = 0.0,
    this.lightMode = LiquidGlassLightMode.edge,
    this.borderType = const OpticalBorder(),
  });

  // ── Convenience getters for the painter to extract values ──

  /// The one-sided specular highlight intensity.
  ///
  /// Classic-only: returns the value from [ClassicBorder.oneSideLightIntensity]
  /// in classic mode, and `0.0` for optical mode (which derives its rim from
  /// the glass shape and does not use this specular term).
  double get oneSideLightIntensity => switch (borderType) {
        ClassicBorder(oneSideLightIntensity: final v) => v,
        OpticalBorder() => 0.0,
      };

  /// The double-sided specular highlight intensity.
  ///
  /// Classic-only: returns the value from
  /// [ClassicBorder.doubleSideLightIntensity] in classic mode, and `0.0` for
  /// optical mode (which derives its rim from the glass shape and does not use
  /// this specular term).
  double get doubleSideLightIntensity => switch (borderType) {
        ClassicBorder(doubleSideLightIntensity: final v) => v,
        OpticalBorder() => 0.0,
      };

  /// The border softness (classic only, returns 1.0 for optical).
  double get borderSoftness => switch (borderType) {
        ClassicBorder(borderSoftness: final s) => s,
        OpticalBorder() => 1.0,
      };

  /// The shadow color (classic only, returns transparent black for optical).
  Color get shadowColor => switch (borderType) {
        ClassicBorder(shadowColor: final c) => c,
        OpticalBorder() => const Color(0x1A000000),
      };

  /// The ambient intensity used by the shader for the optical rim.
  ///
  /// Returns the user-configurable value from [OpticalBorder.ambientIntensity]
  /// when in optical mode, and `0.0` for classic mode (which doesn't use
  /// the ambient term).
  double get ambientIntensity => switch (borderType) {
        OpticalBorder(ambientIntensity: final a) => a,
        ClassicBorder() => 0.0,
      };

  /// The border saturation (optical only, returns 1.0 for classic).
  double get borderSaturation => switch (borderType) {
        OpticalBorder(borderSaturation: final s) => s,
        ClassicBorder() => 1.0,
      };

  /// The optical-mode rim solidity. `0.0` for classic mode (unused there).
  double get borderSolidity => switch (borderType) {
        OpticalBorder(borderSolidity: final s) => s,
        ClassicBorder() => 0.0,
      };

  /// Whether the border mode is optical.
  bool get isOpticalBorder => borderType.isOptical;

  /// The border mode as the enum value (for shader uniform).
  LiquidGlassBorderMode get borderMode => borderType.isOptical
      ? LiquidGlassBorderMode.optical
      : LiquidGlassBorderMode.classic;
}

/// For backward compatibility — the enum is still used internally
/// by the shader dispatch logic.
enum LiquidGlassBorderMode { classic, optical }

class RoundedRectangleShape extends LiquidGlassShape {
  final double cornerRadius;
  const RoundedRectangleShape({
    this.cornerRadius = 50.0,
    super.borderWidth,
    super.borderColor,
    super.lightIntensity,
    super.lightColor,
    super.lightDirection,
    super.lightMode,
    super.borderType,
  });
}

class SuperellipseShape extends LiquidGlassShape {
  final double curveExponent;

  const SuperellipseShape({
    this.curveExponent = 3.0,
    super.borderWidth,
    super.borderColor,
    super.lightIntensity,
    super.lightColor,
    super.lightDirection,
    super.lightMode,
    super.borderType,
  });
}
