import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../liquid_glass_view.dart';
import '../../controllers/liquid_glass_view_controller.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_refresh_rate.dart';
import 'bottom_nav_bar/liquid_glass_bottom_nav_bar.dart';

/// A `Scaffold`-style layout for liquid-glass UIs.
///
/// [LiquidGlassScaffold] owns a single [LiquidGlassView] internally so
/// you don't have to wire one up by hand. Your page content goes in
/// [body] and becomes the **background** that every glass slot
/// refracts; the [appBar], [bottomNavigationBar], and
/// [bottomNavigationBarAction] are placed on top of it as liquid-glass
/// lenses.
///
/// Because each slot is just a [LiquidGlass] config object, you compose
/// the scaffold out of the package's existing drop-in components:
///
/// ```dart
/// LiquidGlassScaffold(
///   appBar: LiquidGlassAppBar(
///     title: const Text('Gallery'),
///     actions: const [Icon(Icons.search)],
///   ),
///   body: MyPageContent(),
///   bottomNavigationBar: LiquidGlassBottomNavBar(
///     items: const [
///       LiquidGlassTabBarItem(icon: Icons.home_rounded, label: 'Home'),
///       LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Search'),
///       LiquidGlassTabBarItem(icon: Icons.person_rounded, label: 'You'),
///     ],
///     selectedIndex: _index,
///     onChanged: (i) => setState(() => _index = i),
///   ),
///   bottomNavigationBarAction: LiquidGlassTabBarAction(
///     position: const LiquidGlassAlignPosition(
///       alignment: Alignment.bottomRight,
///       margin: EdgeInsets.only(right: 16, bottom: 32),
///     ),
///     icon: Icons.add_rounded,
///     onTap: _compose,
///   ),
/// )
/// ```
///
/// The renderer is chosen automatically — Impeller devices sample the
/// live backdrop, Skia / Web fall back to a captured snapshot — so the
/// same scaffold runs on both without any change. The render knobs
/// ([pixelRatio], [realTimeCapture], [useSync], [refreshRate],
/// [useImpellerBackdrop]) are forwarded straight through to the
/// internal [LiquidGlassView].
///
/// ### Z-order
///
/// Slots are composited bottom-to-top in this order:
/// `appBar` → `lenses` → `bottomNavigationBar` → `bottomNavigationBarAction`.
/// So the nav bar and its action always float above any extra
/// [lenses], and the app bar sits behind them.
class LiquidGlassScaffold extends StatelessWidget {
  /// The primary content of the screen. Rendered behind every glass
  /// slot and used as the background the lenses refract.
  final Widget body;

  /// A liquid-glass app bar pinned to the top. Typically a
  /// [LiquidGlassAppBar], but any [LiquidGlass] lens works.
  final LiquidGlass? appBar;

  /// A liquid-glass bottom navigation bar pinned to the bottom.
  /// Typically a [LiquidGlassBottomNavBar].
  final LiquidGlass? bottomNavigationBar;

  /// A standalone glass action button that floats **next to** the
  /// [bottomNavigationBar] — the common "tab bar + side action"
  /// pairing (e.g. a search or compose button). Typically a
  /// [LiquidGlassTabBarAction]; position it via its own `position`
  /// (e.g. bottom-right, vertically centered on the nav bar).
  final LiquidGlass? bottomNavigationBarAction;

  /// Extra free-floating glass lenses composited between the [appBar]
  /// and the [bottomNavigationBar]. An escape hatch for anything the
  /// named slots don't cover (docks, cards, FAB-like buttons, …).
  final List<LiquidGlass> lenses;

  /// Optional solid color painted behind [body]. Leave `null` to let
  /// [body] supply its own background (the common case for an image
  /// or gradient wallpaper).
  final Color? backgroundColor;

  /// Whether the bars automatically clear the device safe areas.
  ///
  /// When `true` (the default), the scaffold shifts the [appBar] down by
  /// the top inset (status bar / notch) and the [bottomNavigationBar] +
  /// [bottomNavigationBarAction] up by the bottom inset (home indicator
  /// / gesture bar) — so the bars never sit under the system UI. The
  /// [body] still fills the whole window behind the glass, exactly like
  /// a normal `Scaffold`. Set to `false` to position every slot against
  /// the raw window edges yourself.
  final bool safeArea;

  // ── Render pipeline (forwarded to the internal LiquidGlassView) ──

  /// Controls the internal view's capture pipeline (capture-once,
  /// start/stop realtime). Optional.
  final LiquidGlassViewController? controller;

  /// See [LiquidGlassView.pixelRatio].
  final double pixelRatio;

  /// See [LiquidGlassView.realTimeCapture].
  final bool realTimeCapture;

  /// See [LiquidGlassView.useSync].
  final bool useSync;

  /// See [LiquidGlassView.refreshRate].
  final LiquidGlassRefreshRate refreshRate;

  /// See [LiquidGlassView.useImpellerBackdrop]. Leave `null` for
  /// automatic Skia / Impeller detection.
  final bool? useImpellerBackdrop;

  const LiquidGlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.bottomNavigationBarAction,
    this.lenses = const [],
    this.backgroundColor,
    this.safeArea = true,
    this.controller,
    this.pixelRatio = 1.0,
    this.realTimeCapture = true,
    this.useSync = true,
    this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
    this.useImpellerBackdrop,
  });

  @override
  Widget build(BuildContext context) {
    // Safe-area insets. The bars are shifted off the system UI, while
    // the body keeps filling the whole window behind the glass.
    final EdgeInsets pad =
        safeArea ? MediaQuery.of(context).padding : EdgeInsets.zero;

    // A LiquidGlassBottomNavBar decides for itself whether to use the
    // glass-refracting morphing pill on this renderer; the scaffold only
    // hands over its slots.
    final nav = bottomNavigationBar;
    if (nav is LiquidGlassBottomNavBar &&
        nav.resolveGlassPill(useImpellerBackdrop: useImpellerBackdrop)) {
      return nav.buildGlassPillBar(
        body: body,
        backgroundColor: backgroundColor,
        bottomInset: pad.bottom,
        outerLenses: [
          if (appBar != null) _inset(appBar!, dy: pad.top),
          ...lenses,
          if (bottomNavigationBarAction != null)
            _inset(bottomNavigationBarAction!, dy: -pad.bottom),
        ],
        pixelRatio: pixelRatio,
        useSync: useSync,
        useImpellerBackdrop: useImpellerBackdrop,
        realTimeCapture: realTimeCapture,
      );
    }

    // Composite slots bottom-to-top. `children` order is z-order in
    // LiquidGlassView, so the nav bar + its action float above any
    // extra lenses, and the app bar sits behind them.
    final children = <LiquidGlass>[
      if (appBar != null) _inset(appBar!, dy: pad.top),
      ...lenses,
      if (bottomNavigationBar != null)
        _inset(bottomNavigationBar!, dy: -pad.bottom),
      if (bottomNavigationBarAction != null)
        _inset(bottomNavigationBarAction!, dy: -pad.bottom),
    ];

    final Widget background = backgroundColor == null
        ? body
        : ColoredBox(color: backgroundColor!, child: body);

    return LiquidGlassView(
      controller: controller,
      pixelRatio: pixelRatio,
      realTimeCapture: realTimeCapture,
      useSync: useSync,
      refreshRate: refreshRate,
      useImpellerBackdrop: useImpellerBackdrop,
      backgroundWidget: background,
      children: children,
    );
  }

  /// Returns [lens] shifted by [dy] (and [dx]) — used to push a bar off
  /// the system UI. A zero offset returns the lens untouched so we don't
  /// allocate or invalidate position equality needlessly.
  LiquidGlass _inset(LiquidGlass lens, {double dx = 0, double dy = 0}) {
    if (dx == 0 && dy == 0) return lens;
    return lens.copyWith(
      geometry: lens.geometry.copyWith(
        position: _InsetPosition(lens.position, dx: dx, dy: dy),
      ),
    );
  }
}

/// Wraps another [LiquidGlassPosition] and adds a fixed pixel offset to
/// its resolved result. Lets `LiquidGlassScaffold` nudge a slot by the
/// safe-area inset without caring whether the underlying position is an
/// alignment or an absolute offset.
class _InsetPosition extends LiquidGlassPosition {
  final LiquidGlassPosition base;
  final double dx;
  final double dy;

  const _InsetPosition(this.base, {this.dx = 0, this.dy = 0});

  @override
  Offset resolve(Size parentSize, Size lensSize) {
    final o = base.resolve(parentSize, lensSize);
    return Offset(o.dx + dx, o.dy + dy);
  }
}
