import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import 'liquid_glass_morph_pill.dart';

/// Public layout for [LiquidGlassSliderTrack] /
/// [buildLiquidGlassSliderThumb].
///
/// At rest the slider thumb is a solid **white** pill sitting in
/// the track. While the user holds the thumb the white pill is
/// hidden and a slightly larger liquid-glass pill takes its place
/// (built via [buildLiquidGlassSliderThumb] and placed in the
/// OUTER `LiquidGlassView`'s `children:` list).
class LiquidGlassSliderLayout {
  /// Width of the slider track in logical pixels.
  final double width;

  /// Height of the track (background + filled portion).
  final double trackHeight;

  /// Width of the static rest thumb pill.
  final double thumbWidth;

  /// Height of the static rest thumb pill.
  final double thumbHeight;

  /// Extra width the GLASS thumb gains while held (relative to
  /// [thumbWidth]).
  final double thumbExtraWidth;

  /// Extra height the GLASS thumb gains while held (relative to
  /// [thumbHeight]).
  final double thumbExtraHeight;

  /// How much **narrower** the glass thumb gets at peak drag
  /// velocity — the jelly squeezes inward along the direction of
  /// motion as it's pulled. Should be small relative to
  /// [thumbWidth] so the pill never disappears.
  final double thumbSqueezeWidth;

  /// How much **taller** the glass thumb gets at peak drag
  /// velocity — the jelly extends vertically as the horizontal
  /// width squeezes, suggesting volume preservation.
  final double thumbStretchHeight;

  const LiquidGlassSliderLayout({
    this.width = 280,
    this.trackHeight = 8,
    this.thumbWidth = 40,
    this.thumbHeight = 26,
    this.thumbExtraWidth = 14,
    this.thumbExtraHeight = 10,
    this.thumbSqueezeWidth = 6,
    this.thumbStretchHeight = 10,
  });

  /// Pixel range over which the thumb's center can travel.
  double get travel => width;
}

/// Solid white pill — the at-rest slider thumb.
class _SolidWhiteSliderThumb extends StatelessWidget {
  final double width;
  final double height;

  const _SolidWhiteSliderThumb({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateless track + filled portion + tap/drag handling. Place this
/// inside the INNER `LiquidGlassView`'s `backgroundWidget` so the
/// glass thumb lens (built with [buildLiquidGlassSliderThumb]) can
/// refract the track during drags.
///
/// The thumb at rest is drawn here too as a static white pill. The
/// caller is responsible for hiding it (set [showRestThumb] to
/// false) while the glass lens is visible above.
class LiquidGlassSliderTrack extends StatelessWidget {
  /// Current value in 0..1.
  final double value;

  /// Notified continuously while the user drags.
  final ValueChanged<double> onChanged;

  /// Notified when the user starts a drag (or taps).
  final ValueChanged<double>? onChangeStart;

  /// Notified when the user releases.
  final ValueChanged<double>? onChangeEnd;

  /// Show/hide the rest thumb (the white pill). Hide while the
  /// glass lens is taking its place.
  final bool showRestThumb;

  final LiquidGlassSliderLayout layout;

  const LiquidGlassSliderTrack({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.showRestThumb = true,
    this.layout = const LiquidGlassSliderLayout(),
  });

  void _handle(double localX) {
    final clamped = (localX / layout.width).clamp(0.0, 1.0);
    onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final trackRadius = layout.trackHeight / 2;

    // Rest thumb position — center on the value.
    final thumbCenterX = value * layout.travel;
    final thumbLeft = thumbCenterX - layout.thumbWidth / 2;

    return SizedBox(
      width: layout.width,
      height: layout.thumbHeight, // reserve room for the thumb
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) {
          onChangeStart?.call(value);
          _handle(d.localPosition.dx);
        },
        onHorizontalDragUpdate: (d) => _handle(d.localPosition.dx),
        onHorizontalDragEnd: (_) => onChangeEnd?.call(value),
        onTapDown: (d) {
          onChangeStart?.call(value);
          _handle(d.localPosition.dx);
        },
        onTapUp: (_) => onChangeEnd?.call(value),
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // Track at rest height, vertically centered.
            Positioned(
              left: 0,
              top: (layout.thumbHeight - layout.trackHeight) / 2,
              child: SizedBox(
                width: layout.width,
                height: layout.trackHeight,
                child: Stack(
                  children: [
                    // Track background.
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(60),
                        borderRadius: BorderRadius.circular(trackRadius),
                      ),
                    ),
                    // Filled portion.
                    FractionallySizedBox(
                      widthFactor: value,
                      heightFactor: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(trackRadius),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Static white rest thumb. Hidden during the slide; the
            // glass thumb takes over above the track.
            if (showRestThumb)
              Positioned(
                left: thumbLeft,
                top: 0,
                child: _SolidWhiteSliderThumb(
                  width: layout.thumbWidth,
                  height: layout.thumbHeight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

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
}) {
  final f = growFraction.clamp(0.0, 1.0);
  final extraW = layout.thumbExtraWidth * f;
  final extraH = layout.thumbExtraHeight * f;

  final s = stretchFraction.clamp(-1.5, 1.5);
  final sMag = s.abs();
  final sSign = s.isNegative ? -1.0 : 1.0;

  // Horizontal SQUEEZE — pill becomes a touch narrower while the
  // spring is loaded. The center bias below makes the leading
  // edge lead the trailing edge.
  final squeezeW = -layout.thumbSqueezeWidth * sMag;
  // Vertical STRETCH — pill becomes taller as the width squeezes,
  // suggesting volume preservation.
  final stretchH = layout.thumbStretchHeight * sMag;
  // Center bias: pill's center shifts a touch in the direction of
  // motion. Tied to the squeeze magnitude so the lean scales with
  // the spring load.
  final centerBiasX = layout.thumbSqueezeWidth * 0.6 * sMag * sSign;

  final pillW = layout.thumbWidth + extraW + squeezeW;
  final pillH = layout.thumbHeight + extraH + stretchH;

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
  );
}
