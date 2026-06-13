import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// NOTE: The example showcase drives the FULL set of components,
// including ones that are intentionally NOT exported from the public
// package barrel — either because their animation work is still in
// progress (bottom-nav/tab-bar animated variants, slider, toggle,
// morph-segmented) or because they are showcase-only demo widgets
// (music player, notification card). App developers should use the
// exported public components instead. The example reaches into
// 'src' directly here; the implementation_imports lint is suppressed
// because this app intentionally depends on package internals.
//
// ignore_for_file: implementation_imports
import 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_bottom_nav_bar.dart'
    show
        LiquidGlassBottomNavBarLayout,
        LiquidGlassBottomNavPillStatic,
        LiquidGlassAnimatedBottomNavBarShell,
        buildLiquidGlassBottomNavCapsule,
        buildLiquidGlassBottomNavPill;
import 'package:liquid_glass_easy/src/widgets/components/slider/liquid_glass_slider.dart';
import 'package:liquid_glass_easy/src/widgets/components/toggle/liquid_glass_toggle.dart';
import 'package:liquid_glass_easy/src/widgets/components/liquid_glass_morph_segmented.dart';
import 'package:liquid_glass_easy/src/widgets/components/liquid_glass_morph_pill.dart'
    show liquidGlassMorphEnvelope;
import 'package:liquid_glass_easy/src/widgets/components/liquid_glass_music_player.dart';
import 'package:liquid_glass_easy/src/widgets/components/liquid_glass_notification_card.dart';

import 'components/control_center_background.dart';
import 'components/control_center_widgets.dart';
import 'components/demo_home_background.dart';
import 'components/demo_wallpapers.dart';
import 'components/photo_background.dart';

/// Standalone entry point that demos the liquid-glass components.
/// Run with:
///
///   flutter run -t lib/showcase.dart
///
/// This file is fully separate from `main.dart` so the existing
/// example continues to work untouched.

void main() {
  runApp(const LiquidGlassShowcaseApp());
}

class LiquidGlassShowcaseApp extends StatelessWidget {
  const LiquidGlassShowcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LiquidGlassShowcasePage(),
    );
  }
}

class LiquidGlassShowcasePage extends StatefulWidget {
  const LiquidGlassShowcasePage({super.key});

  @override
  State<LiquidGlassShowcasePage> createState() =>
      _LiquidGlassShowcasePageState();
}

class _LiquidGlassShowcasePageState extends State<LiquidGlassShowcasePage>
    with TickerProviderStateMixin {
  /// Outer pipeline — snapshots the OS canvas (inner glass output +
  /// page lenses' tracks). Realtime is only enabled while a tab,
  /// slider, or toggle animation is running.
  final _viewController = LiquidGlassViewController();

  /// Inner pipeline — snapshots the wallpaper for the bar capsule
  /// lens. Stays in snapshot mode permanently; we just retake the
  /// snapshot when the page (and therefore the wallpaper) changes.
  final _innerViewController = LiquidGlassViewController();

  /// Component-demo page index.
  int _pageIndex = 0;

  /// Critically-underdamped spring step. Pulls [x] toward [target]
  /// with stiffness [k] and damping [c]. Returns the new (x, vel)
  /// pair. Keep the same constants between drag-pumps and rest so
  /// the system feels continuous.
  ///
  /// `c < 2*sqrt(k)` ⇒ underdamped (overshoots), which is the iOS
  /// feel. `c == 2*sqrt(k)` ⇒ critically damped (no overshoot, just
  /// fast settle). We default to slightly underdamped so the thumb
  /// has a single noticeable bounce on release.
  static (double, double) _springStep({
    required double x,
    required double vel,
    required double target,
    required double dt,
    double stiffness = 280,
    double damping = 18,
  }) {
    // Sub-step long frames to keep the integrator stable.
    var t = dt;
    var px = x;
    var pv = vel;
    while (t > 0) {
      final step = t > 1 / 240.0 ? 1 / 240.0 : t;
      final accel = -stiffness * (px - target) - damping * pv;
      pv += accel * step;
      px += pv * step;
      t -= step;
    }
    return (px, pv);
  }

  // ── Tab bar state ─────────────────────────────────────────────
  int _tabIndex = 0;

  /// Index that the static UI (tab icons in the shell, the static
  /// rest pill) actually shows as selected. Flips to the new value
  /// only AFTER the glass pill animation completes — so during the
  /// travel the shell still highlights the previously-selected tab
  /// and only the glass moves.
  int _tabIndexCommitted = 0;

  late final AnimationController _tabAnim;
  late Animation<double> _tabIndexTween =
      const AlwaysStoppedAnimation<double>(0.0);

  /// True while the glass pill is on screen — either the tab
  /// animation is running, or the user is dragging the pill. The
  /// static rest pill is hidden whenever this is true so the glass
  /// is the ONLY selection indicator visible during the
  /// transition. When the animation completes we flip this off and
  /// commit the tab change in the same setState so the static pill
  /// appears at the new index in the same frame the glass
  /// disappears — the two read as one component handing off.
  bool _pillGlassActive = false;

  /// True while the post-drag settle animation is running. Used
  /// to swap the grow envelope from the bell-shape `sin(π·t)`
  /// (used by tap-to-switch, where the pill grows out of rest and
  /// shrinks back) to a monotonic decay `1 - t` (used after a
  /// drag, where the pill is already at peak size and just needs
  /// to shrink back to rest). Without this, releasing a drag
  /// produced a visible shrink → grow → shrink wobble.
  bool _settlingFromDrag = false;

  /// Fractional pill position rendered in the bar (0..itemCount-1).
  /// Driven by `_tabAnim`/`_tabIndexTween` for tap-to-switch, or by
  /// the user's finger while dragging the pill directly.
  double _tabPillFracIndex = 0;

  /// True while the user is dragging the glass pill.
  bool _tabDragging = false;

  /// Jelly state for the tab pill — signed spring (negative when
  /// dragging right-to-left, positive otherwise) so the pill
  /// stretches in the direction of motion and overshoots on
  /// release like an iOS spring.
  double _tabPillStretch = 0;
  double _tabPillStretchVel = 0;
  double _tabPillJellyLastFrac = 0;
  DateTime _tabPillJellyLastTs = DateTime.now();
  Ticker? _tabPillJellyTicker;
  Duration? _tabPillJellyTickerLast;

  static const _tabLayout = LiquidGlassBottomNavBarLayout(
    itemCount: 3,
    width: 200,
    height: 60,
    bottomMargin: 28,
    padding: 5,
  );

  /// Side-floating search button is the same diameter as the tab
  /// bar's row height so the two read as paired controls at the
  /// same baseline.
  static const double _searchButtonSize = 60;

  static const _tabItems = <LiquidGlassTabBarItem>[
    LiquidGlassTabBarItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: 'Explore',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  // ── Slider state ─────────────────────────────────────────────
  double _sliderValue = 0.4;
  late final AnimationController _sliderAnim;
  bool _sliderDragging = false;

  /// Signed jelly stretch for the slider thumb (-1..1). Negative
  /// = stretched left, positive = stretched right. Driven by a
  /// spring that targets the current drag velocity while held and
  /// snaps to 0 with a single overshoot on release — the iOS feel.
  double _sliderStretch = 0;
  double _sliderStretchVel = 0;

  /// Last known slider value + timestamp, used to compute the raw
  /// signed velocity each `setState` from the drag handler.
  double _sliderJellyLastValue = 0.4;
  DateTime _sliderJellyLastTs = DateTime.now();

  /// Most recent target the spring is pulling toward. Drag pumps
  /// set this to a signed [-1..1] value proportional to drag speed
  /// and direction; release sets it to 0. The per-frame ticker
  /// integrates the spring against this target.
  double _sliderStretchTarget = 0;

  /// Ticker that integrates the spring every frame. Auto-stops
  /// once the spring is at rest after release.
  Ticker? _sliderJellyTicker;
  Duration? _sliderJellyTickerLast;
  static const _sliderLayout = LiquidGlassSliderLayout(
    width: 280,
    trackHeight: 8,
    thumbWidth: 40,
    thumbHeight: 26,
    thumbExtraWidth: 8,
    thumbExtraHeight: 6,
  );

  // ── Toggle state ─────────────────────────────────────────────
  bool _toggleValue = false;
  late final AnimationController _toggleAnim;
  late Animation<double> _toggleFraction =
      const AlwaysStoppedAnimation<double>(0.0);
  static const _toggleLayout = LiquidGlassToggleLayout(
    width: 64,
    height: 32,
    padding: 2.5,
    thumbWidth: 36,
    thumbHeight: 27,
    thumbExtraWidth: 36,
    thumbExtraHeight: 18,
    pinchedHeight: 22,
  );

  // ── Existing demo state ──────────────────────────────────────
  bool _isPlaying = true;
  int _segment = 1;

  // ── Segmented control morph state ────────────────────────────
  late final AnimationController _segAnim;
  late Animation<double> _segIndexTween =
      const AlwaysStoppedAnimation<double>(1.0);
  int _segIndexCommitted = 1;
  bool _segPillGlassActive = false;
  static const _segLayout = LiquidGlassMorphSegmentedLayout(
    itemCount: 3,
    width: 260,
    height: 44,
    padding: 4,
    pillExtraHeight: 16,
  );
  static const double _segTopMargin = 90;
  static const _segItems = <String>['Day', 'Week', 'Month'];

  // ── Control Center state ────────────────────────────────────
  final CcConnectivityState _cc = CcConnectivityState();
  bool _ccPlaying = true;
  bool _ccLockRotation = false;
  bool _ccBell = true;
  double _ccBrightness = 0.55;
  double _ccVolume = 0.65;
  bool _ccTorch = false;
  bool _ccTimer = false;
  bool _ccCalc = false;
  bool _ccCamera = false;

  static const _pageCount = 8;

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _tabIndexTween = AlwaysStoppedAnimation<double>(_tabIndex.toDouble());
    _tabAnim.addListener(() => setState(() {}));
    _tabAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _maybeStopCapture();
        // Defer flipping `_pillGlassActive` off by one frame so the
        // outer view has a chance to paint without the glass pill
        // before the static pill appears. Without this, the static
        // pill briefly overlaps the glass pill on the final frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _pillGlassActive = false;
            _settlingFromDrag = false;
            // Commit the tab change AFTER the glass has finished
            // travelling. Until now the shell was still showing the
            // previously-selected tab, so only the glass moved.
            _tabIndexCommitted = _tabIndex;
          });
        });
        if (mounted) setState(() {});
      }
    });

    _sliderAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _sliderAnim.addListener(() => setState(() {}));
    _sliderAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _maybeStopCapture();
      }
    });

    // Per-frame jelly decay. Started on touch-down, stopped after
    // release once the jelly has relaxed to ~0.
    _sliderJellyTicker = createTicker(_onSliderJellyTick);

    // Same scheme for the tab pill jelly.
    _tabPillJellyTicker = createTicker(_onTabPillJellyTick);

    _toggleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _toggleFraction = AlwaysStoppedAnimation<double>(_toggleValue ? 1 : 0);
    _toggleAnim.addListener(() => setState(() {}));
    _toggleAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _maybeStopCapture();
      }
    });

    // Segmented control morph — same hand-off pattern as the tab
    // bar but without drag. Tap → glass pill grows out of static
    // highlight, slides to the new index, shrinks back into the
    // static highlight at the destination.
    _segAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _segIndexTween = AlwaysStoppedAnimation<double>(_segment.toDouble());
    _segAnim.addListener(() => setState(() {}));
    _segAnim.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _maybeStopCapture();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _segPillGlassActive = false;
            _segIndexCommitted = _segment;
          });
        });
        if (mounted) setState(() {});
      }
    });

    // Initial snapshot for both pipelines once layout is settled.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshSnapshots();
    });
  }

  @override
  void dispose() {
    _tabAnim.dispose();
    _sliderAnim.dispose();
    _toggleAnim.dispose();
    _segAnim.dispose();
    _sliderJellyTicker?.dispose();
    _tabPillJellyTicker?.dispose();
    super.dispose();
  }

  /// Wakes the inner pipeline so the bar capsule has live frames to
  /// refract against during a morph. Call this on the *first frame*
  /// of an animation; pair with [_maybeStopCapture] on completion.
  void _startCapture() => _innerViewController.startRealtimeCapture();

  /// Stops the inner pipeline once nothing is animating anymore. The
  /// last captured frame stays available for the at-rest bar
  /// capsule, so it remains visible without burning per-frame work.
  void _maybeStopCapture() {
    if (!_tabAnim.isAnimating &&
        !_sliderAnim.isAnimating &&
        !_sliderDragging &&
        !_toggleAnim.isAnimating &&
        !_segAnim.isAnimating) {
      _innerViewController.stopRealtimeCapture();
    }
  }

  /// Re-capture the inner pipeline (wallpaper + bar capsule). Used
  /// on first frame and after every page change so the at-rest bar
  /// capsule has a fresh wallpaper to refract. The outer view runs
  /// realtime, so it doesn't need an explicit recapture here.
  Future<void> _refreshSnapshots() async {
    await _innerViewController.captureOnce();
    if (mounted) setState(() {});
  }

  // ── Tab bar handler ──────────────────────────────────────────
  void _onTabChanged(int next) {
    if (next == _tabIndex) return;
    final from = _tabIndexTween.value;
    setState(() {
      _tabIndex = next;
      _pillGlassActive = true;
      _tabIndexTween = Tween<double>(begin: from, end: next.toDouble())
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(_tabAnim);
    });
    _startCapture();
    // Tap-to-switch always uses the full bell-envelope duration
    // (set in initState). Restore it in case the previous run was
    // a settle-from-drag with the shortened duration.
    _tabAnim
      ..duration = const Duration(milliseconds: 320)
      ..reset()
      ..forward();
  }

  // ── Tab pill drag handlers ───────────────────────────────────
  /// Convert a global drag x-coordinate into a fractional tab index
  /// using the bar's current screen geometry.
  double _xToTabFrac(double globalDx) {
    final barLeft = (_screenWidth - _tabLayout.width) / 2 +
        _tabLayout.padding +
        _tabLayout.cellWidth / 2; // center of cell 0
    final cellW = _tabLayout.cellWidth;
    final raw = (globalDx - barLeft) / cellW;
    return raw.clamp(0.0, (_tabLayout.itemCount - 1).toDouble());
  }

  /// Tap-up on the unified tab bar gesture overlay. Routes through
  /// the same `_onTabChanged` path the old `InkWell`s used.
  void _onTabBarTapUp(TapUpDetails d) {
    // Overlay starts at `barLeft + padding`, so cell 0 begins at
    // `localPosition.dx == 0`. Snap to nearest integer index.
    final cellW = _tabLayout.cellWidth;
    final raw = d.localPosition.dx / cellW;
    final idx =
        raw.floor().clamp(0, _tabLayout.itemCount - 1);
    _onTabChanged(idx);
  }

  void _onTabPillDragStart(DragStartDetails d) {
    _tabDragging = true;
    _pillGlassActive = true;
    _startCapture();
    // Snap the pill to wherever the finger is.
    final frac = _xToTabFrac(d.globalPosition.dx);
    _tabPillJellyLastFrac = frac;
    _tabPillJellyLastTs = DateTime.now();
    _tabPillStretch = 0;
    _tabPillStretchVel = 0;
    _tabPillStretchTarget = 0;
    _tabPillJellyTickerLast = null;
    // Idempotent: a previous drag could have left the ticker
    // running (e.g. if it was cancelled mid-flight). Calling
    // `.start()` on an already-active ticker asserts.
    if (_tabPillJellyTicker?.isActive != true) {
      _tabPillJellyTicker?.start();
    }
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillDragUpdate(DragUpdateDetails d) {
    if (!_tabDragging) return;
    final frac = _xToTabFrac(d.globalPosition.dx);
    _pumpTabPillJelly(frac);
    setState(() => _tabPillFracIndex = frac);
  }

  void _onTabPillDragEnd(DragEndDetails d) {
    _releaseTabPillDrag();
  }

  /// Called when the gesture arena cancels the drag (e.g. another
  /// recognizer wins the pointer, the route is popped, a second
  /// pointer lands). Without this, `_tabDragging` would stay `true`
  /// indefinitely, the static rest pill would never reappear, and
  /// the glass pill would look frozen mid-travel — the "stuck"
  /// behaviour we used to see.
  void _onTabPillDragCancel() {
    if (!_tabDragging) return;
    _releaseTabPillDrag();
  }

  /// Shared release path for both natural end and arena cancel.
  /// Snaps the pill to the nearest integer index using the same
  /// settle animation regardless of how the drag terminated.
  void _releaseTabPillDrag() {
    final from = _tabPillFracIndex;
    final next = from.round().clamp(0, _tabLayout.itemCount - 1);
    setState(() {
      _tabDragging = false;
      _settlingFromDrag = true;
      _tabIndex = next;
      _pillGlassActive = true;
      _tabIndexTween = Tween<double>(begin: from, end: next.toDouble())
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(_tabAnim);
    });
    // Settle-from-drag uses a SHORT duration so the shrink + snap
    // finish together and the static pill takes over right after
    // the shrink completes — no perceptible pause. Tap-to-switch
    // restores the longer duration in `_onTabChanged`.
    _tabAnim
      ..duration = const Duration(milliseconds: 140)
      ..reset()
      ..forward();
  }

  /// Compute a signed [-1..1] target from drag delta and feed it
  /// to the tab pill spring. Same scheme as the slider.
  double _tabPillStretchTarget = 0;
  void _pumpTabPillJelly(double newFrac) {
    final now = DateTime.now();
    final dt = now.difference(_tabPillJellyLastTs).inMicroseconds / 1e6;
    if (dt > 0) {
      const kMaxVelocity = 8.0; // index-units per second at peak.
      final signedVel =
          ((newFrac - _tabPillJellyLastFrac) / dt).clamp(-60.0, 60.0);
      _tabPillStretchTarget = (signedVel / kMaxVelocity).clamp(-1.0, 1.0);
    }
    _tabPillJellyLastFrac = newFrac;
    _tabPillJellyLastTs = now;
  }

  void _onTabPillJellyTick(Duration elapsed) {
    final last = _tabPillJellyTickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _tabPillJellyTickerLast = elapsed;

    if (_tabDragging) {
      final timeSincePump = DateTime.now()
              .difference(_tabPillJellyLastTs)
              .inMicroseconds /
          1e6;
      if (timeSincePump > 0.032) {
        const targetTau = 0.08;
        final targetAlpha = 1 - math.exp(-dt / targetTau);
        _tabPillStretchTarget *= (1 - targetAlpha);
      }
    } else {
      _tabPillStretchTarget = 0;
    }

    final result = _springStep(
      x: _tabPillStretch,
      vel: _tabPillStretchVel,
      target: _tabPillStretchTarget,
      dt: dt,
      stiffness: 320,
      damping: 22,
    );
    _tabPillStretch = result.$1;
    _tabPillStretchVel = result.$2;

    if (!_tabDragging &&
        _tabPillStretch.abs() < 0.005 &&
        _tabPillStretchVel.abs() < 0.05 &&
        _tabPillStretchTarget.abs() < 0.005) {
      _tabPillStretch = 0;
      _tabPillStretchVel = 0;
      _tabPillStretchTarget = 0;
      _tabPillJellyTicker?.stop();
    }
    if (mounted) setState(() {});
  }

  // ── Slider handlers ─────────────────────────────────────────
  void _onSliderStart(double v) {
    _sliderDragging = true;
    _startCapture();
    _sliderAnim
      ..stop()
      ..forward(from: _sliderAnim.value);
    _sliderStretch = 0;
    _sliderStretchVel = 0;
    _sliderStretchTarget = 0;
    _sliderJellyLastValue = _sliderValue;
    _sliderJellyLastTs = DateTime.now();
    _sliderJellyTickerLast = null;
    _sliderJellyTicker?.start();
  }

  void _onSliderEnd(double v) {
    _sliderDragging = false;
    _sliderAnim.reverse(from: _sliderAnim.value);
    // Aim the spring back to zero — its current velocity carries
    // the overshoot. Ticker keeps running until the spring rests.
    _sliderStretchTarget = 0;
  }

  /// Compute a signed [-1..1] target from the user's most recent
  /// drag delta and feed it to the spring. Negative = thumb moved
  /// left, positive = right. Larger magnitude = faster drag.
  void _pumpSliderJelly(double newValue) {
    final now = DateTime.now();
    final dt = now.difference(_sliderJellyLastTs).inMicroseconds / 1e6;
    if (dt > 0) {
      const kMaxVelocity = 1.5; // value-units per second at peak.
      final signedVel =
          ((newValue - _sliderJellyLastValue) / dt).clamp(-12.0, 12.0);
      // Map to [-1..1] and clamp.
      final newTarget = (signedVel / kMaxVelocity).clamp(-1.0, 1.0);
      _sliderStretchTarget = newTarget;
    }
    _sliderJellyLastValue = newValue;
    _sliderJellyLastTs = now;
  }

  /// Per-frame spring integration for the slider thumb stretch.
  /// While dragging, the target is what `_pumpSliderJelly` last
  /// wrote. While not dragging, the target is 0; the spring's
  /// momentum carries it past zero once and back, giving a single
  /// soft overshoot — the iOS feel.
  void _onSliderJellyTick(Duration elapsed) {
    final last = _sliderJellyTickerLast ?? elapsed;
    final dt = (elapsed - last).inMicroseconds / 1e6;
    _sliderJellyTickerLast = elapsed;

    // While dragging, decay the target toward 0 if no recent pump
    // arrived — keeps the stretch from sticking when the user
    // pauses mid-drag.
    if (_sliderDragging) {
      final timeSincePump = DateTime.now()
              .difference(_sliderJellyLastTs)
              .inMicroseconds /
          1e6;
      if (timeSincePump > 0.032) {
        const targetTau = 0.08;
        final targetAlpha = 1 - math.exp(-dt / targetTau);
        _sliderStretchTarget *= (1 - targetAlpha);
      }
    } else {
      _sliderStretchTarget = 0;
    }

    final result = _springStep(
      x: _sliderStretch,
      vel: _sliderStretchVel,
      target: _sliderStretchTarget,
      dt: dt,
      // Slightly underdamped: a single visible overshoot on
      // release, then settle. Tuned for ~250ms ring-down.
      stiffness: 320,
      damping: 22,
    );
    _sliderStretch = result.$1;
    _sliderStretchVel = result.$2;

    if (!_sliderDragging &&
        _sliderStretch.abs() < 0.005 &&
        _sliderStretchVel.abs() < 0.05 &&
        _sliderStretchTarget.abs() < 0.005) {
      _sliderStretch = 0;
      _sliderStretchVel = 0;
      _sliderStretchTarget = 0;
      _sliderJellyTicker?.stop();
    }
    if (mounted) setState(() {});
  }

  // ── Toggle handler ──────────────────────────────────────────
  void _onToggleChanged(bool next) {
    if (next == _toggleValue) return;
    final from = _toggleFraction.value;
    setState(() {
      _toggleValue = next;
      _toggleFraction = Tween<double>(begin: from, end: next ? 1.0 : 0.0)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(_toggleAnim);
    });
    _startCapture();
    _toggleAnim
      ..reset()
      ..forward();
  }

  // ── Segmented control handler ───────────────────────────────
  /// Tap-to-switch for the segmented control. Mirrors the tab bar
  /// hand-off: we flip `_segPillGlassActive=true` immediately so
  /// the static rest pill at the source disappears and the moving
  /// glass pill takes over, then commit the new index after the
  /// animation completes (post-frame) so the static rest pill
  /// reappears at the destination.
  void _onSegChanged(int next) {
    if (next == _segment) return;
    final from = _segIndexTween.value;
    setState(() {
      _segment = next;
      _segPillGlassActive = true;
      _segIndexTween = Tween<double>(begin: from, end: next.toDouble())
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(_segAnim);
    });
    _startCapture();
    _segAnim
      ..reset()
      ..forward();
  }

  String _titleForPage(int i) {
    switch (i) {
      case 0:
        return 'Search & Buttons';
      case 1:
        return 'Now Playing';
      case 2:
        return 'Control Center';
      case 3:
        return 'Dock';
      case 4:
        return 'Notifications';
      case 5:
        return 'Segmented Control';
      case 6:
        return 'Tab Bar';
      case 7:
        return 'Slider & Toggle';
    }
    return '';
  }

  /// Build the layered "OS" canvas that the OUTER LiquidGlassView
  /// captures. Inner LiquidGlassView paints the wallpaper + bar
  /// capsule lens; the icon row is drawn on top.
  ///
  /// [pillFrac], [pillW], [pillH] are forwarded to the bottom nav
  /// shell so it can do the iOS-26 dual-layer "icon highlights
  /// through the pill" rendering. Pass `null` when the glass pill
  /// isn't on screen — the shell falls back to highlighting only
  /// the committed index.
  Widget _buildBackground({
    double? pillFrac,
    double? pillW,
    double? pillH,
  }) {
    final wallpaper = kDemoWallpapers[_pageIndex % kDemoWallpapers.length];
    // Page-specific background overrides:
    //   • page 2 (Control Center) — pre-blurred photo.
    //   • page 4 (Notifications) — Mt. Fuji photo so the
    //     notification cards refract a real, varied image
    //     instead of a flat gradient.
    final Widget homeBackground;
    if (_pageIndex == 2) {
      homeBackground = const ControlCenterBackground();
    } else if (_pageIndex == 4) {
      homeBackground = const PhotoBackground(
        imageUrl:
            'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/mountain.jpg',
        scrimAlpha: 60,
      );
    } else {
      homeBackground = DemoHomeBackground(
        wallpaper: wallpaper,
        time: '9:41',
        batteryPercent: 86,
      );
    }
    // The bottom nav bar is the demo on page 6. Hide it
    // everywhere else so each page only shows the components it's
    // meant to demonstrate.
    final bool showTabBar = _pageIndex == 6;
    // Segmented control morph lives on page 5. Inner pipeline
    // captures the capsule lens only — the labels shell is
    // overlaid in the outer Stack so the text stays crisp.
    final bool showSegmented = _pageIndex == 5;
    return Stack(
      fit: StackFit.expand,
      children: [
        // INNER liquid-glass view: wallpaper + bar capsule lens.
        // Snapshot-only at rest. The bar capsule itself doesn't
        // move, so a single capture per page is enough; we briefly
        // re-enable realtime during morph animations so any motion
        // baked into the wallpaper still shows through.
        LiquidGlassView(
          controller: _innerViewController,
          backgroundWidget: homeBackground,
          pixelRatio: 1,
          useSync: true,
          realTimeCapture: false,
          refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
          children: [
            if (showTabBar)
              buildLiquidGlassBottomNavCapsule(layout: _tabLayout),
            if (showSegmented)
              buildLiquidGlassMorphSegmentedCapsule(
                layout: _segLayout,
                topMargin: _segTopMargin,
              ),
          ],
        ),
        if (showTabBar)
          IgnorePointer(
            // Shell is purely cosmetic now — its taps and any drag
            // arena conflicts are owned by the unified gesture overlay
            // built later (search for `RawGestureDetector` over the
            // tab bar). Keeping `Material`/`InkWell` here would race
            // with the overlay's HorizontalDragGestureRecognizer
            // across two widget subtrees, which is exactly what made
            // "press-then-drag" feel stuck.
            child: LiquidGlassAnimatedBottomNavBarShell(
              items: _tabItems,
              // Show the COMMITTED selection — the icon for the new
              // index lights up only after the glass pill finishes
              // travelling, not at the moment of tap.
              selectedIndex: _tabIndexCommitted,
              onChanged: _onTabChanged,
              layout: _tabLayout,
              // iOS-26 dual-layer highlight: parts of any icon
              // currently UNDER the moving glass pill render in
              // their selected state, parts outside stay
              // unselected. Only feed in highlight params while
              // the glass pill is on screen, otherwise the static
              // selectedIndex path takes over.
              highlightFrac: pillFrac,
              highlightWidth: pillW,
              highlightHeight: pillH,
            ),
          ),
        // The page-specific demo tracks (slider/toggle) live in the
        // background snapshot too — see _backgroundDemos.
        ..._backgroundDemos(),
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 36),
              child: Text(
                _titleForPage(_pageIndex),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Per-page widgets that need to be IN the background snapshot
  /// (so a glass lens sitting above them can refract).
  List<Widget> _backgroundDemos() {
    switch (_pageIndex) {
      case 7:
        // Slider track + toggle track baked into the snapshot. The
        // glass thumbs sit above them as outer-view lenses.
        return [
          // Slider — centered horizontally a bit above middle.
          Positioned(
            left: _sliderTrackLeftFromLeft,
            top: _sliderTrackTopFromTop,
            child: LiquidGlassSliderTrack(
              value: _sliderValue,
              onChanged: (v) {
                setState(() => _sliderValue = v);
                _pumpSliderJelly(v);
              },
              onChangeStart: _onSliderStart,
              onChangeEnd: _onSliderEnd,
              showRestThumb: !_sliderDragging && !_sliderAnim.isAnimating,
              layout: _sliderLayout,
            ),
          ),
          // Toggle below the slider.
          Positioned(
            left: _toggleTrackLeftFromLeft,
            top: _toggleTrackTopFromTop,
            child: LiquidGlassToggleTrack(
              value: _toggleValue,
              onChanged: _onToggleChanged,
              layout: _toggleLayout,
              showRestThumb: !_toggleAnim.isAnimating,
              // Same sin(π·t) envelope as the glass thumb so the
              // hole + fake mini pill appear behind the glass and
              // close back when the glass is gone.
              pinchFraction: math.sin(math.pi * _toggleAnim.value),
              // Travel fraction so the cut-out + fake pill follow
              // the glass thumb's slide.
              travelFraction: _toggleFraction.value,
            ),
          ),
        ];
    }
    return const [];
  }

  // Slider/toggle position helpers — computed once per build via
  // LayoutBuilder in build(). We cache the screen height for the
  // bottom-from-bottom math the lens needs.
  double _screenWidth = 0;
  double _screenHeight = 0;

  double get _sliderTrackLeftFromLeft =>
      (_screenWidth - _sliderLayout.width) / 2;
  double get _sliderTrackTopFromTop => _screenHeight * 0.42;
  double get _sliderTrackBottomFromBottom =>
      _screenHeight -
      _sliderTrackTopFromTop -
      // The slider widget's outer SizedBox is thumbHeight tall (it
      // reserves vertical room for the thumb to overflow the track).
      // Match that here so the glass thumb's bottom-anchor lines up
      // with the rest thumb.
      _sliderLayout.thumbHeight;

  double get _toggleTrackLeftFromLeft =>
      (_screenWidth - _toggleLayout.width) / 2;
  double get _toggleTrackTopFromTop => _screenHeight * 0.55;
  double get _toggleTrackBottomFromBottom =>
      _screenHeight -
      _toggleTrackTopFromTop -
      _toggleLayout.height;

  // ── Control Center page layout ─────────────────────────────
  //
  // The page is laid out as a two-column grid using a fixed gutter
  // and a uniform card width so all four "rows" (connectivity +
  // now-playing, round tiles + vertical sliders, focus pill +
  // vertical sliders, bottom-row round tiles) line up nicely.
  static const double _ccPagePadding = 18;
  static const double _ccGutter = 14;
  static const double _ccTopOffset = 130;

  double get _ccCardWidth =>
      (_screenWidth - _ccPagePadding * 2 - _ccGutter) / 2;
  static const double _ccTopCardHeight = 196;
  // Round tiles in the middle column (lock-rotation, bell).
  static const double _ccRoundTileSize = 64;
  static const double _ccVerticalSliderWidth = 72;
  static const double _ccVerticalSliderHeight = 170;
  static const double _ccFocusPillHeight = 64;
  static const double _ccBottomTileSize = 70;

  double get _ccTopRowTop => _ccTopOffset;
  double get _ccConnectivityLeft => _ccPagePadding;
  double get _ccNowPlayingLeft =>
      _ccPagePadding + _ccCardWidth + _ccGutter;

  // Middle row — round tiles aligned to the left card column.
  double get _ccMiddleRowTop =>
      _ccTopRowTop + _ccTopCardHeight + _ccGutter;
  // Two round tiles split the LEFT card column with the same
  // gutter as the outer grid.
  double get _ccLeftRoundTileLeft =>
      _ccConnectivityLeft + (_ccCardWidth - _ccRoundTileSize * 2 - _ccGutter) / 2;
  double get _ccRightRoundTileLeft =>
      _ccLeftRoundTileLeft + _ccRoundTileSize + _ccGutter;

  // Vertical sliders share the right column. Each is centered on
  // half of the right column.
  double get _ccVerticalSliderTop => _ccMiddleRowTop;
  double get _ccBrightnessLeft =>
      _ccNowPlayingLeft +
      (_ccCardWidth / 2 - _ccVerticalSliderWidth) / 2;
  double get _ccVolumeLeft =>
      _ccNowPlayingLeft +
      _ccCardWidth / 2 +
      (_ccCardWidth / 2 - _ccVerticalSliderWidth) / 2;

  // Focus pill sits below the round tiles, spans the full left
  // card column width.
  double get _ccFocusPillTop =>
      _ccMiddleRowTop + _ccRoundTileSize + _ccGutter;
  double get _ccFocusPillLeft => _ccConnectivityLeft;
  double get _ccFocusPillWidth => _ccCardWidth;

  // Bottom row — four round tiles spanning the full grid width.
  double get _ccBottomRowTop =>
      _ccTopRowTop +
      _ccTopCardHeight +
      _ccGutter +
      _ccVerticalSliderHeight +
      _ccGutter;
  double _ccBottomTileLeft(int index) {
    final spacing =
        (_screenWidth - _ccPagePadding * 2 - _ccBottomTileSize * 4) / 3;
    return _ccPagePadding +
        index * (_ccBottomTileSize + spacing);
  }

  /// Lenses specific to the current demo page.
  List<LiquidGlass> _pageLenses(int i) {
    switch (i) {
      case 0:
        return [
          LiquidGlassSearchBar(
            position: const LiquidGlassAlignPosition(
              alignment: Alignment.topCenter,
              margin: EdgeInsets.only(top: 90),
            ),
            placeholder: 'Search apps and content',
            onTap: () {},
          ),
          LiquidGlassButton(
            position: const LiquidGlassAlignPosition(
              alignment: Alignment.center,
              margin: EdgeInsets.only(bottom: 60),
            ),
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            tint: const Color(0xFF007AFF),
            onPressed: () {},
          ),
          LiquidGlassButton(
            position: const LiquidGlassAlignPosition(
              alignment: Alignment.center,
              margin: EdgeInsets.only(top: 60),
            ),
            label: 'Cancel',
            onPressed: () {},
          ),
        ];

      case 1:
        return [
          LiquidGlassMusicPlayer(
            position: const LiquidGlassAlignPosition(
              alignment: Alignment.center,
            ),
            track: 'Midnight City',
            artist: 'M83',
            isPlaying: _isPlaying,
            onPlayPause: () => setState(() => _isPlaying = !_isPlaying),
          ),
        ];

      case 2:
        return [
          // Top-left — connectivity grid card.
          LiquidGlassConnectivityCard(
            position: LiquidGlassOffsetPosition(
              left: _ccConnectivityLeft,
              top: _ccTopRowTop,
            ),
            width: _ccCardWidth,
            height: _ccTopCardHeight,
            state: _cc,
            onToggleAirplane: () =>
                setState(() => _cc.airplane = !_cc.airplane),
            onToggleAirdrop: () =>
                setState(() => _cc.airdrop = !_cc.airdrop),
            onToggleWifi: () => setState(() => _cc.wifi = !_cc.wifi),
            onToggleBluetooth: () =>
                setState(() => _cc.bluetooth = !_cc.bluetooth),
            onToggleCellular: () =>
                setState(() => _cc.cellular = !_cc.cellular),
            onToggleData: () => setState(() => _cc.data = !_cc.data),
          ),
          // Top-right — now-playing card.
          LiquidGlassNowPlayingCard(
            position: LiquidGlassOffsetPosition(
              left: _ccNowPlayingLeft,
              top: _ccTopRowTop,
            ),
            width: _ccCardWidth,
            height: _ccTopCardHeight,
            track: 'Backseat Driver',
            artist: 'Kane Brown',
            isPlaying: _ccPlaying,
            onPlayPause: () => setState(() => _ccPlaying = !_ccPlaying),
          ),
          // Middle-left — lock rotation tile.
          LiquidGlassRoundTile(
            position: LiquidGlassOffsetPosition(
              left: _ccLeftRoundTileLeft,
              top: _ccMiddleRowTop,
            ),
            size: _ccRoundTileSize,
            icon: Icons.screen_lock_rotation_rounded,
            active: _ccLockRotation,
            activeColor: const Color(0xFFFF3B30),
            onTap: () =>
                setState(() => _ccLockRotation = !_ccLockRotation),
          ),
          // Middle-left — bell / silence tile.
          LiquidGlassRoundTile(
            position: LiquidGlassOffsetPosition(
              left: _ccRightRoundTileLeft,
              top: _ccMiddleRowTop,
            ),
            size: _ccRoundTileSize,
            icon: _ccBell
                ? Icons.notifications_rounded
                : Icons.notifications_off_rounded,
            active: !_ccBell,
            activeColor: const Color(0xFFFF9500),
            onTap: () => setState(() => _ccBell = !_ccBell),
          ),
          // Brightness — vertical slider lens.
          buildVerticalSliderLens(
            left: _ccBrightnessLeft,
            top: _ccVerticalSliderTop,
            width: _ccVerticalSliderWidth,
            height: _ccVerticalSliderHeight,
            value: _ccBrightness,
            onChanged: (v) => setState(() => _ccBrightness = v),
          ),
          // Volume — vertical slider lens.
          buildVerticalSliderLens(
            left: _ccVolumeLeft,
            top: _ccVerticalSliderTop,
            width: _ccVerticalSliderWidth,
            height: _ccVerticalSliderHeight,
            value: _ccVolume,
            onChanged: (v) => setState(() => _ccVolume = v),
          ),
          // Focus pill, sits below the round tiles.
          LiquidGlassFocusPill(
            position: LiquidGlassOffsetPosition(
              left: _ccFocusPillLeft,
              top: _ccFocusPillTop,
            ),
            width: _ccFocusPillWidth,
            height: _ccFocusPillHeight,
            onTap: () {},
          ),
          // Bottom row — four round tiles.
          LiquidGlassRoundTile(
            position: LiquidGlassOffsetPosition(
              left: _ccBottomTileLeft(0),
              top: _ccBottomRowTop,
            ),
            size: _ccBottomTileSize,
            icon: Icons.flashlight_on_rounded,
            active: _ccTorch,
            activeColor: const Color(0xFFFFCC00),
            onTap: () => setState(() => _ccTorch = !_ccTorch),
          ),
          LiquidGlassRoundTile(
            position: LiquidGlassOffsetPosition(
              left: _ccBottomTileLeft(1),
              top: _ccBottomRowTop,
            ),
            size: _ccBottomTileSize,
            icon: Icons.timer_rounded,
            active: _ccTimer,
            activeColor: const Color(0xFFFFCC00),
            onTap: () => setState(() => _ccTimer = !_ccTimer),
          ),
          LiquidGlassRoundTile(
            position: LiquidGlassOffsetPosition(
              left: _ccBottomTileLeft(2),
              top: _ccBottomRowTop,
            ),
            size: _ccBottomTileSize,
            icon: Icons.calculate_rounded,
            active: _ccCalc,
            activeColor: const Color(0xFFFF9500),
            onTap: () => setState(() => _ccCalc = !_ccCalc),
          ),
          LiquidGlassRoundTile(
            position: LiquidGlassOffsetPosition(
              left: _ccBottomTileLeft(3),
              top: _ccBottomRowTop,
            ),
            size: _ccBottomTileSize,
            icon: Icons.photo_camera_rounded,
            active: _ccCamera,
            activeColor: const Color(0xFFFFCC00),
            onTap: () => setState(() => _ccCamera = !_ccCamera),
          ),
        ];

      case 99:
        // Old control-tile demo, no longer used. Kept as a guard
        // case so a stray index lookup falls through to [].

      case 3:
        return [
          LiquidGlassDock(
            position: const LiquidGlassAlignPosition(
              alignment: Alignment.center,
            ),
            apps: const [
              LiquidGlassDockApp(
                icon: Icons.phone_rounded,
                gradient: [Color(0xFF34D158), Color(0xFF1AA13E)],
              ),
              LiquidGlassDockApp(
                icon: Icons.message_rounded,
                gradient: [Color(0xFF6FE36F), Color(0xFF1AA13E)],
              ),
              LiquidGlassDockApp(
                icon: Icons.email_rounded,
                gradient: [Color(0xFF4FB3FF), Color(0xFF1E69DE)],
              ),
              LiquidGlassDockApp(
                icon: Icons.music_note_rounded,
                gradient: [Color(0xFFFF6B6B), Color(0xFFB23BFF)],
              ),
            ],
          ),
        ];

      case 4:
        return [
          // Two notification cards stacked one below the other near
          // the top of the screen.
          LiquidGlassNotificationCard(
            position: const LiquidGlassAlignPosition(
              alignment: Alignment.topCenter,
              margin: EdgeInsets.only(top: 90),
            ),
            appName: 'Messages',
            title: 'Sara',
            body: 'Heading out, see you in 10 minutes!',
            appIcon: Icons.message_rounded,
            appIconColor: const Color(0xFF34C759),
            time: '2 min ago',
          ),
          LiquidGlassNotificationCard(
            // 90 (first card top) + 92 (card height) + 14 (gap).
            position: const LiquidGlassAlignPosition(
              alignment: Alignment.topCenter,
              margin: EdgeInsets.only(top: 196),
            ),
            appName: 'Calendar',
            title: 'Standup at 10:00',
            body: 'Daily team sync — Conference Room A.',
            appIcon: Icons.calendar_today_rounded,
            appIconColor: const Color(0xFFFF3B30),
            time: 'in 5 min',
          ),
          // ── iOS lock-screen corner buttons ────────────────
          // Flashlight bottom-left, camera bottom-right.
          _buildLockScreenButton(
            icon: Icons.flashlight_on_rounded,
            alignment: Alignment.bottomLeft,
            margin: const EdgeInsets.only(left: 32, bottom: 48),
          ),
          _buildLockScreenButton(
            icon: Icons.photo_camera_rounded,
            alignment: Alignment.bottomRight,
            margin: const EdgeInsets.only(right: 32, bottom: 48),
          ),
        ];

      case 5:
        // Segmented control's labels + capsule lens live in the
        // inner pipeline; the moving glass pill is appended in
        // build() to the OUTER view's children. So nothing here.
        return const [];

      case 6:
      case 7:
        return const [];
    }
    return const [];
  }

  /// Builds a circular liquid-glass lock-screen button (flashlight /
  /// camera) anchored to a screen corner. Returns a [LiquidGlass]
  /// lens so it composites in the page's outer view like the other
  /// demo lenses.
  LiquidGlass _buildLockScreenButton({
    required IconData icon,
    required Alignment alignment,
    required EdgeInsets margin,
    double size = 56,
  }) {
    return LiquidGlass(
      geometry: LiquidGlassGeometry(
        position: LiquidGlassAlignPosition(
          alignment: alignment,
          margin: margin,
        ),
        width: size,
        height: size,
        shape: RoundedRectangleShape(
          cornerRadius: size / 2,
          borderWidth: 1.2,
          lightIntensity: 1.1,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.2,
            ambientIntensity: 1.0,
            borderSolidity: 0.35,
          ),
        ),
      ),
      refraction: const LiquidGlassRefraction(
        magnification: 1,
        distortion: 0.07,
        distortionWidth: 28,
        chromaticAberration: 0.002,
      ),
      appearance: LiquidGlassAppearance(
        color: Colors.black.withAlpha(60),
        blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: size * 0.42),
      ),
    );
  }

  void _next() {
    setState(() => _pageIndex = (_pageIndex + 1) % _pageCount);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSnapshots());
  }

  void _prev() {
    setState(
        () => _pageIndex = (_pageIndex + _pageCount - 1) % _pageCount);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshSnapshots());
  }

  bool get _pillAnimating => _tabAnim.isAnimating;

  /// True whenever the GLASS pill should be on screen — either the
  /// tap animation is running, or the user is dragging it.
  bool get _pillGlassVisible => _pillAnimating || _tabDragging;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final parentWidth = constraints.maxWidth;
        _screenWidth = constraints.maxWidth;
        _screenHeight = constraints.maxHeight;

        // Tab pill layout.
        final t = _tabAnim.value.clamp(0.0, 1.0);
        final cellW = _tabLayout.cellWidth;

        // Glass pill geometry: same w:h ratio as the static rest
        // pill, scaled up so the glass is slightly bigger than the
        // entire tab bar height.
        const glassOverflowPx = 16.0;
        final restRatio = _tabLayout.pillWidth / _tabLayout.cellHeight;
        final targetGlassH = _tabLayout.height + glassOverflowPx;
        final targetGlassW = targetGlassH * restRatio;

        // Morph-grow envelope. Three modes:
        //   - Dragging: hold pill at peak (1.0).
        //   - Tap-to-switch: original bell shape `sin(π·t)` so the
        //     pill grows out of rest, peaks mid-travel, and shrinks
        //     back at the destination. Unchanged from the original.
        //   - Settling from a drag: monotonic decay across the
        //     entire (already shortened) settle controller so the
        //     pill shrinks while it slides to the snapped index,
        //     and the static pill takes over the instant the
        //     animation completes — no perceptible post-shrink
        //     pause.
        final double growT;
        if (_tabDragging) {
          growT = 1.0;
        } else if (_settlingFromDrag) {
          growT = (1.0 - t).clamp(0.0, 1.0);
        } else {
          growT = liquidGlassMorphEnvelope(t);
        }

        // Lerp from the static pill geometry up to the target glass
        // geometry as the morph plays out.
        final glassH = _tabLayout.cellHeight +
            (targetGlassH - _tabLayout.cellHeight) * growT;
        final glassW = _tabLayout.pillWidth +
            (targetGlassW - _tabLayout.pillWidth) * growT;
        final pillExtraH = glassH - _tabLayout.cellHeight;
        final pillExtraW = glassW - _tabLayout.pillWidth;

        // While dragging, the pill follows the finger directly via
        // `_tabPillFracIndex`. Otherwise the easeOutCubic tween
        // drives it for tap-to-switch.
        final pillFrac =
            _tabDragging ? _tabPillFracIndex : _tabIndexTween.value;
        // Static rest pill sits at the COMMITTED index. It is
        // ONLY visible at rest — while the glass is on screen
        // (animating or being dragged) the glass is the single
        // selection indicator. The two are designed to read as one
        // component handing off: glass appears → static
        // disappears, glass finishes → static reappears at the
        // new index in the same frame.
        final staticPillLeft = (parentWidth - _tabLayout.width) / 2 +
            _tabLayout.padding +
            _tabIndexCommitted * cellW;
        final staticBottom =
            _tabLayout.bottomMargin + _tabLayout.padding;

        // Tab pill jelly — signed spring.
        // `_tabPillStretch` is in [-1..1]: sign = direction, mag =
        // intensity. Width SQUEEZES inward and the pill grows a
        // touch TALLER while loaded — same "vertical jelly bead"
        // shape the slider thumb uses. Two tuning knobs:
        //   - 0.18  → how much the pill narrows at peak drag
        //   - 0.18  → how much taller it gets at peak drag
        // Lower either to soften the deformation.
        final tabStretchMag = _tabPillStretch.abs().clamp(0.0, 1.2);
        final tabSqueezeW = -_tabLayout.pillWidth * 0.18 * tabStretchMag;
        final tabStretchH =
            _tabLayout.pillExtraHeight * 0.18 * tabStretchMag;

        // Slider thumb grow — _sliderAnim ramps from 0 → 1 on
        // touch-down and stays there for the whole drag, then
        // reverses to 0 on release. The grown glass pill mirrors
        // that envelope directly (no sin() — that would collapse
        // the bulge mid-drag).
        final sliderGrow = _sliderAnim.value;

        // Toggle thumb grow — sin() envelope so the glass pill
        // grows out of the rest pill, peaks mid-slide, then shrinks
        // back to the rest size at the destination.
        final toggleGrow = math.sin(math.pi * _toggleAnim.value);

        return Stack(
          children: [
            LiquidGlassView(
              controller: _viewController,
              backgroundWidget: _buildBackground(
                // Forward the live pill geometry so the bar shell
                // can do the iOS-26 dual-layer icon highlight.
                // Only pass values while the glass pill is on
                // screen — at rest the shell uses
                // `selectedIndex` directly.
                pillFrac: _pageIndex == 6 && _pillGlassVisible
                    ? pillFrac
                    : null,
                pillW: _pageIndex == 6 && _pillGlassVisible
                    ? _tabLayout.pillWidth + pillExtraW + tabSqueezeW
                    : null,
                pillH: _pageIndex == 6 && _pillGlassVisible
                    ? _tabLayout.cellHeight + pillExtraH + tabStretchH
                    : null,
              ),
              pixelRatio: 1,
              useSync: true,
              realTimeCapture: true,
              refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
              children: [
                ..._pageLenses(_pageIndex),
                // Tab pill — visible while animating OR while the
                // user is dragging it. Only on the tab-bar page.
                if (_pageIndex == 6 && _pillGlassVisible)
                  buildLiquidGlassBottomNavPill(
                    layout: _tabLayout,
                    animatedIndex: pillFrac,
                    parentWidth: parentWidth,
                    extraHeight: pillExtraH + tabStretchH,
                    extraWidth: pillExtraW + tabSqueezeW,
                  ),
                if (_pageIndex == 6)
                  LiquidGlassTabBarAction(
                    position: LiquidGlassAlignPosition(
                      alignment: Alignment.bottomRight,
                      // Vertically center the search button on the
                      // tab bar's row. Bar center sits at
                      // `bottomMargin + height/2` from the bottom of
                      // the screen, and the action button is `size`
                      // tall, so its bottom should be at
                      // `barCenter - size/2`.
                      margin: EdgeInsets.only(
                        right: 16,
                        bottom: _tabLayout.bottomMargin +
                            _tabLayout.height / 2 -
                            _searchButtonSize / 2,
                      ),
                    ),
                    icon: Icons.search_rounded,
                    size: _searchButtonSize,
                    onTap: () {},
                  ),
                // Slider thumb glass — only while dragging or
                // returning from a drag.
                if (_pageIndex == 7 &&
                    (_sliderDragging || _sliderAnim.isAnimating))
                  buildLiquidGlassSliderThumb(
                    layout: _sliderLayout,
                    trackLeft: _sliderTrackLeftFromLeft,
                    trackBottom: _sliderTrackBottomFromBottom,
                    value: _sliderValue,
                    growFraction: sliderGrow,
                    stretchFraction: _sliderStretch,
                  ),
                // Toggle thumb glass — only while toggling.
                if (_pageIndex == 7 && _toggleAnim.isAnimating)
                  buildLiquidGlassToggleThumb(
                    layout: _toggleLayout,
                    trackLeft: _toggleTrackLeftFromLeft,
                    trackBottom: _toggleTrackBottomFromBottom,
                    travelFraction: _toggleFraction.value,
                    growFraction: toggleGrow,
                  ),
                // Segmented control morph pill — visible only while
                // the controller is animating between segments.
                if (_pageIndex == 5 && _segAnim.isAnimating)
                  buildLiquidGlassMorphSegmentedPill(
                    layout: _segLayout,
                    animatedIndex: _segIndexTween.value,
                    parentWidth: parentWidth,
                    topMargin: _segTopMargin,
                    extraHeight: _segLayout.pillExtraHeight *
                        liquidGlassMorphEnvelope(_segAnim.value),
                  ),
              ],
            ),
            // Control Center vertical slider overlays — placed
            // ABOVE the LiquidGlassView so the white fill + icon
            // are NOT bent or blurred by the lens shader. The
            // lens itself sits below and only refracts the
            // background photo. `IgnorePointer` on the overlay
            // lets the vertical-drag gestures pass through to
            // the lens's child gesture detector underneath.
            if (_pageIndex == 2) ...[
              Positioned(
                left: _ccBrightnessLeft,
                top: _ccVerticalSliderTop,
                child: IgnorePointer(
                  child: VerticalSliderFill(
                    value: _ccBrightness,
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFFFB800),
                    width: _ccVerticalSliderWidth,
                    height: _ccVerticalSliderHeight,
                  ),
                ),
              ),
              Positioned(
                left: _ccVolumeLeft,
                top: _ccVerticalSliderTop,
                child: IgnorePointer(
                  child: VerticalSliderFill(
                    value: _ccVolume,
                    icon: Icons.volume_up_rounded,
                    iconColor: const Color(0xFF007AFF),
                    width: _ccVerticalSliderWidth,
                    height: _ccVerticalSliderHeight,
                  ),
                ),
              ),
            ],
            // Segmented control static rest pill — visible while
            // the morph is NOT running. Lives in the outer Stack
            // (above the LiquidGlassView), exactly mirroring the
            // bottom-nav hand-off pattern.
            if (_pageIndex == 5 && !_segPillGlassActive)
              Positioned(
                key: const ValueKey('lg-segmented-pill-static'),
                left: (parentWidth - _segLayout.width) / 2 +
                    _segLayout.padding +
                    _segIndexCommitted * _segLayout.cellWidth,
                top: _segTopMargin + _segLayout.padding,
                child: LiquidGlassMorphSegmentedPillStatic(
                  width: _segLayout.pillWidth,
                  height: _segLayout.cellHeight,
                ),
              ),
            // Segmented control labels — placed ABOVE the
            // LiquidGlassView (so the capsule's distortion does
            // NOT soften the text) and ABOVE the static rest
            // pill (so the labels read on top of the highlight).
            // Owns the tap-to-switch gesture. The morph pill
            // (added inside the LiquidGlassView's children) slides
            // UNDER this layer during a transition.
            if (_pageIndex == 5)
              LiquidGlassMorphSegmentedShell(
                segments: _segItems,
                // Show the COMMITTED selection — text weight
                // flips after the glass pill arrives, not at
                // tap, so the bold label and the glass meet at
                // the destination at the same time.
                selectedIndex: _segIndexCommitted,
                onChanged: _onSegChanged,
                layout: _segLayout,
                topMargin: _segTopMargin,
              ),
            // Static tab pill at rest — only when the glass is NOT
            // on screen AND we're on the tab-bar page. The glass and
            // this static pill act as a single component: while
            // transitioning, only the glass is visible; at rest, only
            // this pill is. The hand-off happens in one setState
            // (post-frame after the tab animation completes) so they
            // never overlap.
            //
            // Keyed Positioned: without this, Flutter's positional
            // reconciliation in the parent Stack would treat the
            // gesture overlay below as taking this slot the moment
            // the static pill is hidden, deactivate the overlay's
            // RawGestureDetector State, and DROP the in-flight
            // drag — which is exactly the "first drag freezes
            // mid-gesture, second drag works" bug.
            if (_pageIndex == 6 && !_pillGlassActive && !_tabDragging)
              Positioned(
                key: const ValueKey('lg-bottom-nav-pill-static'),
                left: staticPillLeft,
                bottom: staticBottom,
                child: LiquidGlassBottomNavPillStatic(
                  width: _tabLayout.pillWidth,
                  height: _tabLayout.cellHeight,
                ),
              ),
            // Unified gesture overlay covering the entire tab bar
            // row. Owns BOTH the tap (cell-by-cell) and the
            // horizontal drag (the pill drag) in a single
            // gesture-arena scope, so press-then-drag transitions
            // smoothly: the tap-down arms a tap, finger movement
            // promotes it to a horizontal drag, and the pill
            // releases on whichever wins. Replaces the previous
            // split between `InkWell`-on-shell + drag-overlay
            // which raced across two subtrees.
            //
            // Keyed Positioned (see comment above the static
            // pill): preserves the RawGestureDetector State across
            // sibling add/remove in the Stack, so the recognizer
            // that accepted a pointer-down keeps receiving moves
            // for the lifetime of that gesture. Only mounted on
            // the tab-bar page.
            if (_pageIndex == 6)
              Positioned(
                key: const ValueKey('lg-bottom-nav-gesture-overlay'),
                left: (parentWidth - _tabLayout.width) / 2 + _tabLayout.padding,
                bottom: staticBottom,
                width: _tabLayout.width - 2 * _tabLayout.padding,
                height: _tabLayout.cellHeight,
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    // Tap recognizer for the cell-by-cell selection.
                    // Loses to the drag recognizer if the finger
                    // moves enough to pass slop — exactly what we
                    // want for press-then-drag.
                    TapGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            TapGestureRecognizer>(
                      () => TapGestureRecognizer(),
                      (instance) {
                        instance.onTapUp = _onTabBarTapUp;
                      },
                    ),
                    HorizontalDragGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            HorizontalDragGestureRecognizer>(
                      () => HorizontalDragGestureRecognizer(),
                      (instance) {
                        instance
                          ..onStart = _onTabPillDragStart
                          ..onUpdate = _onTabPillDragUpdate
                          ..onEnd = _onTabPillDragEnd
                          ..onCancel = _onTabPillDragCancel;
                      },
                    ),
                  },
                ),
              ),
          ],
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _prev,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
