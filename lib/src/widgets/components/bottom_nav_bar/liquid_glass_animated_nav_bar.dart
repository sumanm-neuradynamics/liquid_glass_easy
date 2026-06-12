import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../controllers/liquid_glass_view_controller.dart';
import '../../liquid_glass.dart';
import '../../liquid_glass_view.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_jelly_spring.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_refresh_rate.dart';
import '../liquid_glass_morph_pill.dart' show liquidGlassMorphEnvelope;
import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_bottom_nav_bar.dart';

/// Self-contained **animated** liquid-glass bottom nav bar —
/// the iOS-26 "morphing glass pill" that slides between tabs, grows out
/// of the rest highlight, can be dragged with a jelly-spring stretch,
/// and reveals the selected icon as it passes.
///
/// This is the internal machinery behind
/// [LiquidGlassBottomNavBar.glassPill]: it owns the entire dual
/// `LiquidGlassView` pipeline and is built by
/// [LiquidGlassBottomNavBar.buildGlassPillBar] (which
/// `LiquidGlassScaffold` calls when the bar's `glassPill` mode resolves
/// for the active renderer). Prefer configuring it through
/// [LiquidGlassBottomNavBar] — constructing it directly still works,
/// but it will be hidden from the public API in 3.0.
///
/// [body] is the page content, captured behind the glass. [outerLenses]
/// are composited in the outer view on top of the bar (e.g. the app bar
/// and the side action button).
class LiquidGlassAnimatedNavBar extends StatefulWidget {
  final Widget body;
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Bar geometry (size, position, padding). The bottom margin should
  /// already include any safe-area inset.
  final LiquidGlassBottomNavBarLayout layout;

  /// Lenses composited in the **outer** view, above the bar — typically
  /// the app bar, the side action button, and any extra glass.
  final List<LiquidGlass> outerLenses;

  /// Optional solid color behind [body].
  final Color? backgroundColor;

  /// Custom placement for the bar. When non-null, the capsule, pill,
  /// icon shell, rest pill, and gesture overlay all honor it (resolved
  /// against the parent size). When `null` the bar is bottom-center
  /// anchored via [layout]'s `bottomMargin`.
  final LiquidGlassPosition? barPosition;

  /// Blur behind the moving glass pill. Defaults to none.
  final LiquidGlassBlur pillBlur;

  /// How much taller the glass pill grows than the bar at peak travel —
  /// the pill's size knob. Peak height is `layout.height + pillGrowHeight`.
  final double pillGrowHeight;

  /// Refraction strength of the moving glass pill.
  final double pillDistortion;

  /// Width of the glass pill's refraction band.
  final double pillDistortionWidth;

  /// Magnification of the content seen through the glass pill.
  final double pillMagnification;

  /// When `true`, the glass pill's inner area is transparent.
  final bool pillEnableInnerRadiusTransparent;

  // Render pipeline knobs forwarded to both views.
  final double pixelRatio;
  final bool useSync;
  final bool? useImpellerBackdrop;

  /// Whether the **inner** view (body + bar capsule) captures every
  /// frame. `true` (default) keeps the bar's refraction live as the
  /// body scrolls/animates — important on Skia, where the capsule reads
  /// a captured snapshot. `false` falls back to snapshot-at-rest and
  /// only wakes the inner pipeline during a morph (cheaper for a static
  /// body). No effect on Impeller, which always samples the live
  /// backdrop.
  final bool realTimeCapture;

  const LiquidGlassAnimatedNavBar({
    super.key,
    required this.body,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
    this.outerLenses = const [],
    this.backgroundColor,
    this.barPosition,
    this.pillBlur = const LiquidGlassBlur(),
    this.pillGrowHeight = 16,
    this.pillDistortion = 0.06,
    this.pillDistortionWidth = 10,
    this.pillMagnification = 1,
    this.pillEnableInnerRadiusTransparent = false,
    this.pixelRatio = 1.0,
    this.useSync = true,
    this.useImpellerBackdrop,
    this.realTimeCapture = true,
  });

  @override
  State<LiquidGlassAnimatedNavBar> createState() =>
      _LiquidGlassAnimatedNavBarState();
}

class _LiquidGlassAnimatedNavBarState extends State<LiquidGlassAnimatedNavBar>
    with TickerProviderStateMixin {
  // Inner pipeline captures wallpaper + bar capsule; outer composites
  // the moving glass pill on top so it refracts the bar's own glass.
  final _outerViewController = LiquidGlassViewController();
  final _innerViewController = LiquidGlassViewController();

  /// Live selection driving the animation (source of truth internally).
  late int _tabIndex;

  /// Index the static UI (shell icons, rest pill) shows as selected.
  /// Flips only AFTER the glass finishes travelling.
  late int _tabIndexCommitted;

  /// True while the glass pill should be on screen (animating/dragging).
  bool _pillGlassActive = false;
  bool _settlingFromDrag = false;

  /// Fractional pill position (0..itemCount-1).
  double _tabPillFracIndex = 0;
  bool _tabDragging = false;

  // ── Travel spring ────────────────────────────────────────────────
  // The pill's position is spring-driven (same underdamped integrator
  // as the jelly), so a tap travels with momentum and settles with a
  // single soft overshoot instead of an eased tween.
  double _travelPos = 0;
  double _travelVel = 0;
  double _travelTarget = 0;

  /// Position the current travel started from — used to derive the
  /// morph-grow envelope's progress.
  double _travelFrom = 0;

  /// True from the moment a travel starts until the spring settles.
  bool _travelActive = false;

  /// Grow envelope value during the drag-release settle (decays 1 → 0).
  double _settleGrow = 0;

  /// Drag jelly — the shared simulation, tuned for tab-fraction units
  /// (a full-speed flick crosses several cells per second).
  final LiquidGlassJellySpring _dragJelly =
      LiquidGlassJellySpring(maxVelocity: 8, velocityClamp: 60);

  /// Single ticker driving the travel spring, the drag jelly and the
  /// settle-grow decay.
  Ticker? _ticker;
  Duration? _tickerLast;

  /// Absolute left edge of the bar in the parent, recomputed each build
  /// from [LiquidGlassAnimatedNavBar.barPosition] (or centered). Used by
  /// the drag math so the pill tracks a moved bar.
  double _barLeft = 0;

  /// Effective bottom inset of the bar (from a custom position, or the
  /// layout's `bottomMargin`).
  double _effBottomMargin = 0;

  LiquidGlassBottomNavBarLayout get _layout => widget.layout;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.selectedIndex;
    _tabIndexCommitted = widget.selectedIndex;
    _tabPillFracIndex = widget.selectedIndex.toDouble();
    _travelPos = widget.selectedIndex.toDouble();
    _travelTarget = _travelPos;
    _travelFrom = _travelPos;
    _ticker = createTicker(_onTick);
  }

  /// Starts the shared ticker if it isn't already running. The ticker's
  /// `elapsed` restarts from zero on every `start()`, so the last-seen
  /// timestamp must be cleared or the first `dt` would be negative.
  void _startTicker() {
    if (_ticker?.isActive != true) {
      _tickerLast = null;
      _ticker?.start();
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassAnimatedNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External (programmatic) selection change — animate to it without
    // re-notifying the parent.
    if (widget.selectedIndex != _tabIndex &&
        widget.selectedIndex != oldWidget.selectedIndex) {
      _animateTo(widget.selectedIndex, notify: false);
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _outerViewController.detach();
    _innerViewController.detach();
    super.dispose();
  }

  // ── Capture lifecycle ────────────────────────────────────────────
  // When [LiquidGlassAnimatedNavBar.realTimeCapture] is true the inner
  // view already captures every frame (so a scrolling/animated body
  // refracts live), and these are no-ops. When it's false the inner
  // pipeline is snapshot-only at rest and we briefly wake it during a
  // morph so the moving glass has live frames to refract.
  void _startCapture() {
    if (!widget.realTimeCapture) _innerViewController.startRealtimeCapture();
  }

  void _maybeStopCapture() {
    if (widget.realTimeCapture) return; // keep the inner pipeline live
    if (!_travelActive && !_tabDragging) {
      _innerViewController.stopRealtimeCapture();
    }
  }

  // ── Selection / animation ────────────────────────────────────────
  void _animateTo(int next, {required bool notify}) {
    if (next == _tabIndex) return;
    setState(() {
      _tabIndex = next;
      _pillGlassActive = true;
      _settlingFromDrag = false;
      _travelActive = true;
      // Retarget from wherever the pill currently is (so a tap during
      // a travel is handled gracefully); the spring keeps its velocity.
      _travelFrom = _travelPos;
      _travelTarget = next.toDouble();
    });
    _startCapture();
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  // ── Gesture geometry ─────────────────────────────────────────────
  double _xToTabFrac(double globalDx) {
    // `_barLeft` is the bar's absolute left (honors a custom position).
    final cell0Center =
        _barLeft + _layout.padding + _layout.cellWidth / 2;
    final cellW = _layout.cellWidth;
    final raw = (globalDx - cell0Center) / cellW;
    return raw.clamp(0.0, (_layout.itemCount - 1).toDouble());
  }

  void _onTabBarTapUp(TapUpDetails d) {
    final cellW = _layout.cellWidth;
    final raw = d.localPosition.dx / cellW;
    final idx = raw.floor().clamp(0, _layout.itemCount - 1);
    _animateTo(idx, notify: true);
  }

  // ── Drag handlers ────────────────────────────────────────────────
  void _onTabPillDragStart(DragStartDetails d) {
    _tabDragging = true;
    _pillGlassActive = true;
    _settlingFromDrag = false;
    _travelActive = false;
    _startCapture();
    final frac = _xToTabFrac(d.globalPosition.dx);
    _dragJelly.start(frac);
    // Keep the spring's notion of position in sync so an interrupted
    // tap-travel hands over to the finger without a jump.
    _travelPos = frac;
    _travelVel = 0;
    _startTicker();
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillDragUpdate(DragUpdateDetails d) {
    if (!_tabDragging) return;
    final frac = _xToTabFrac(d.globalPosition.dx);
    _dragJelly.pump(frac);
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillDragEnd(DragEndDetails d) => _releaseTabPillDrag();

  void _onTabPillDragCancel() {
    if (!_tabDragging) return;
    _releaseTabPillDrag();
  }

  void _releaseTabPillDrag() {
    final from = _tabPillFracIndex;
    final next = from.round().clamp(0, _layout.itemCount - 1);
    final notify = next != _tabIndex;
    setState(() {
      _tabDragging = false;
      _settlingFromDrag = true;
      _tabIndex = next;
      _pillGlassActive = true;
      _travelActive = true;
      _travelFrom = from;
      _travelPos = from;
      _travelVel = 0;
      _travelTarget = next.toDouble();
      _settleGrow = 1.0;
    });
    _dragJelly.release();
    _startTicker();
    if (notify) widget.onChanged(next);
  }

  /// One frame of the spring system: travel spring, drag jelly, and
  /// the drag-release grow decay. Commits the selection and drops the
  /// glass the moment everything has settled.
  void _onTick(Duration elapsed) {
    final last = _tickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tickerLast = elapsed;

    final jellySettled = _dragJelly.tick(dt, dragging: _tabDragging);

    bool travelSettled = true;
    if (_travelActive) {
      final r = liquidGlassSpringStep(
        x: _travelPos,
        vel: _travelVel,
        target: _travelTarget,
        dt: dt,
        stiffness: _kTravelStiffness,
        damping: _kTravelDamping,
      );
      _travelPos = r.$1;
      _travelVel = r.$2;
      travelSettled = (_travelPos - _travelTarget).abs() < 0.003 &&
          _travelVel.abs() < 0.05;
      if (travelSettled) {
        _travelPos = _travelTarget;
        _travelVel = 0;
      }
    }

    // Drag-release grow decay — replaces the old 140ms linear shrink.
    if (_settlingFromDrag && _settleGrow > 0) {
      const tau = 0.06;
      _settleGrow *= math.exp(-dt / tau);
      if (_settleGrow < 0.01) _settleGrow = 0;
    }
    final growSettled = !_settlingFromDrag || _settleGrow == 0;

    if (_travelActive && travelSettled && growSettled && !_tabDragging) {
      // Commit atomically in the SAME frame the glass pill turns off.
      // Deferring the commit to a post-frame callback left one frame
      // where the glass was gone but the shell still showed the OLD
      // committed index — the "old icon flashes white" glitch.
      _travelActive = false;
      _pillGlassActive = false;
      _settlingFromDrag = false;
      _settleGrow = 0;
      _tabIndexCommitted = _tabIndex;
      _maybeStopCapture();
    }

    if (!_tabDragging && !_travelActive && jellySettled) {
      _ticker?.stop();
    }
    if (mounted) setState(() {});
  }

  /// Travel spring tuning — the same family as the jelly (underdamped,
  /// one soft overshoot at arrival).
  static const double _kTravelStiffness = 320;
  static const double _kTravelDamping = 22;

  bool get _pillGlassVisible => _travelActive || _tabDragging;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final parentWidth = constraints.maxWidth;
      final parentHeight = constraints.maxHeight;

      // Resolve the bar's placement. A custom position is honored by the
      // capsule, pill, shell, rest pill, and gesture overlay; otherwise
      // the bar is bottom-center anchored via the layout's bottomMargin.
      final centeredLeft = (parentWidth - _layout.width) / 2;
      if (widget.barPosition != null) {
        final off = widget.barPosition!.resolve(
          Size(parentWidth, parentHeight),
          Size(_layout.width, _layout.height),
        );
        _barLeft = off.dx;
        _effBottomMargin = parentHeight - off.dy - _layout.height;
      } else {
        _barLeft = centeredLeft;
        _effBottomMargin = _layout.bottomMargin;
      }
      final dx = _barLeft - centeredLeft;
      final layout = _layout.copyWith(bottomMargin: _effBottomMargin);

      final cellW = layout.cellWidth;

      // Glass pill geometry: same w:h ratio as the rest pill, scaled
      // up so the glass is a touch bigger than the bar height.
      final glassOverflowPx = widget.pillGrowHeight;
      final restRatio = layout.pillWidth / layout.cellHeight;
      final targetGlassH = layout.height + glassOverflowPx;
      final targetGlassW = targetGlassH * restRatio;

      // Travel progress for the morph-grow envelope, derived from the
      // spring's remaining distance. An overshoot past the target
      // clamps to 1, so the pill is back at rest size while the
      // position wobble settles — the wobble reads in the motion, not
      // the geometry.
      final travelSpan = (_travelTarget - _travelFrom).abs();
      final travelP = travelSpan < 1e-6
          ? 1.0
          : (1.0 - (_travelTarget - _travelPos).abs() / travelSpan)
              .clamp(0.0, 1.0);

      // Morph-grow envelope.
      final double growT;
      if (_tabDragging) {
        growT = 1.0;
      } else if (_settlingFromDrag) {
        growT = _settleGrow;
      } else if (_travelActive) {
        growT = liquidGlassMorphEnvelope(travelP);
      } else {
        growT = 0.0;
      }

      final glassH =
          layout.cellHeight + (targetGlassH - layout.cellHeight) * growT;
      final glassW =
          layout.pillWidth + (targetGlassW - layout.pillWidth) * growT;
      final pillExtraH = glassH - layout.cellHeight;

      final pillFrac = _tabDragging ? _tabPillFracIndex : _travelPos;

      final staticPillLeft =
          _barLeft + layout.padding + _tabIndexCommitted * cellW;
      final staticBottom = _effBottomMargin + layout.padding;

      // Jelly: width squeezes inward, pill grows a touch taller.
      final tabStretchMag = _dragJelly.stretch.abs().clamp(0.0, 1.2);
      final tabSqueezeW = -layout.pillWidth * 0.18 * tabStretchMag;
      final tabStretchH = layout.pillExtraHeight * 0.18 * tabStretchMag;

      final bool glassOn = _pillGlassVisible;
      final double? hlFrac = glassOn ? pillFrac : null;
      final double? hlW =
          glassOn ? layout.pillWidth + (glassW - layout.pillWidth) + tabSqueezeW : null;
      final double? hlH =
          glassOn ? layout.cellHeight + pillExtraH + tabStretchH : null;

      return Stack(
        fit: StackFit.expand,
        children: [
          // OUTER view: captures the inner stack and composites the
          // moving glass pill + the developer's outer lenses on top.
          LiquidGlassView(
            controller: _outerViewController,
            pixelRatio: widget.pixelRatio,
            useSync: widget.useSync,
            realTimeCapture: true,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            useImpellerBackdrop: widget.useImpellerBackdrop,
            backgroundWidget: _buildInner(
              layout: layout,
              pillFrac: hlFrac,
              pillW: hlW,
              pillH: hlH,
            ),
            children: [
              if (glassOn)
                buildLiquidGlassBottomNavPill(
                  // Constant key: the pill is added to / removed from this
                  // list as it animates. Without a stable key the lenses
                  // are matched by index, so toggling the pill renumbers
                  // the outer lenses and the app bar reuses the pill's
                  // `State` (and its bottom-anchored position) — shifting
                  // it. See `LiquidGlass.key`.
                  key: const ValueKey('lg-nav-morph-pill'),
                  layout: layout,
                  animatedIndex: pillFrac,
                  parentWidth: parentWidth,
                  dx: dx,
                  blur: widget.pillBlur,
                  distortion: widget.pillDistortion,
                  distortionWidth: widget.pillDistortionWidth,
                  magnification: widget.pillMagnification,
                  enableInnerRadiusTransparent:
                      widget.pillEnableInnerRadiusTransparent,
                  extraHeight: pillExtraH + tabStretchH,
                  extraWidth: (glassW - layout.pillWidth) + tabSqueezeW,
                ),
              // Stable, role-based keys so each outer lens keeps its own
              // `State` regardless of whether the pill is currently in the
              // list. The outer-lenses order is invariant (app bar, extra
              // lenses, side action — they never reorder at runtime), so an
              // index-derived key here is stable; only the pill toggles.
              for (int i = 0; i < widget.outerLenses.length; i++)
                widget.outerLenses[i].key != null
                    ? widget.outerLenses[i]
                    : widget.outerLenses[i]
                        .copyWith(key: ValueKey('lg-nav-outer-$i')),
            ],
          ),
          // Static rest pill — only when the glass is NOT on screen.
          if (!_pillGlassActive && !_tabDragging)
            Positioned(
              key: const ValueKey('lg-animated-nav-pill-static'),
              left: staticPillLeft,
              bottom: staticBottom,
              child: LiquidGlassBottomNavPillStatic(
                width: layout.pillWidth,
                height: layout.cellHeight,
              ),
            ),
          // Unified gesture overlay (tap cell + drag pill in one arena).
          Positioned(
            key: const ValueKey('lg-animated-nav-gesture-overlay'),
            left: _barLeft + layout.padding,
            bottom: staticBottom,
            width: layout.width - 2 * layout.padding,
            height: layout.cellHeight,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (instance) => instance.onTapUp = _onTabBarTapUp,
                ),
                HorizontalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                        HorizontalDragGestureRecognizer>(
                  () => HorizontalDragGestureRecognizer(),
                  (instance) => instance
                    ..onStart = _onTabPillDragStart
                    ..onUpdate = _onTabPillDragUpdate
                    ..onEnd = _onTabPillDragEnd
                    ..onCancel = _onTabPillDragCancel,
                ),
              },
            ),
          ),
        ],
      );
    });
  }

  /// Inner stack the outer view captures: wallpaper/body + bar capsule
  /// lens, with the icon shell drawn on top. The shell does the iOS-26
  /// dual-layer "icon highlights through the moving pill" reveal when
  /// [pillFrac]/[pillW]/[pillH] are supplied.
  Widget _buildInner({
    required LiquidGlassBottomNavBarLayout layout,
    double? pillFrac,
    double? pillW,
    double? pillH,
  }) {
    final Widget background = widget.backgroundColor == null
        ? widget.body
        : ColoredBox(color: widget.backgroundColor!, child: widget.body);

    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassView(
          controller: _innerViewController,
          pixelRatio: widget.pixelRatio,
          useSync: widget.useSync,
          realTimeCapture: widget.realTimeCapture,
          refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
          useImpellerBackdrop: widget.useImpellerBackdrop,
          backgroundWidget: background,
          children: [
            buildLiquidGlassBottomNavCapsule(
              layout: layout,
              position: widget.barPosition,
            ),
          ],
        ),
        // Cosmetic only — taps are owned by the outer gesture overlay.
        // Wrapped in a transparent Material so the shell's labels get a
        // DefaultTextStyle (otherwise they render with the debug yellow
        // underline).
        IgnorePointer(
          child: Material(
            type: MaterialType.transparency,
            child: LiquidGlassAnimatedBottomNavBarShell(
              items: widget.items,
              selectedIndex: _tabIndexCommitted,
              onChanged: (_) {},
              layout: layout,
              left: _barLeft,
              bottom: _effBottomMargin,
              highlightFrac: pillFrac,
              highlightWidth: pillW,
              highlightHeight: pillH,
            ),
          ),
        ),
      ],
    );
  }
}
