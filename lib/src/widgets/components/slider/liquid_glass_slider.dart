import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_jelly_spring.dart';
import 'liquid_glass_slider_jelly.dart';
import 'liquid_glass_slider_layout.dart';
import 'liquid_glass_slider_thumb.dart';
import 'liquid_glass_slider_track.dart';

export 'liquid_glass_slider_jelly.dart';
export 'liquid_glass_slider_layout.dart';
export 'liquid_glass_slider_thumb.dart';
export 'liquid_glass_slider_track.dart';

/// A drop-in liquid-glass slider.
///
/// This is the **developer-facing** component: it owns its own
/// [LiquidGlassView], the track ([LiquidGlassSliderTrack]), the moving
/// glass thumb ([buildLiquidGlassSliderThumb]) and all the interaction
/// animation (grow-on-press + the signed "jelly" spring that leans the
/// thumb in the drag direction) — so you just give it a [value] in
/// `0..1` and an [onChanged] like a regular `Slider`.
///
/// At rest it shows a solid white pill on the track. While the user
/// drags, the pill is replaced by a liquid-glass pill that grows, leans
/// into the motion, and refracts the track underneath.
///
/// ```dart
/// LiquidGlassSlider(
///   value: _v,
///   onChanged: (v) => setState(() => _v = v),
///   activeColor: Colors.white,
/// )
/// ```
///
/// See [transparentWhenBlack] for how the glass overhang avoids drawing
/// black over the transparent area around the track.
class LiquidGlassSlider extends StatefulWidget {
  /// Current value, in `0..1`.
  final double value;

  /// Called continuously with the new value while the user drags.
  final ValueChanged<double> onChanged;

  /// Called when a drag (or tap) begins.
  final ValueChanged<double>? onChangeStart;

  /// Called when the drag ends.
  final ValueChanged<double>? onChangeEnd;

  /// Color of the filled (left) portion of the track.
  final Color activeColor;

  /// Color of the unfilled track background.
  final Color inactiveColor;

  /// Track + thumb geometry. Defaults to a 280-wide track.
  final LiquidGlassSliderLayout layout;

  /// Whether a refracted background sample that comes out (near) black
  /// is rendered transparent instead of black. Recommended `true` for
  /// this self-contained component. Defaults to `true`.
  final bool transparentWhenBlack;

  /// Capture resolution for the inner view. `1.0` is a good default; use
  /// less for cheaper captures, `0.0` for the device pixel ratio.
  final double pixelRatio;

  /// Jelly deformation model + tuning. Defaults to the original
  /// "pinch & extrude" feel; pass a
  /// [LiquidGlassSliderJellyStyle.stretch] config for the iOS-like
  /// elongate-along-motion variant.
  final LiquidGlassSliderJelly jelly;

  const LiquidGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor = Colors.white,
    this.inactiveColor = const Color(0x3CFFFFFF),
    this.layout = const LiquidGlassSliderLayout(),
    this.transparentWhenBlack = true,
    this.pixelRatio = 1.0,
    this.jelly = const LiquidGlassSliderJelly(),
  });

  @override
  State<LiquidGlassSlider> createState() => _LiquidGlassSliderState();
}

class _LiquidGlassSliderState extends State<LiquidGlassSlider>
    with TickerProviderStateMixin {
  final LiquidGlassViewController _viewController = LiquidGlassViewController();

  /// Grow envelope: ramps 0→1 on touch-down, holds while dragging,
  /// reverses to 0 on release.
  late final AnimationController _grow;

  bool _dragging = false;

  /// The shared jelly simulation (lean spring + deform spring +
  /// direction memory). The slider feeds it drag values and maps its
  /// outputs onto the thumb geometry in [buildLiquidGlassSliderThumb].
  final LiquidGlassJellySpring _jelly = LiquidGlassJellySpring();

  /// Last ticker `elapsed`, used as the spring integrator's `dt`.
  Duration? _jellyTickerLast;
  Ticker? _jellyTicker;

  /// Geometry stashed by [build] so the thumb-child gesture surface can
  /// map a global pointer position to a 0..1 value (same math as the
  /// track's own hit handling).
  double _gesturePadX = 0;
  double _gestureInnerWidth = 1;

  /// Maps a global pointer position to a slider value and reports it.
  void _handleGlobalDrag(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(globalPosition);
    final clamped =
        ((local.dx - _gesturePadX) / _gestureInnerWidth).clamp(0.0, 1.0);
    _onChanged(clamped);
  }

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _grow.addListener(() => setState(() {}));
    _syncJellyConfig();
    _jelly.start(widget.value);
    _jellyTicker = createTicker(_onJellyTick);
    // TEMP test: run the capture pipeline from startup instead of
    // starting it on the first grab, to check whether the cold capture
    // start is the first-touch stall.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewController.startRealtimeCapture();
    });
  }

  @override
  void dispose() {
    _jellyTicker?.dispose();
    _grow.dispose();
    super.dispose();
  }

  /// Pushes the widget's physics tuning into the shared simulation.
  /// Called every tick so a live change to [LiquidGlassSlider.jelly]
  /// applies immediately, matching the old inline behavior.
  void _syncJellyConfig() {
    _jelly
      ..stiffness = widget.jelly.stiffness
      ..damping = widget.jelly.damping
      ..maxVelocity = widget.jelly.maxVelocity
      ..directionTau = widget.jelly.directionTau;
  }

  void _onStart(double v) {
    _dragging = true;
    _viewController.startRealtimeCapture();
    _grow
      ..stop()
      ..forward(from: _grow.value);
    _syncJellyConfig();
    _jelly.start(widget.value);
    _jellyTickerLast = null;
    _jellyTicker?.start();
    widget.onChangeStart?.call(v);
  }

  void _onChanged(double v) {
    widget.onChanged(v);
    _jelly.pump(v);
  }

  void _onEnd(double v) {
    _dragging = false;
    _grow.reverse(from: _grow.value);
    _jelly.release(); // spring momentum carries the overshoot
    widget.onChangeEnd?.call(v);
  }

  void _onJellyTick(Duration elapsed) {
    final last = _jellyTickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _jellyTickerLast = elapsed;

    _syncJellyConfig();
    final settled = _jelly.tick(dt, dragging: _dragging);
    if (settled) _jellyTicker?.stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final bool glassActive = _dragging || _grow.isAnimating;

    // Padding so the grown AND jelly-deformed thumb is always fully
    // inside the inner view — so it is never clipped at the ends, and
    // its position never hits the clamp (which would pin it before the
    // end and drift on release). The jelly spring output is clamped to
    // +/-1.5 inside the thumb builder, so use that as the peak.
    const jellyPeak = 1.5;
    // Horizontal: exactly half the (grown) pill width — the pill sits
    // centered on the track end and overhangs it by half its width.
    // The stretch style additionally elongates the pill along the drag
    // axis and shifts its center by the anchor bias, so reserve the
    // worst-case reach of (added width + bias shift) on each side.
    final jelly = widget.jelly;
    final stretchReach = jelly.style == LiquidGlassSliderJellyStyle.stretch
        ? jelly.stretchWidth * jellyPeak * (1 + jelly.anchorBias.abs()) / 2
        : 0.0;
    final maxPillW = layout.thumbWidth + layout.thumbExtraWidth;
    final padX = maxPillW / 2 + stretchReach;
    // Vertical: half of the (grown + stretched) pill beyond the track.
    // The stretch style gains height during the stop-recoil
    // (squashHeight × recoilScale at peak spring overshoot) instead of
    // the pinch style's thumbStretchHeight.
    final jellyHeightGain = jelly.style == LiquidGlassSliderJellyStyle.stretch
        ? jelly.squashHeight * jelly.recoilScale * jellyPeak
        : layout.thumbStretchHeight * jellyPeak;
    final maxPillH =
        layout.thumbHeight + layout.thumbExtraHeight + jellyHeightGain;
    final padY = math.max(0.0, (maxPillH - layout.thumbHeight) / 2) + 2.0;

    // Inset the track INSIDE the requested width instead of widening the
    // widget. The widget stays exactly `layout.width` wide; the visible
    // track is narrowed by padX on each side (and stays centered), so
    // the thumb's horizontal overhang lives inside that width — no shift,
    // no extra width. Height still grows by padY to fit the taller
    // (grown) thumb vertically.
    final innerLayout = LiquidGlassSliderLayout(
      width: math.max(0.0, layout.width - padX * 2),
      trackHeight: layout.trackHeight,
      thumbWidth: layout.thumbWidth,
      thumbHeight: layout.thumbHeight,
      thumbExtraWidth: layout.thumbExtraWidth,
      thumbExtraHeight: layout.thumbExtraHeight,
      thumbSqueezeWidth: layout.thumbSqueezeWidth,
      thumbStretchHeight: layout.thumbStretchHeight,
    );
    final viewWidth = layout.width;
    final viewHeight = layout.thumbHeight + padY * 2;

    _gesturePadX = padX;
    _gestureInnerWidth = math.max(1.0, innerLayout.width);

    return SizedBox(
      width: viewWidth,
      height: viewHeight,
      child: LiquidGlassView(
        controller: _viewController,
        pixelRatio: widget.pixelRatio,
        realTimeCapture: true,
        useSync: true,
        backgroundWidget: Stack(
          children: [
            Positioned(
              // Span the full view width: the track's visible body is
              // re-centered inside via hitSlopX, while the gesture area
              // now reaches the very ends, so the thumb's half-overhang
              // at value 0 and 1 (which lives in padX) is tappable.
              left: 0,
              top: padY,
              child: LiquidGlassSliderTrack(
                value: widget.value,
                onChanged: _onChanged,
                onChangeStart: _onStart,
                onChangeEnd: _onEnd,
                // The white rest handle is rendered INSIDE the glass
                // lens (as its child) so it sits ON TOP of the glass
                // pill — never here in the background, which lenses
                // always cover.
                showRestThumb: false,
                activeColor: widget.activeColor,
                inactiveColor: widget.inactiveColor,
                layout: innerLayout,
                hitSlopX: padX,
              ),
            ),
          ],
        ),
        children: [
          // The glass thumb is ALWAYS mounted. At rest (growFraction 0,
          // springs at 0) it is exactly the size of the handle and sits
          // UNDER the white rest pill, which is rendered as the lens's
          // child — on top of the glass. On grab the white pill hides
          // and the glass (already rendered all along) grows and
          // jelly-deforms, so nothing new is created at first touch.
          // The child also carries the handle's gesture surface, since
          // the lens sits above the track and would otherwise block it.
          buildLiquidGlassSliderThumb(
            layout: innerLayout,
            trackLeft: padX,
            trackBottom: padY,
            value: widget.value,
            growFraction: _grow.value,
            // The stretch style is driven by the speed-based
            // deform spring (sign = stretch vs recoil); the pinch
            // style keeps the direction-signed spring.
            stretchFraction:
                widget.jelly.style == LiquidGlassSliderJellyStyle.stretch
                    ? _jelly.deform
                    : _jelly.stretch,
            // Smoothed direction memory: the lean follows it
            // continuously, flipping softly across a reversal.
            motionSign: _jelly.direction,
            jelly: widget.jelly,
            transparentWhenBlack: widget.transparentWhenBlack,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) {
                _onStart(widget.value);
                _handleGlobalDrag(d.globalPosition);
              },
              onHorizontalDragUpdate: (d) =>
                  _handleGlobalDrag(d.globalPosition),
              onHorizontalDragEnd: (_) => _onEnd(widget.value),
              onTapDown: (d) {
                _onStart(widget.value);
                _handleGlobalDrag(d.globalPosition);
              },
              onTapUp: (_) => _onEnd(widget.value),
              // White rest handle, drawn over the glass. Hidden (but
              // still hit-testable) while the glass is active.
              child: glassActive
                  ? const SizedBox.expand()
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          innerLayout.thumbHeight / 2,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
