import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../liquid_glass.dart';
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_border_mode.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_animated_nav_bar.dart';
import 'liquid_glass_nav_bar_animated_content.dart';
import 'liquid_glass_nav_bar_content.dart';
import 'liquid_glass_nav_bar_layout.dart';
import 'liquid_glass_nav_bar_style.dart';

export 'liquid_glass_nav_bar_animated_content.dart';
export 'liquid_glass_nav_bar_animated_shell.dart';
export 'liquid_glass_nav_bar_content.dart';
export 'liquid_glass_nav_bar_icon_row.dart';
export 'liquid_glass_nav_bar_layout.dart';
export 'liquid_glass_nav_bar_pill.dart';
export 'liquid_glass_nav_bar_pill_clippers.dart';
export 'liquid_glass_nav_bar_shell.dart';
export 'liquid_glass_nav_bar_style.dart';

/// A floating, drop-in liquid-glass bottom navigation bar.
///
/// It is a single [LiquidGlass] lens (a capsule pinned to the bottom
/// of its parent) with the icons, labels, and the selection highlight
/// baked into the lens `child` — so it composes in one line, exactly
/// like [LiquidGlassTabBar]:
///
/// ```dart
/// LiquidGlassView(
///   backgroundWidget: myPageContent,
///   children: [
///     LiquidGlassBottomNavBar(
///       items: const [
///         LiquidGlassTabBarItem(icon: Icons.home_outlined,
///             selectedIcon: Icons.home_rounded, label: 'Home'),
///         LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Search'),
///         LiquidGlassTabBarItem(icon: Icons.person_outline,
///             selectedIcon: Icons.person_rounded, label: 'Profile'),
///       ],
///       selectedIndex: _index,
///       onChanged: (i) => setState(() => _index = i),
///     ),
///   ],
/// )
/// ```
///
/// By default the selection moves **instantly** between tabs. Set
/// `animated: true` to make the selection pill **slide** between tabs
/// with the iOS-26 "icon highlights through the moving pill" reveal —
/// drawn entirely inside the lens, so it works on both Skia and
/// Impeller with no extra wiring.
///
/// Almost everything is customizable — size, position, glass tint and
/// blur, distortion, corner radius, the selection-pill color/visibility,
/// and the icon/label colors and sizes. See the constructor parameters.
class LiquidGlassBottomNavBar extends LiquidGlass {
  /// The tab items — exposed so `LiquidGlassScaffold` can build the
  /// animated glass variant from the same config.
  final List<LiquidGlassTabBarItem> items;

  /// The selected tab index.
  final int selectedIndex;

  /// Selection callback.
  final ValueChanged<int> onChanged;

  /// Which renderer(s) use the glass-refracting morphing pill. Read by
  /// `LiquidGlassScaffold` to decide whether to swap in the animated
  /// dual-pipeline nav bar. Defaults to [LiquidGlassPillMode.none].
  final LiquidGlassPillMode glassPill;

  /// Geometry derived from this bar's size/margins, used by the
  /// animated glass variant.
  final LiquidGlassBottomNavBarLayout navLayout;

  /// The raw `position` the caller passed (may be `null`). Kept so the
  /// animated glass variant can honor a custom position instead of the
  /// default bottom-center placement.
  final LiquidGlassPosition? customPosition;

  /// Blur behind the moving **glass pill** (glassPill modes only).
  /// Defaults to none. Pass a [LiquidGlassBlur] to soften it.
  final LiquidGlassBlur pillBlur;

  /// Refraction strength of the moving glass pill (glassPill modes
  /// only). Higher = more bending. Defaults to `0.06`.
  final double pillDistortion;

  /// Width of the glass pill's refraction band in logical pixels
  /// (glassPill modes only). Defaults to `10`.
  final double pillDistortionWidth;

  /// Magnification of the content seen through the glass pill (glassPill
  /// modes only). `1` = none. Defaults to `1`.
  final double pillMagnification;

  /// When `true`, the glass pill's inner area is transparent, revealing
  /// the background directly through the center (glassPill modes only).
  final bool pillEnableInnerRadiusTransparent;

  /// How much **taller** the moving glass pill grows than the bar at the
  /// peak of a transition (glassPill modes only). The pill's peak height
  /// is `height + pillGrowHeight`, and its width scales to match — so
  /// this is the main knob for the pill's size. Defaults to `16`.
  final double pillGrowHeight;

  LiquidGlassBottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onChanged,

    // ── Grouped configuration ──────────────────────────────
    /// Icon + label styling of the tabs (colors, icon size, label font).
    LiquidGlassNavItemStyle? itemStyle,

    /// Everything about the selection pill — highlight look, slide
    /// animation, and the glass-refracting morph mode.
    LiquidGlassNavPillStyle? pillStyle,

    /// Appearance of the bar capsule (tint, blur, saturation).
    super.appearance = const LiquidGlassAppearance(
      color: Color(0x16FFFFFF), // white, alpha 22
      blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    ),

    /// Refraction of the bar capsule.
    super.refraction = const LiquidGlassRefraction(
      distortion: 0.07,
      distortionWidth: 28,
      chromaticAberration: 0.002,
    ),

    /// Programmatic show/hide control of the bar lens.
    LiquidGlassController? controller,

    // ── Size & position ────────────────────────────────────
    double width = 300,
    double height = 64,

    /// Where the bar sits. Defaults to bottom-center with
    /// [bottomMargin] of breathing room. Pass any
    /// [LiquidGlassPosition] (e.g. [LiquidGlassOffsetPosition]) to
    /// override.
    LiquidGlassPosition? position,

    /// Bottom inset used only when [position] is `null`.
    double bottomMargin = 24,

    /// Inner padding between the capsule rim and the icon row.
    double itemPadding = 6,

    /// Corner radius of the capsule. Defaults to a full pill
    /// (`height / 2`).
    double? cornerRadius,

    /// Border styling of the capsule rim.
    double borderWidth = 1.2,
    double lightIntensity = 1.1,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.2,
      ambientIntensity: 1.0,
      borderSolidity: 0.35,
    ),
  })  : assert(items.isNotEmpty, 'Provide at least one item'),
        assert(selectedIndex >= 0 && selectedIndex < items.length,
            'selectedIndex out of range'),
        glassPill = pillStyle?.mode ?? LiquidGlassPillMode.none,
        pillBlur = pillStyle?.blur ?? const LiquidGlassBlur(),
        pillGrowHeight = pillStyle?.growHeight ?? 16,
        pillDistortion = pillStyle?.distortion ?? 0.06,
        pillDistortionWidth = pillStyle?.distortionWidth ?? 10,
        pillMagnification = pillStyle?.magnification ?? 1,
        pillEnableInnerRadiusTransparent =
            pillStyle?.enableInnerRadiusTransparent ?? false,
        navLayout = LiquidGlassBottomNavBarLayout(
          itemCount: items.length,
          width: width,
          height: height,
          bottomMargin: bottomMargin,
          padding: itemPadding,
        ),
        customPosition = position,
        super(
          geometry: LiquidGlassGeometry(
            position: position ??
                LiquidGlassAlignPosition(
                  alignment: Alignment.bottomCenter,
                  margin: EdgeInsets.only(bottom: bottomMargin),
                ),
            width: width,
            height: height,
            shape: RoundedRectangleShape(
              cornerRadius: cornerRadius ?? height / 2,
              borderWidth: borderWidth,
              lightIntensity: lightIntensity,
              lightDirection: lightDirection,
              borderType: borderType,
            ),
          ),
          behavior: LiquidGlassBehavior(controller: controller),
          child: (pillStyle?.animated ?? false)
              ? AnimatedBottomNavBarContent(
                  items: items,
                  selectedIndex: selectedIndex,
                  onChanged: onChanged,
                  itemPadding: itemPadding,
                  showSelectionPill: pillStyle?.show ?? true,
                  selectionColor:
                      pillStyle?.color ?? const Color(0x26FFFFFF),
                  selectedItemColor: itemStyle?.selectedColor ?? Colors.white,
                  unselectedItemColor:
                      itemStyle?.unselectedColor ?? Colors.white70,
                  iconSize: itemStyle?.iconSize ?? 24,
                  labelFontSize: itemStyle?.labelFontSize ?? 10.5,
                  duration: pillStyle?.animationDuration ??
                      const Duration(milliseconds: 320),
                  curve: pillStyle?.animationCurve ?? Curves.easeOutCubic,
                )
              : BottomNavBarContent(
                  items: items,
                  selectedIndex: selectedIndex,
                  onChanged: onChanged,
                  itemPadding: itemPadding,
                  showSelectionPill: pillStyle?.show ?? true,
                  selectionColor:
                      pillStyle?.color ?? const Color(0x26FFFFFF),
                  selectedItemColor: itemStyle?.selectedColor ?? Colors.white,
                  unselectedItemColor:
                      itemStyle?.unselectedColor ?? Colors.white70,
                  iconSize: itemStyle?.iconSize ?? 24,
                  labelFontSize: itemStyle?.labelFontSize ?? 10.5,
                ),
        );

  /// Whether [glassPill] resolves to the glass-refracting morphing pill
  /// on the active renderer. Pass [useImpellerBackdrop] to force a
  /// renderer (as `LiquidGlassView` does); leave it `null` for automatic
  /// detection.
  bool resolveGlassPill({bool? useImpellerBackdrop}) {
    switch (glassPill) {
      case LiquidGlassPillMode.none:
        return false;
      case LiquidGlassPillMode.both:
        return true;
      case LiquidGlassPillMode.impellerOnly:
        return useImpellerBackdrop ?? ui.ImageFilter.isShaderFilterSupported;
    }
  }

  /// Builds the self-contained dual-pipeline variant of this bar — the
  /// glass-refracting morphing pill. The bar owns this decision and
  /// construction; hosts like `LiquidGlassScaffold` only check
  /// [resolveGlassPill] and call this, passing their slots through.
  ///
  /// [body] is the page content captured behind the glass.
  /// [outerLenses] are composited above the bar (app bar, side action,
  /// extra lenses). [bottomInset] is the safe-area bottom inset; it is
  /// ignored when this bar has a custom [customPosition], which takes
  /// full control of placement.
  Widget buildGlassPillBar({
    required Widget body,
    List<LiquidGlass> outerLenses = const [],
    Color? backgroundColor,
    double bottomInset = 0,
    double pixelRatio = 1.0,
    bool useSync = true,
    bool? useImpellerBackdrop,
    bool realTimeCapture = true,
  }) {
    final bool hasCustomPos = customPosition != null;
    final layout = LiquidGlassBottomNavBarLayout(
      itemCount: navLayout.itemCount,
      width: navLayout.width,
      height: navLayout.height,
      bottomMargin: navLayout.bottomMargin + (hasCustomPos ? 0 : bottomInset),
      padding: navLayout.padding,
      pillExtraHeight: navLayout.pillExtraHeight,
    );

    return LiquidGlassAnimatedNavBar(
      body: body,
      items: items,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      layout: layout,
      outerLenses: outerLenses,
      backgroundColor: backgroundColor,
      barPosition: customPosition,
      pillBlur: pillBlur,
      pillGrowHeight: pillGrowHeight,
      pillDistortion: pillDistortion,
      pillDistortionWidth: pillDistortionWidth,
      pillMagnification: pillMagnification,
      pillEnableInnerRadiusTransparent: pillEnableInnerRadiusTransparent,
      pixelRatio: pixelRatio,
      useSync: useSync,
      useImpellerBackdrop: useImpellerBackdrop,
      realTimeCapture: realTimeCapture,
    );
  }
}
