import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a component glyph from either an SVG asset or a Material
/// [IconData], sharing one size/color contract across every
/// liquid-glass component that exposes both options.
///
/// [assetPath], when set, takes precedence over [icon]. Exactly one of
/// them must be non-null — this mirrors the icon/iconAsset pair every
/// component field exposes.
class LiquidGlassGlyph extends StatelessWidget {
  const LiquidGlassGlyph({
    super.key,
    this.icon,
    this.assetPath,
    this.assetPackage,
    required this.size,
    required this.color,
  }) : assert(icon != null || assetPath != null,
            'Provide either icon or assetPath');

  /// Material icon glyph. Ignored when [assetPath] is set.
  final IconData? icon;

  /// SVG asset path (e.g. `'assets/icons/home.svg'`). Takes precedence
  /// over [icon] when non-null.
  final String? assetPath;

  /// Package the SVG asset ships from, when it isn't the app's own
  /// `assets/` directory (mirrors [AssetImage.package]).
  final String? assetPackage;

  /// Glyph size in logical pixels.
  final double size;

  /// Glyph color. Applied to the SVG via a `srcIn` color filter, so
  /// source SVGs should be single-color / recolorable.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final String? path = assetPath;
    if (path != null) {
      return SvgPicture.asset(
        path,
        package: assetPackage,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    return Icon(icon, size: size, color: color);
  }
}
