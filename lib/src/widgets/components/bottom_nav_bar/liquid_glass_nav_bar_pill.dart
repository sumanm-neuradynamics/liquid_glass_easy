import 'package:flutter/material.dart';

import '../../liquid_glass.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_border_mode.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_shape.dart';
import 'liquid_glass_nav_bar_layout.dart';

/// Builds the moving liquid-glass selection pill that slides across
/// the bar. Returns a [LiquidGlass] you place in the `children:` list
/// of the OUTER `LiquidGlassView`.
///
/// **Not exported yet** — this is part of the animated bottom nav
/// bar, whose motion work is still in progress. It is consumed only
/// by the package's own example/showcase.
///
/// Pass [animatedIndex] as a fractional value between `0` and
/// `items.length - 1` so the pill can be animated between tabs by
/// the caller (typically via an `AnimationController` running a
/// `Tween<double>` between the previous and next index).
///
/// [extraHeight] overrides the layout's default pill-extra-height
/// for this single frame. Animate it from `0` →
/// `layout.pillExtraHeight` → `0` to make the pill grow out of and
/// shrink back into the static selection highlight, the way iOS
/// does on tap.
///
/// [extraWidth] adds horizontal stretch to the pill — useful for
/// the jelly effect during a drag. Always grows symmetrically (left
/// and right) so the pill stays centered on its base index.
LiquidGlass buildLiquidGlassBottomNavPill({
  required LiquidGlassBottomNavBarLayout layout,
  required double animatedIndex,
  required double parentWidth,

  /// Stable key for the pill lens. Pass a constant key so the pill
  /// keeps its own `State` when it is added to / removed from the
  /// outer view's `children` (it is only present while moving), instead
  /// of being matched by list index — which would otherwise let it
  /// reuse a sibling lens's `State`.
  Key? key,
  double? extraHeight,
  double extraWidth = 0,

  /// Horizontal shift applied to the whole bar (0 = centered). Lets the
  /// pill track a bar that's been moved off-center by a custom position.
  double dx = 0,

  /// Blur behind the moving pill. Defaults to **none** so the glass
  /// reads crisp; pass a [LiquidGlassBlur] to soften it.
  LiquidGlassBlur blur = const LiquidGlassBlur(),

  /// Refraction strength of the pill's glass. Higher = more bending.
  double distortion = 0.06,

  /// Width of the pill's refraction band, in logical pixels.
  double distortionWidth = 10,

  /// Magnification of the content seen through the pill (`1` = none).
  double magnification = 1,

  /// When `true`, the pill's inner (non-distorted) area is transparent,
  /// revealing the background directly through the center.
  bool enableInnerRadiusTransparent = false,
}) {
  final extra = extraHeight ?? layout.pillExtraHeight;
  final cellW = layout.cellWidth;
  final barLeft = (parentWidth - layout.width) / 2 + dx;
  final pillLeft = barLeft + layout.padding + animatedIndex * cellW;
  // Center the pill (which may be taller than the cell) vertically
  // over the bar's inner row.
  final pillBottom = layout.bottomMargin + layout.padding - extra / 2;
  final pillH = layout.cellHeight + extra;
  final pillW = layout.pillWidth + extraWidth;
  // Center the extra width on the index so the pill doesn't drift
  // when stretching.
  final adjustedLeft = pillLeft - extraWidth / 2;

  return LiquidGlass(
    key: key,
    position: LiquidGlassOffsetPosition(
      left: adjustedLeft,
      bottom: pillBottom,
    ),
    width: pillW,
    height: pillH,
    magnification: magnification,
    distortion: distortion,
    distortionWidth: distortionWidth,
    enableInnerRadiusTransparent: enableInnerRadiusTransparent,
    chromaticAberration: 0.002,
    color: Colors.white.withAlpha(28),
    blur: blur,
    shape: RoundedRectangleShape(
      cornerRadius: pillH / 2,
      borderWidth: 1.0,
      lightIntensity: 1.3,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.4,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    ),
  );
}

/// Builds the long bar-capsule lens. Place it in the `children:`
/// list of the INNER `LiquidGlassView`. It refracts the wallpaper
/// that the inner view captures, and contributes its glass
/// appearance to the outer view's snapshot — so the selection pill
/// (built with [buildLiquidGlassBottomNavPill]) running in the
/// OUTER view refracts the bar's glass output.
LiquidGlass buildLiquidGlassBottomNavCapsule({
  required LiquidGlassBottomNavBarLayout layout,

  /// Overrides the default bottom-center placement. When non-null the
  /// capsule lens uses this position directly (so the whole animated
  /// bar can honor a caller-supplied position).
  LiquidGlassPosition? position,
}) {
  return LiquidGlass(
    position: position ??
        LiquidGlassAlignPosition(
          alignment: Alignment.bottomCenter,
          margin: EdgeInsets.only(bottom: layout.bottomMargin),
        ),
    width: layout.width,
    height: layout.height,
    magnification: 1,
    distortion: 0.07,
    distortionWidth: 28,
    chromaticAberration: 0.002,
    color: Colors.white.withAlpha(22),
    blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    shape: RoundedRectangleShape(
      cornerRadius: 40,
      borderWidth: 1.2,
      lightIntensity: 1.1,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.2,
        ambientIntensity: 1.0,
        borderSolidity: 0.35,
      ),
    ),
  );
}

/// Plain (non-shader) version of the selection pill, used while the
/// pill is at rest. Visually mimics the optical-rim look of the
/// liquid-glass pill so swapping between the two is unnoticeable.
class LiquidGlassBottomNavPillStatic extends StatelessWidget {
  final double width;
  final double height;

  const LiquidGlassBottomNavPillStatic({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(height / 2),
          // No border — only the moving liquid-glass pill carries
          // the optical rim. The static rest pill is meant to look
          // like a soft highlight, not a framed shape.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}
