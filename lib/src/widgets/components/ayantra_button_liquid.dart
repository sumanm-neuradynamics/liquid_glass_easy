import 'package:flutter/material.dart';

import '../lens/liquid_glass_lens.dart';
import '../liquid_glass_config.dart';
import '../liquid_glass_style.dart';
import '../../theme/app_colors.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_glyph.dart';
import '../utils/liquid_glass_shape.dart';

/// A pill-shaped action button rendered as warm-gold liquid glass — the
/// Ayantra brand variant of the plain [LiquidGlassButton].
///
/// Same drop-in shape as [LiquidGlassButton]: place it anywhere in a
/// layout; it needs no position and no `LiquidGlassView` on Impeller, and
/// on Skia / Web it just needs a `LiquidGlassView` ancestor to refract.
///
/// Its [defaultStyle] tints the glass with [AppColors.primary300] (the
/// brand gold) instead of a neutral white frost — mirroring the existing
/// `goldCta` / `primaryCta` pattern of tinting at ~72% alpha — with a
/// warmer, more saturated optical rim so the pill reads as gold liquid
/// glass rather than plain frosted glass.
///
/// To use the current [Theme]'s primary color instead of the static
/// brand gold, override the appearance from context:
///
/// ```dart
/// AyantraButtonLiquid(
///   label: 'Continue',
///   style: AyantraButtonLiquid.defaultStyle.copyWith(
///     appearance: LiquidGlassAppearance(
///       color: Theme.of(context).colorScheme.primary.withAlpha(184),
///     ),
///   ),
///   onPressed: () {},
/// )
/// ```
class AyantraButtonLiquid extends StatelessWidget {
  const AyantraButtonLiquid({
    super.key,
    required this.label,
    this.icon,
    this.iconAsset,
    this.iconAssetPackage,
    this.onPressed,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.style,
    this.visibility = true,
    this.foregroundColor = AppColors.secondary500,
    this.fontSize = 16,
    this.fontWeight = FontWeight.w600,
    this.iconSize = 20,
  });

  /// Button label text.
  final String label;

  /// Optional leading icon. Ignored when [iconAsset] is set.
  final IconData? icon;

  /// Optional leading icon as an SVG asset path, takes precedence over
  /// [icon].
  final String? iconAsset;

  /// Package [iconAsset] ships from, when it isn't the app's own assets.
  final String? iconAssetPackage;

  /// Tap callback.
  final VoidCallback? onPressed;

  /// Explicit width. When null the button hugs its content.
  final double? width;

  /// Capsule height; also drives the default pill radius (`height / 2`).
  final double height;

  /// Inner padding around the label/icon.
  final EdgeInsetsGeometry padding;

  /// The button's glass look as one [LiquidGlassStyle] (shape +
  /// appearance + refraction), taken as the complete look. When null the
  /// tuned [defaultStyle] is used. Its `shape` may be null, in which case
  /// a full pill ([LiquidGlassShape] with radius `height / 2`) and a
  /// tuned gold optical border are used. To tweak one facet while keeping
  /// the rest of the tuned look, compose with `copyWith`, e.g.
  /// `style: AyantraButtonLiquid.defaultStyle.copyWith(...)`.
  final LiquidGlassStyle? style;

  /// Whether the button is shown; toggling animates the glass in/out.
  final bool visibility;

  /// Color of the label text and icon. Defaults to [AppColors.secondary500]
  /// (dark chrome) for contrast against the opaque brand-gold fill.
  final Color foregroundColor;

  /// Font size of the label.
  final double fontSize;

  /// Font weight of the label.
  final FontWeight fontWeight;

  /// Size of the leading icon.
  final double iconSize;

  static const LiquidGlassAppearance _defaultAppearance =
      LiquidGlassAppearance(
    // Brand gold at ~72% alpha, mirroring the goldCta/primaryCta tint.
    color: Color(0xB8EEAB2F), // AppColors.primary300, alpha ~184/255
    blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
  );

  static const LiquidGlassRefraction _defaultRefraction =
      LiquidGlassRefraction(
    distortion: 0.07,
    distortionWidth: 24,
    chromaticAberration: 0.002,
  );

  /// The tuned default look — an opaque-leaning brand-gold tint over a
  /// soft optical refraction with a warmer, more saturated rim. Its
  /// `shape` is `null`: the button derives a height-tracking full pill
  /// with a gold optical border when [style] supplies no shape. Compose
  /// with `copyWith` to tweak one facet, e.g.
  /// `style: AyantraButtonLiquid.defaultStyle.copyWith(...)`.
  static const LiquidGlassStyle defaultStyle = LiquidGlassStyle(
    appearance: _defaultAppearance,
    refraction: _defaultRefraction,
  );

  @override
  Widget build(BuildContext context) {
    final LiquidGlassStyle resolved = defaultStyle.merge(style);
    final LiquidGlassShape effectiveShape = resolved.shape ??
        LiquidGlassShape.roundedRectangle(
          cornerRadius: height / 2,
          borderWidth: 1.1,
          lightIntensity: 1.2,
          lightDirection: 80,
          borderType: const OpticalBorder(
            // Bumped saturation/ambient vs. the plain white button so the
            // rim reads warm-gold rather than neutral.
            borderSaturation: 1.4,
            ambientIntensity: 1.15,
            borderSolidity: 0.35,
          ),
        );

    return SizedBox(
      width: width,
      height: height,
      child: LiquidGlassLens(
        style: LiquidGlassStyle(
          shape: effectiveShape,
          appearance: resolved.appearance,
          refraction: resolved.refraction,
        ),
        visibility: visibility,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(
              liquidGlassClipCornerRadius(effectiveShape),
            ),
            onTap: onPressed,
            child: Padding(
              padding: padding,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null || iconAsset != null) ...[
                      LiquidGlassGlyph(
                        icon: icon,
                        assetPath: iconAsset,
                        assetPackage: iconAssetPackage,
                        size: iconSize,
                        color: foregroundColor,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: fontSize,
                        fontWeight: fontWeight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
