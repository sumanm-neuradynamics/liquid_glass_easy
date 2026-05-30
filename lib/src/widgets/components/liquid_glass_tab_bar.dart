import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// Description of a single tab in [LiquidGlassTabBar].
class LiquidGlassTabBarItem {
  /// Icon shown when the tab is unselected.
  final IconData icon;

  /// Icon shown when the tab is selected (defaults to [icon]).
  final IconData? selectedIcon;

  /// Optional label below the icon. When `null` the tab renders icon
  /// only, matching the modern liquid-glass minimal style.
  final String? label;

  const LiquidGlassTabBarItem({
    required this.icon,
    this.selectedIcon,
    this.label,
  });
}

/// A floating "liquid glass" tab bar.
///
/// Renders 2–5 tabs as a single translucent pill that sits above the
/// content (not pinned to the screen edge). The active tab is marked
/// with a soft inner pill that moves **instantly** to the selected
/// tab (no slide animation).
///
/// This is the non-animated, release-ready variant. An animated
/// counterpart ([LiquidGlassAnimatedTabBar]) exists in the source
/// but is intentionally **not exported** while its motion work is
/// still being finished.
///
/// HIG-style notes that informed the defaults:
/// - Use three to five tabs in iOS-style apps.
/// - The bar is translucent and floats over content.
/// - Selected state is shown via a subtle background pill, not just
///   color.
class LiquidGlassTabBar extends LiquidGlass {
  LiquidGlassTabBar({
    required super.position,
    required List<LiquidGlassTabBarItem> items,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    super.height = 64,
    super.width = 320,
    super.controller,

    /// Corner radius of the capsule. Defaults to a full pill
    /// (`height / 2`).
    double? cornerRadius,

    /// Translucent glass tint of the capsule.
    Color glassColor = const Color(0x1CFFFFFF), // white, alpha 28
    super.blur = const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
    super.distortion = 0.08,
    super.distortionWidth = 32,
    super.chromaticAberration = 0.002,
    super.magnification = 1,

    // ── Border ─────────────────────────────────────────────
    double borderWidth = 1.2,
    double lightIntensity = 1.2,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.3,
      ambientIntensity: 1.0,
      borderSolidity: 0.4,
    ),

    // ── Selection pill ─────────────────────────────────────
    /// Whether to draw the soft pill behind the selected tab.
    bool showSelectionPill = true,

    /// Fill color of the selection pill.
    Color selectionColor = const Color(0x32FFFFFF), // white, alpha 50

    /// Border color of the selection pill.
    Color selectionBorderColor = const Color(0x50FFFFFF), // alpha 80

    // ── Items ──────────────────────────────────────────────
    /// Color of the selected tab's icon + label.
    Color selectedItemColor = Colors.white,

    /// Color of unselected tabs' icons + labels.
    Color unselectedItemColor = Colors.white70,

    /// Icon size for every tab.
    double iconSize = 24,

    /// Label font size (labels show only when an item has a label).
    double labelFontSize = 10.5,
    super.draggable = false,
    super.outOfBoundaries = false,
  })  : assert(items.length >= 2 && items.length <= 5,
            'Tab bars use 2–5 tabs'),
        assert(selectedIndex >= 0 && selectedIndex < items.length),
        super(
          color: glassColor,
          shape: RoundedRectangleShape(
            cornerRadius: cornerRadius ?? height / 2,
            borderWidth: borderWidth,
            lightIntensity: lightIntensity,
            lightDirection: lightDirection,
            borderType: borderType,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(builder: (context, constraints) {
              final segWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  // Selected pill — jumps instantly between tabs
                  // (no slide). The animated slide lives in
                  // [LiquidGlassAnimatedTabBar].
                  if (showSelectionPill)
                    Positioned(
                      left: selectedIndex * segWidth,
                      top: 0,
                      bottom: 0,
                      width: segWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectionColor,
                          borderRadius:
                              BorderRadius.circular((height - 12) / 2),
                          border: Border.all(
                            color: selectionBorderColor,
                            width: 0.6,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (int i = 0; i < items.length; i++)
                        Expanded(
                          child: _TabButton(
                            item: items[i],
                            selected: i == selectedIndex,
                            selectedColor: selectedItemColor,
                            unselectedColor: unselectedItemColor,
                            iconSize: iconSize,
                            labelFontSize: labelFontSize,
                            onTap: () => onChanged(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
}

/// Animated variant of [LiquidGlassTabBar]: the selection pill
/// **slides** between tabs instead of jumping.
///
/// **Not exported yet.** Kept internal while the animation polish
/// for the liquid-glass components is still being finished, so it is
/// only consumed by the package's own example/showcase. Once the
/// motion work is complete it can be promoted to the public API. It
/// already carries the full customization surface of
/// [LiquidGlassTabBar] plus [selectionDuration] and [selectionCurve].
class LiquidGlassAnimatedTabBar extends LiquidGlass {
  LiquidGlassAnimatedTabBar({
    required super.position,
    required List<LiquidGlassTabBarItem> items,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    super.height = 64,
    super.width = 320,
    super.controller,

    /// Corner radius of the capsule. Defaults to a full pill
    /// (`height / 2`).
    double? cornerRadius,

    /// Translucent glass tint of the capsule.
    Color glassColor = const Color(0x1CFFFFFF), // white, alpha 28
    super.blur = const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
    super.distortion = 0.08,
    super.distortionWidth = 32,
    super.chromaticAberration = 0.002,
    super.magnification = 1,

    // ── Border ─────────────────────────────────────────────
    double borderWidth = 1.2,
    double lightIntensity = 1.2,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.3,
      ambientIntensity: 1.0,
      borderSolidity: 0.4,
    ),

    // ── Selection pill ─────────────────────────────────────
    /// Whether to draw the soft pill behind the selected tab.
    bool showSelectionPill = true,

    /// Fill color of the selection pill.
    Color selectionColor = const Color(0x32FFFFFF), // white, alpha 50

    /// Border color of the selection pill.
    Color selectionBorderColor = const Color(0x50FFFFFF), // alpha 80

    /// How long the selection pill takes to slide between tabs.
    Duration selectionDuration = const Duration(milliseconds: 240),

    /// Easing curve for the slide.
    Curve selectionCurve = Curves.easeOutCubic,

    // ── Items ──────────────────────────────────────────────
    /// Color of the selected tab's icon + label.
    Color selectedItemColor = Colors.white,

    /// Color of unselected tabs' icons + labels.
    Color unselectedItemColor = Colors.white70,

    /// Icon size for every tab.
    double iconSize = 24,

    /// Label font size (labels show only when an item has a label).
    double labelFontSize = 10.5,
    super.draggable = false,
    super.outOfBoundaries = false,
  })  : assert(items.length >= 2 && items.length <= 5,
            'Tab bars use 2–5 tabs'),
        assert(selectedIndex >= 0 && selectedIndex < items.length),
        super(
          color: glassColor,
          shape: RoundedRectangleShape(
            cornerRadius: cornerRadius ?? height / 2,
            borderWidth: borderWidth,
            lightIntensity: lightIntensity,
            lightDirection: lightDirection,
            borderType: borderType,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(builder: (context, constraints) {
              final segWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  // Selected pill — animates (slides) between tabs.
                  if (showSelectionPill)
                    AnimatedPositioned(
                      duration: selectionDuration,
                      curve: selectionCurve,
                      left: selectedIndex * segWidth,
                      top: 0,
                      bottom: 0,
                      width: segWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectionColor,
                          borderRadius:
                              BorderRadius.circular((height - 12) / 2),
                          border: Border.all(
                            color: selectionBorderColor,
                            width: 0.6,
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      for (int i = 0; i < items.length; i++)
                        Expanded(
                          child: _TabButton(
                            item: items[i],
                            selected: i == selectedIndex,
                            selectedColor: selectedItemColor,
                            unselectedColor: unselectedItemColor,
                            iconSize: iconSize,
                            labelFontSize: labelFontSize,
                            onTap: () => onChanged(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            }),
          ),
        );
}

class _TabButton extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final double iconSize;
  final double labelFontSize;
  final VoidCallback onTap;

  const _TabButton({
    required this.item,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.iconSize,
    required this.labelFontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? (item.selectedIcon ?? item.icon) : item.icon,
                size: iconSize,
                color: color,
              ),
              if (item.label != null) ...[
                const SizedBox(height: 2),
                Text(
                  item.label!,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Companion floating action button rendered as its own
/// liquid-glass pill, mirroring the pattern of pairing a tab bar with
/// a separate, side-floating action (often Search).
class LiquidGlassTabBarAction extends LiquidGlass {
  LiquidGlassTabBarAction({
    required super.position,
    required IconData icon,
    VoidCallback? onTap,
    Color iconColor = Colors.white,
    @Deprecated('Use iconColor instead. Retained so existing call sites '
        'that pass `tint:` still compile.')
    Color? tint,
    double size = 56,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          width: size,
          height: size,
          magnification: 1,
          distortion: 0.07,
          distortionWidth: 28,
          chromaticAberration: 0.002,
          // Transparent body — let the underlying liquid-glass
          // refraction speak for itself. The icon color is
          // independently controlled by [iconColor] (defaults to
          // white) so the button doesn't look "tinted".
          color: Colors.transparent,
          blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
          shape: RoundedRectangleShape(
            // Border profile mirrors the bottom-nav capsule (see
            // [buildLiquidGlassBottomNavCapsule]) so the search
            // button reads as part of the same family rather than
            // a brighter standalone pill.
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
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Icon(
                  icon,
                  color: tint ?? iconColor,
                  size: size * 0.46,
                ),
              ),
            ),
          ),
        );
}
