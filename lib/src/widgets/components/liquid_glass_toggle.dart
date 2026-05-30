import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import 'liquid_glass_morph_pill.dart';

/// Layout for [LiquidGlassToggleTrack] /
/// [buildLiquidGlassToggleThumb].
///
/// At rest the thumb is a solid **white** horizontal pill sitting
/// inside a tinted track (gray when off, green when on).
///
/// During a slide, the white pill is replaced by a liquid-glass
/// pill that grows larger than the toggle track. The slice of the
/// colored track *behind* the glass simultaneously **pinches** to a
/// shorter height — the rest of the track stays at full height.
/// The glass then refracts whatever sits above and below the
/// pinched slice (typically the wallpaper).
class LiquidGlassToggleLayout {
  final double width;
  final double height;
  final double padding;

  /// Width of the static rest thumb pill. Should be wider than
  /// [thumbHeight] for the pill look.
  final double thumbWidth;

  /// Height of the static rest thumb pill.
  final double thumbHeight;

  /// Extra width the GLASS thumb gains at the peak of the slide
  /// relative to [thumbWidth]. Also drives the WIDTH of the
  /// pinched slice in the colored track.
  final double thumbExtraWidth;

  /// Extra height the GLASS thumb gains at the peak of the slide
  /// relative to [thumbHeight].
  final double thumbExtraHeight;

  /// Height of the pinched slice at the peak of the slide. Make
  /// this noticeably less than [height] so the pinch is visible.
  final double pinchedHeight;

  const LiquidGlassToggleLayout({
    this.width = 64,
    this.height = 32,
    this.padding = 2.5,
    this.thumbWidth = 36,
    this.thumbHeight = 27,
    this.thumbExtraWidth = 36,
    this.thumbExtraHeight = 18,
    this.pinchedHeight = 16,
  });

  /// Travel along the track between off and on positions.
  double get travel => width - thumbWidth - padding * 2;
}

/// Solid white pill — the at-rest toggle thumb.
class _SolidWhiteToggleThumb extends StatelessWidget {
  final double width;
  final double height;

  const _SolidWhiteToggleThumb({required this.width, required this.height});

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

/// Cuts a rounded-rect (pill) hole out of the colored capsule at
/// the glass thumb's exact position. The glass thumb sits on top of
/// this hole and hides the cut edges; a separate "fake" mini pill
/// fills the hole at a smaller height so the user sees a thinner
/// pill inside the glass while the rest of the body stays at full
/// height.
class _GlassHoleClipper extends CustomClipper<Path> {
  final double trackHeight;
  final double holeCenterX;
  final double holeWidth;
  final double holeHeight;

  _GlassHoleClipper({
    required this.trackHeight,
    required this.holeCenterX,
    required this.holeWidth,
    required this.holeHeight,
  });

  @override
  Path getClip(Size size) {
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.height / 2),
      ));

    if (holeWidth <= 0.001 || holeHeight <= 0.001) return outer;

    final holeRect = Rect.fromCenter(
      center: Offset(holeCenterX, size.height / 2),
      width: holeWidth,
      height: holeHeight,
    );
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(
        holeRect,
        Radius.circular(holeHeight / 2),
      ));

    return Path.combine(PathOperation.difference, outer, hole);
  }

  @override
  bool shouldReclip(covariant _GlassHoleClipper old) =>
      old.trackHeight != trackHeight ||
      old.holeCenterX != holeCenterX ||
      old.holeWidth != holeWidth ||
      old.holeHeight != holeHeight;
}

/// Stateless toggle track: capsule background that tints from a
/// gray (off) to a solid color (on), with a static white pill
/// thumb drawn inline. Place inside the INNER `LiquidGlassView`'s
/// `backgroundWidget` so the moving glass thumb (built with
/// [buildLiquidGlassToggleThumb]) can refract it.
///
/// While [pinchFraction] > 0, a pill-shaped hole is cut out of
/// the colored capsule at the glass's x position (driven by
/// [travelFraction]) and a separate, shorter "fake" pill is drawn
/// inside the hole. The glass thumb hides the cut edges entirely,
/// so the user sees: full-height capsule on the sides, plus a
/// thinner pill behind the glass.
class LiquidGlassToggleTrack extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final LiquidGlassToggleLayout layout;

  /// `0` at rest (no hole, plain capsule), `1` at the peak of the
  /// slide (max-size hole + shortest fake pill).
  final double pinchFraction;

  /// `0` when off and `1` when on. Drives where the hole + fake
  /// pill sit along the track. Pass the same value used for the
  /// glass thumb's [buildLiquidGlassToggleThumb] `travelFraction`.
  final double travelFraction;

  /// Tint color of the track when [value] is true. Defaults to a
  /// system green.
  final Color tint;

  /// Background color of the track when [value] is false. Defaults
  /// to a translucent gray that reads well over a glass canvas.
  final Color offColor;

  /// Show/hide the rest thumb (the static white pill). Hide while
  /// the glass lens is taking its place during the slide.
  final bool showRestThumb;

  const LiquidGlassToggleTrack({
    super.key,
    required this.value,
    required this.onChanged,
    this.tint = const Color(0xFF34C759),
    this.offColor = const Color(0x66808080),
    this.layout = const LiquidGlassToggleLayout(),
    this.showRestThumb = true,
    this.pinchFraction = 0,
    this.travelFraction = 0,
  });

  @override
  Widget build(BuildContext context) {
    final p = pinchFraction.clamp(0.0, 1.0);
    final isAnimating = p > 0.001;

    // Hole geometry — slightly inside the glass thumb so the cut
    // edges are guaranteed to be hidden by the glass overhang.
    final holeWidth = layout.thumbWidth + layout.thumbExtraWidth * p * 0.6;
    final holeHeight = layout.thumbHeight + layout.thumbExtraHeight * p * 0.6;

    // Center of the hole at this travel fraction. Mirrors the math
    // used by buildLiquidGlassToggleThumb so the hole tracks the
    // glass.
    final holeCenterX = layout.padding +
        travelFraction * layout.travel +
        layout.thumbWidth / 2;

    // Fake mini pill inside the hole. Spans the toggle's FULL
    // width — `(0, layout.width)` — so its rounded ends line up
    // exactly with the toggle body's rounded ends. Outside the
    // hole the fake pill is masked by the surrounding full-height
    // main capsule (same color), so it has no effect on the
    // rest-of-body appearance.
    final fakeW = layout.width;
    final fakeH =
        layout.height + (layout.pinchedHeight - layout.height) * p;
    final fakeLeft = 0.0;
    final fakeTop = (layout.height - fakeH) / 2;

    // Rest thumb position (white pill at on/off endpoints). Always
    // computed against the rest layout so its on/off positions
    // don't shift while the track changes.
    final thumbLeft =
        layout.padding + (value ? layout.travel : 0.0);
    final thumbTop = (layout.height - layout.thumbHeight) / 2;

    Widget coloredCapsule = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: value ? tint : offColor),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, animatedColor, _) => Container(
        decoration: BoxDecoration(
          color: animatedColor,
          borderRadius: BorderRadius.circular(layout.height / 2),
        ),
      ),
    );

    if (isAnimating) {
      coloredCapsule = ClipPath(
        clipper: _GlassHoleClipper(
          trackHeight: layout.height,
          holeCenterX: holeCenterX,
          holeWidth: holeWidth,
          holeHeight: holeHeight,
        ),
        child: coloredCapsule,
      );
    }

    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Fake mini pill — drawn FIRST (lowest z) so the
            // main capsule (with hole) above masks everything
            // except the part visible through the hole. Spans
            // the toggle's full inner width so the part inside
            // the hole looks like a thinner rounded pill running
            // through it.
            if (isAnimating)
              Positioned(
                left: fakeLeft,
                top: fakeTop,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: value ? tint : offColor),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedColor, _) => Container(
                    width: fakeW,
                    height: fakeH,
                    decoration: BoxDecoration(
                      color: animatedColor,
                      borderRadius: BorderRadius.circular(fakeH / 2),
                    ),
                  ),
                ),
              ),
            // Full-height capsule with a pill-shaped hole cut out
            // while the glass is overhead. At rest, no hole.
            // Drawn ABOVE the fake pill so its hole reveals the
            // fake pill beneath.
            Positioned.fill(child: coloredCapsule),
            // Static white pill thumb. Anchored to the REST rect.
            // Hidden during the slide; the glass takes over.
            if (showRestThumb)
              Positioned(
                left: thumbLeft,
                top: thumbTop,
                child: _SolidWhiteToggleThumb(
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

/// Build the moving glass thumb. [travelFraction] is `0` when off
/// and `1` when on; the parent should drive it via an
/// `AnimationController` running between those two values during
/// the slide.
///
/// [growFraction] is `0` at rest and `1` at the peak of the
/// animation. Drive it with a `sin(π·t)` envelope (see
/// [liquidGlassMorphEnvelope]) so the glass pill grows OUT of the
/// rest pill, peaks bigger than the whole track mid-slide, then
/// shrinks back to the rest size at the destination.
///
/// [trackLeft] / [trackBottom] are the track's bottom-left corner
/// in the outer view's local coordinate space.
LiquidGlass buildLiquidGlassToggleThumb({
  required LiquidGlassToggleLayout layout,
  required double trackLeft,
  required double trackBottom,
  required double travelFraction,
  required double growFraction,
}) {
  final f = growFraction.clamp(0.0, 1.0);
  final extraW = layout.thumbExtraWidth * f;
  final extraH = layout.thumbExtraHeight * f;
  final pillW = layout.thumbWidth + extraW;
  final pillH = layout.thumbHeight + extraH;

  // Center of the rest thumb at this travel fraction, in track-
  // local coordinates. We anchor the GROWN pill on the same center
  // point so it expands evenly outward as it bulges, then settles
  // back.
  final restCenterXInTrack =
      layout.padding + travelFraction * layout.travel + layout.thumbWidth / 2;
  final restCenterYInTrack = layout.height / 2;

  final left = trackLeft + restCenterXInTrack - pillW / 2;
  final bottomFromTrackBottom =
      layout.height - restCenterYInTrack - pillH / 2;
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
