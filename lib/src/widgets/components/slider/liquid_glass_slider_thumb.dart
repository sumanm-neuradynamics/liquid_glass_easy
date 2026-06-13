import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../liquid_glass.dart';
import '../liquid_glass_morph_pill.dart';
import 'liquid_glass_slider_jelly.dart';
import 'liquid_glass_slider_layout.dart';

/// Builds the moving glass thumb at the requested track position.
/// Place the result in the OUTER `LiquidGlassView`'s `children:`
/// list. While the user holds the thumb, drive [growFraction]
/// toward `1` (peak overlay size). Reverse it back to `0` on
/// release.
///
/// **Signed jelly spring:**
///
/// - [stretchFraction] (-1..1) — signed spring output. Sign tells
///   the direction the thumb is being dragged (negative = left,
///   positive = right); magnitude tells how hard. The glass pill
///   **squeezes narrower** along its long axis while
///   **stretching taller** in the cross axis (a vertical
///   "pinch & extrude" rather than a horizontal stretch — the
///   pill leans into the drag like a soft jelly bead). Its center
///   is biased slightly in the direction of motion via the sign so
///   the leading edge leads the trailing edge.
///
/// On release, drive the spring's target to 0; the spring's own
/// momentum produces a single overshoot, then settle. There is no
/// separate rebound state; the spring's underdamping handles it.
///
/// [trackLeft] / [trackBottom] are the track's bottom-left corner
/// in the OUTER view's local coordinate space.
LiquidGlass buildLiquidGlassSliderThumb({
  required LiquidGlassSliderLayout layout,
  required double trackLeft,
  required double trackBottom,
  required double value,
  required double growFraction,
  double stretchFraction = 0,

  /// `stretch` style only: the smoothed motion direction in `-1..1`
  /// (negative = left). Drives the anchor-bias lean; the deformation
  /// itself is direction-symmetric.
  double motionSign = 1,
  LiquidGlassSliderJelly jelly = const LiquidGlassSliderJelly(),

  /// Optional content rendered inside the lens, above the glass (e.g.
  /// the white rest handle + its gesture surface).
  Widget? child,
}) {
  final f = growFraction.clamp(0.0, 1.0);
  final extraW = layout.thumbExtraWidth * f;
  final extraH = layout.thumbExtraHeight * f;

  final s = stretchFraction.clamp(-1.5, 1.5);
  final sMag = s.abs();
  final sSign = s.isNegative ? -1.0 : 1.0;

  final double deltaW;
  final double deltaH;
  final double centerBiasX;

  if (jelly.style == LiquidGlassSliderJellyStyle.pinchExtrude) {
    // Horizontal SQUEEZE — pill becomes a touch narrower while the
    // spring is loaded. The center bias below makes the leading
    // edge lead the trailing edge.
    deltaW = -layout.thumbSqueezeWidth * sMag;
    // Vertical STRETCH — pill becomes taller as the width squeezes,
    // suggesting volume preservation.
    deltaH = layout.thumbStretchHeight * sMag;
    // Center bias: pill's center shifts a touch in the direction of
    // motion. Tied to the squeeze magnitude so the lean scales with
    // the spring load.
    centerBiasX = layout.thumbSqueezeWidth * 0.6 * sMag * sSign;
  } else {
    // iOS-style squash & stretch. Here [stretchFraction] is the SIGNED
    // deform spring value, not a direction:
    //   d > 0 — moving: elongate along the drag axis, flatten slightly
    //           (volume preservation).
    //   d < 0 — just stopped: the spring overshot through neutral, so
    //           the volume rebounds the other way — narrower and TALLER
    //           — before wobbling to rest. recoilScale exaggerates it.
    // Direction comes in via [motionSign] and only drives the lean.
    final d = s >= 0 ? s : s * jelly.recoilScale;
    // Keep the pill from inverting under extreme recoil settings.
    deltaW = math.max(jelly.stretchWidth * d, -layout.thumbWidth * 0.45);
    deltaH = math.max(-jelly.squashHeight * d, -layout.thumbHeight * 0.4);
    // The anchor-bias lean applies only while stretched along the
    // motion.
    final leanBias = jelly.anchorBias * (math.max(deltaW, 0) / 2) * motionSign;
    // Recoil squash is momentum-sided: shifting the center toward the
    // (remembered) motion direction by recoilAnchor × half the lost
    // width pins the leading edge in place, so the whole compression is
    // absorbed by the trailing side — it piles into the front instead
    // of shrinking symmetrically. _dir still holds the OLD direction at
    // squash onset (it lags by design), which is the correct anchor for
    // both the stop and the reversal case.
    final squashShift =
        deltaW < 0 ? jelly.recoilAnchor * (-deltaW / 2) * motionSign : 0.0;
    centerBiasX = leanBias + squashShift;
  }

  final pillW = layout.thumbWidth + extraW + deltaW;
  final pillH = layout.thumbHeight + extraH + deltaH;

  // Center of the rest thumb at this value, in track-local
  // coordinates. The grown pill expands evenly outward from there.
  final thumbCenterXInTrack = value * layout.travel;
  final thumbCenterYInTrack = layout.thumbHeight / 2;

  final left = trackLeft + thumbCenterXInTrack - pillW / 2 + centerBiasX;
  final bottomFromTrackBottom =
      layout.thumbHeight - thumbCenterYInTrack - pillH / 2;
  final bottom = trackBottom + bottomFromTrackBottom;

  final spec = LiquidGlassMorphPillSpec(
    width: pillW,
    restHeight: pillH,
    extraHeight: 0,
    restRadius: pillH / 2,
  );

  return buildLiquidGlassMorphPill(
    spec: spec,
    left: left,
    bottom: bottom,
    extraHeight: 0,
    child: child,
  );
}
