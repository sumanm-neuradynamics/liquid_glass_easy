import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../liquid_glass.dart';
import '../../liquid_glass_config.dart'
    show LiquidGlassAppearance, LiquidGlassRefraction;
import '../../utils/liquid_glass_blur.dart';
import '../../utils/liquid_glass_border_mode.dart';
import '../../utils/liquid_glass_position.dart';
import '../../utils/liquid_glass_refraction_mode.dart';
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

    // ── Grouped configuration (preferred) ──────────────────
    // Each group, when provided, takes precedence over the matching
    // flat parameters below — including the group's own defaults. The
    // flat parameters are kept for compatibility and will be replaced
    // by the groups in 3.0.

    /// Icon + label styling of the tabs. Overrides [selectedItemColor],
    /// [unselectedItemColor], [iconSize] and [labelFontSize].
    LiquidGlassNavItemStyle? itemStyle,

    /// Everything about the selection pill — highlight look, slide
    /// animation, and the glass-refracting morph mode. Overrides
    /// [glassPill], [showSelectionPill], [selectionColor], [animated],
    /// [animationDuration], [animationCurve] and the `pill*` params.
    LiquidGlassNavPillStyle? pillStyle,

    /// Appearance of the bar capsule (tint, blur, saturation).
    /// Overrides [glassColor] and [blur].
    LiquidGlassAppearance? appearance,

    /// Refraction of the bar capsule. Overrides [distortion],
    /// [distortionWidth], [chromaticAberration] and [magnification].
    LiquidGlassRefraction? refraction,

    // ── Glass-refracting morph pill (flat) ─────────────────
    LiquidGlassPillMode glassPill = LiquidGlassPillMode.none,
    LiquidGlassBlur pillBlur = const LiquidGlassBlur(),
    double pillGrowHeight = 16,
    double pillDistortion = 0.06,
    double pillDistortionWidth = 10,
    double pillMagnification = 1,
    bool pillEnableInnerRadiusTransparent = false,
    super.controller,

    // ── Size & position ────────────────────────────────────
    super.width = 300,
    super.height = 64,

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

    // ── Glass look (flat) ──────────────────────────────────
    /// Base tint of the glass capsule.
    Color glassColor = const Color(0x16FFFFFF), // white, alpha 22
    LiquidGlassBlur blur = const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    double distortion = 0.07,
    double distortionWidth = 28,
    double chromaticAberration = 0.002,
    double magnification = 1,

    /// Border styling of the capsule rim.
    double borderWidth = 1.2,
    double lightIntensity = 1.1,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.2,
      ambientIntensity: 1.0,
      borderSolidity: 0.35,
    ),

    // ── Selection highlight (flat) ─────────────────────────
    /// Whether to draw the soft pill behind the selected item.
    bool showSelectionPill = true,

    /// Color of the selection pill behind the active item.
    Color selectionColor = const Color(0x26FFFFFF), // white, alpha 38

    // ── Items (flat) ───────────────────────────────────────
    /// Color of the selected item's icon + label.
    Color selectedItemColor = Colors.white,

    /// Color of unselected items' icons + labels.
    Color unselectedItemColor = Colors.white70,

    /// Icon size for every item.
    double iconSize = 24,

    /// Label font size. Labels are only shown for items that
    /// provide a [LiquidGlassTabBarItem.label].
    double labelFontSize = 10.5,

    // ── Animation (flat) ───────────────────────────────────
    /// When `true`, the selection pill **slides** between tabs and the
    /// icon under the pill fills in (the iOS-26 "icon highlights
    /// through the moving pill" reveal) as it travels. When `false`
    /// (default) the selection jumps instantly.
    ///
    /// The animation is drawn entirely inside the lens `child`, so it
    /// composites identically on both Skia and Impeller — no extra
    /// pipeline or controller wiring is required from the caller.
    bool animated = false,

    /// How long the pill takes to slide between tabs. Only used when
    /// [animated] is `true`.
    Duration animationDuration = const Duration(milliseconds: 320),

    /// Easing curve for the pill slide. Only used when [animated] is
    /// `true`.
    Curve animationCurve = Curves.easeOutCubic,
  })  : assert(items.isNotEmpty, 'Provide at least one item'),
        assert(selectedIndex >= 0 && selectedIndex < items.length,
            'selectedIndex out of range'),
        glassPill = pillStyle?.mode ?? glassPill,
        pillBlur = pillStyle?.blur ?? pillBlur,
        pillGrowHeight = pillStyle?.growHeight ?? pillGrowHeight,
        pillDistortion = pillStyle?.distortion ?? pillDistortion,
        pillDistortionWidth =
            pillStyle?.distortionWidth ?? pillDistortionWidth,
        pillMagnification = pillStyle?.magnification ?? pillMagnification,
        pillEnableInnerRadiusTransparent =
            pillStyle?.enableInnerRadiusTransparent ??
                pillEnableInnerRadiusTransparent,
        navLayout = LiquidGlassBottomNavBarLayout(
          itemCount: items.length,
          width: width,
          height: height,
          bottomMargin: bottomMargin,
          padding: itemPadding,
        ),
        customPosition = position,
        super(
          position: position ??
              LiquidGlassAlignPosition(
                alignment: Alignment.bottomCenter,
                margin: EdgeInsets.only(bottom: bottomMargin),
              ),
          color: appearance?.color ?? glassColor,
          blur: appearance?.blur ?? blur,
          saturation: appearance?.saturation ?? 1.0,
          enableInnerRadiusTransparent:
              appearance?.enableInnerRadiusTransparent ?? false,
          transparentWhenBlack: appearance?.transparentWhenBlack ?? false,
          distortion: refraction?.distortion ?? distortion,
          distortionWidth: refraction?.distortionWidth ?? distortionWidth,
          chromaticAberration:
              refraction?.chromaticAberration ?? chromaticAberration,
          magnification: refraction?.magnification ?? magnification,
          refractionMode: refraction?.refractionMode ??
              LiquidGlassRefractionMode.shapeRefraction,
          diagonalFlip: refraction?.diagonalFlip ?? 0,
          shape: RoundedRectangleShape(
            cornerRadius: cornerRadius ?? height / 2,
            borderWidth: borderWidth,
            lightIntensity: lightIntensity,
            lightDirection: lightDirection,
            borderType: borderType,
          ),
          child: (pillStyle?.animated ?? animated)
              ? AnimatedBottomNavBarContent(
                  items: items,
                  selectedIndex: selectedIndex,
                  onChanged: onChanged,
                  itemPadding: itemPadding,
                  showSelectionPill: pillStyle?.show ?? showSelectionPill,
                  selectionColor: pillStyle?.color ?? selectionColor,
                  selectedItemColor:
                      itemStyle?.selectedColor ?? selectedItemColor,
                  unselectedItemColor:
                      itemStyle?.unselectedColor ?? unselectedItemColor,
                  iconSize: itemStyle?.iconSize ?? iconSize,
                  labelFontSize: itemStyle?.labelFontSize ?? labelFontSize,
                  duration: pillStyle?.animationDuration ?? animationDuration,
                  curve: pillStyle?.animationCurve ?? animationCurve,
                )
              : BottomNavBarContent(
                  items: items,
                  selectedIndex: selectedIndex,
                  onChanged: onChanged,
                  itemPadding: itemPadding,
                  showSelectionPill: pillStyle?.show ?? showSelectionPill,
                  selectionColor: pillStyle?.color ?? selectionColor,
                  selectedItemColor:
                      itemStyle?.selectedColor ?? selectedItemColor,
                  unselectedItemColor:
                      itemStyle?.unselectedColor ?? unselectedItemColor,
                  iconSize: itemStyle?.iconSize ?? iconSize,
                  labelFontSize: itemStyle?.labelFontSize ?? labelFontSize,
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
