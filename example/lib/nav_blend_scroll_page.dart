import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'nav_bar_tuning.dart';
import 'scaffold_demo.dart' show AuroraFeed;
import 'tuning_store.dart';

// =============================================================
// Scroll-to-merge nav bar + tab button.
//
// The SAME Aurora feed + liquid-glass bottom nav bar as the Scaffold demo,
// except:
//   • the nav bar has 3 elements, and
//   • a single tab button floats just to its right.
//
// IMPORTANT: this uses a LiquidGlassView directly (NOT LiquidGlassScaffold).
// A LiquidGlassBlender's member lenses only register when the blender is a
// plain descendant of the view's `child`; the scaffold's slot wrapper breaks
// that registration, so the merged glass renders nothing there. The view is
// what the scaffold wraps anyway, so the look is identical.
//
// Both the bar and the button are members of ONE LiquidGlassBlender. As you
// scroll the feed, the button slides into the bar; once the gap drops under
// the blender's smoothness their glass flows together (the metaball bridge),
// and by the end of the scroll they have fused into one bottom bar. Scroll
// back up and the button splits off again.
// =============================================================

class NavBlendScrollPage extends StatefulWidget {
  const NavBlendScrollPage({super.key});

  @override
  State<NavBlendScrollPage> createState() => _NavBlendScrollPageState();
}

class _NavBlendScrollPageState extends State<NavBlendScrollPage> {
  final ScrollController _scroll = ScrollController();

  int _navIndex = 0;

  // Blur strength (sigma) of the merged glass surface. Change this to taste —
  // 0 = no blur, higher = frostier.
  static const double _blurSigma = 0.5;

  // Width (logical px) of the refraction band at the lens edge. Higher = a
  // wider, softer bend; lower = a tighter, sharper edge.
  static const double _distortionWidth = 28;

  // Bar geometry — same 64-px height as the scaffold bar.
  static const double _barH = 64;
  static const double _navW = 192; // 3 elements (≈64 each)
  static const double _buttonW = 64; // single round tab button

  // The button sits clearly apart at the top of the scroll, then slides in to
  // a slight overlap (fully fused). The apart-gap must exceed the blender's
  // smoothness so no bridge shows at rest.
  static const double _gapApart = 46;
  static const double _gapMerged = -6;

  // Logical pixels of scroll that complete the merge.
  static const double _mergeDistance = 240;

  double _t = 0; // 0 → apart, 1 → fused

  ValueNotifier<NavTuning> get _navTuning => TuningStore.instance.nav;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final double offset = _scroll.hasClients ? _scroll.offset : 0;
    final double t = (offset / _mergeDistance).clamp(0.0, 1.0);
    if (t != _t) setState(() => _t = t);
  }

  // The three nav items + their per-tab accent / copy (mirrors the scaffold
  // demo's recolouring so the refracting glass picks up a different hue).
  static const _navItems = [
    LiquidGlassTabBarItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
      label: 'Search',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'You',
    ),
  ];
  static const _accents = [
    Color(0xFF7C5CFF),
    Color(0xFF4FB3FF),
    Color(0xFF2DD4BF),
  ];
  static const _overlines = ['TUESDAY · JUNE 24', 'BROWSE ALL', 'YOUR LIBRARY'];
  static const _greetings = ['Good evening', 'Search', 'Your music'];

  @override
  Widget build(BuildContext context) {
    final navTuning = _navTuning.value;

    // The merged surface's material = the nav-bar look with a tunable blur.
    final LiquidGlassStyle navStyle = navBarStyle(navTuning);
    final LiquidGlassStyle blenderStyle = navStyle.copyWith(
      appearance: navStyle.appearance.copyWith(
        blur: const LiquidGlassBlur(sigmaX: _blurSigma, sigmaY: _blurSigma),
      ),
      refraction: navStyle.refraction.copyWith(
        distortionWidth: _distortionWidth,
      ),
    );

    final double w = MediaQuery.sizeOf(context).width;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    // Keep the union centred so the pair fuses into a single centred bar
    // rather than drifting to one side.
    final double gap = _gapApart + (_gapMerged - _gapApart) * _t;
    final double unionW = _navW + gap + _buttonW;
    final double unionLeft = (w - unionW) / 2;
    final double navLeft = unionLeft;
    final double buttonLeft = unionLeft + _navW + gap;
    final double barBottom = 24 + bottomInset;

    return Scaffold(
      body: Stack(
        children: [
          ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
            child: AuroraFeed(
              accent: _accents[_navIndex],
              overline: _overlines[_navIndex],
              greeting: _greetings[_navIndex],
              controller: _scroll,
            ),
          ),

          // The real UI: 3-element nav bar + single tab button, merging on
          // scroll. navBarStyle carries a blur; the blender now blurs via a
          // stacked engine BackdropFilter (no ImageFilter.compose), so the
          // engine blur renders correctly.
          Positioned.fill(
            child: LiquidGlassBlender(
              smoothness: 34,
              style: blenderStyle,
              child: Stack(
                children: [
                  // The liquid-glass bottom nav bar — 3 elements.
                  Positioned(
                    left: navLeft,
                    bottom: barBottom,
                    width: _navW,
                    height: _barH,
                    child: LiquidGlassBottomNavBar(
                      items: _navItems,
                      selectedIndex: _navIndex,
                      onChanged: (i) => setState(() => _navIndex = i),
                      style: navBarStyle(navTuning),
                      pillStyle: navPillStyle(navTuning),
                      width: _navW,
                      height: _barH,
                      margin: EdgeInsets.zero,
                    ),
                  ),

                  // The single tab button to its right.
                  Positioned(
                    left: buttonLeft,
                    bottom: barBottom,
                    width: _buttonW,
                    height: _barH,
                    child: _TabButton(
                      navTuning: navTuning,
                      onTap: () => setState(() => _navIndex = 0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single round glass tab button — a lone [LiquidGlassLens] member so it
/// metaball-merges with the bar. Its capsule uses the same tuned bar look.
class _TabButton extends StatelessWidget {
  const _TabButton({required this.navTuning, required this.onTap});

  final NavTuning navTuning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final barStyle = navBarStyle(navTuning);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          // A circle: continuous corners at half the side merge smoothly into
          // the bar's continuous capsule.
          shape: const LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: _barH / 2,
            clipQuality: LiquidGlassClipQuality.exact,
            borderWidth: 0.8,
            lightIntensity: 1.1,
            lightDirection: 39,
            borderType: OpticalBorder(
              borderSaturation: 1.2,
              ambientIntensity: 1.0,
              borderSolidity: 1,
            ),
          ),
          appearance: barStyle.appearance,
          refraction: barStyle.refraction,
        ),
        child: const Center(
          child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }
}

const double _barH = 64;
