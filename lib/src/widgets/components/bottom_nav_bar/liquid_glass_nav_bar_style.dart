import 'package:flutter/material.dart';

import '../../utils/liquid_glass_blur.dart';

/// Which renderer(s) get the full iOS-26 **glass-refracting** morphing
/// pill (the dual-pipeline animated bar). See
/// [LiquidGlassBottomNavBar.glassPill] for how to opt in.
enum LiquidGlassPillMode {
  /// No glass pill — the lightweight single-lens bar (instant, or a
  /// soft sliding highlight with `animated: true`). Works everywhere.
  none,

  /// Glass-refracting morphing pill **only on Impeller**; falls back to
  /// [none] on Skia / Web.
  impellerOnly,

  /// Glass-refracting morphing pill on **both** Impeller and Skia.
  both,
}

/// **Item** group for [LiquidGlassBottomNavBar]: how each tab's icon
/// and label render. Defaults mirror the bar's flat parameters, so
/// swapping APIs is lossless.
class LiquidGlassNavItemStyle {
  /// Color of the selected item's icon + label.
  final Color selectedColor;

  /// Color of unselected items' icons + labels.
  final Color unselectedColor;

  /// Icon size for every item.
  final double iconSize;

  /// Label font size. Labels are only shown for items that provide one.
  final double labelFontSize;

  const LiquidGlassNavItemStyle({
    this.selectedColor = Colors.white,
    this.unselectedColor = Colors.white70,
    this.iconSize = 24,
    this.labelFontSize = 10.5,
  });

  LiquidGlassNavItemStyle copyWith({
    Color? selectedColor,
    Color? unselectedColor,
    double? iconSize,
    double? labelFontSize,
  }) {
    return LiquidGlassNavItemStyle(
      selectedColor: selectedColor ?? this.selectedColor,
      unselectedColor: unselectedColor ?? this.unselectedColor,
      iconSize: iconSize ?? this.iconSize,
      labelFontSize: labelFontSize ?? this.labelFontSize,
    );
  }
}

/// **Selection pill** group for [LiquidGlassBottomNavBar]: everything
/// about the highlight behind the active tab — its look, whether it
/// slides, and whether/where it upgrades to the glass-refracting
/// morphing pill. Defaults mirror the bar's flat parameters, so
/// swapping APIs is lossless.
///
/// The three tiers, all configured here:
///  • static highlight — the defaults ([animated] false, [mode] none);
///  • sliding highlight — [animated] true: the pill slides between tabs
///    with the iOS-26 icon-reveal, drawn inside the lens (works on
///    every renderer);
///  • glass-refracting morphing pill — [mode] other than
///    [LiquidGlassPillMode.none]: the dual-pipeline pill that refracts
///    the bar itself. The `distortion`/`growHeight`/… knobs below apply
///    to this tier only.
class LiquidGlassNavPillStyle {
  /// Which renderer(s) use the glass-refracting morphing pill.
  final LiquidGlassPillMode mode;

  /// Whether to draw the soft pill behind the selected item.
  final bool show;

  /// Color of the selection pill behind the active item.
  final Color color;

  /// When `true`, the selection pill **slides** between tabs with the
  /// iOS-26 "icon highlights through the moving pill" reveal. When
  /// `false` the selection jumps instantly.
  final bool animated;

  /// How long the pill takes to slide between tabs ([animated] only).
  final Duration animationDuration;

  /// Easing curve for the pill slide ([animated] only).
  final Curve animationCurve;

  /// Blur behind the moving **glass** pill (glass [mode]s only).
  final LiquidGlassBlur blur;

  /// How much taller the glass pill grows than the bar at the peak of a
  /// transition (glass [mode]s only) — the pill's main size knob.
  final double growHeight;

  /// Refraction strength of the moving glass pill (glass [mode]s only).
  final double distortion;

  /// Width of the glass pill's refraction band in logical pixels
  /// (glass [mode]s only).
  final double distortionWidth;

  /// Magnification of the content seen through the glass pill (glass
  /// [mode]s only). `1` = none.
  final double magnification;

  /// When `true`, the glass pill's inner area is transparent (glass
  /// [mode]s only).
  final bool enableInnerRadiusTransparent;

  const LiquidGlassNavPillStyle({
    this.mode = LiquidGlassPillMode.none,
    this.show = true,
    this.color = const Color(0x26FFFFFF),
    this.animated = false,
    this.animationDuration = const Duration(milliseconds: 320),
    this.animationCurve = Curves.easeOutCubic,
    this.blur = const LiquidGlassBlur(),
    this.growHeight = 16,
    this.distortion = 0.06,
    this.distortionWidth = 10,
    this.magnification = 1,
    this.enableInnerRadiusTransparent = false,
  });

  LiquidGlassNavPillStyle copyWith({
    LiquidGlassPillMode? mode,
    bool? show,
    Color? color,
    bool? animated,
    Duration? animationDuration,
    Curve? animationCurve,
    LiquidGlassBlur? blur,
    double? growHeight,
    double? distortion,
    double? distortionWidth,
    double? magnification,
    bool? enableInnerRadiusTransparent,
  }) {
    return LiquidGlassNavPillStyle(
      mode: mode ?? this.mode,
      show: show ?? this.show,
      color: color ?? this.color,
      animated: animated ?? this.animated,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      blur: blur ?? this.blur,
      growHeight: growHeight ?? this.growHeight,
      distortion: distortion ?? this.distortion,
      distortionWidth: distortionWidth ?? this.distortionWidth,
      magnification: magnification ?? this.magnification,
      enableInnerRadiusTransparent:
          enableInnerRadiusTransparent ?? this.enableInnerRadiusTransparent,
    );
  }
}
