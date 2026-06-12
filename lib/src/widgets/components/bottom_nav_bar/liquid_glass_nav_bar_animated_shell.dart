import 'package:flutter/material.dart';

import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_nav_bar_icon_row.dart';
import 'liquid_glass_nav_bar_layout.dart';
import 'liquid_glass_nav_bar_pill_clippers.dart';

/// Animated bottom nav shell — renders the iOS-26 "icon highlights
/// through the moving glass pill" effect.
///
/// **Not exported yet.** The animation polish for the liquid-glass
/// components is still in progress, so this variant is kept internal
/// and is only consumed by the package's own example/showcase. Once
/// the motion work is complete it can be promoted to the public API.
///
/// ## iOS-26 "icon highlights through the pill"
///
/// On iOS 26, when the moving glass pill passes over an icon, the
/// part of that icon *under* the pill renders in its selected
/// (filled / bright) state, while the part *outside* the pill stays
/// in its unselected (outlined / dim) state. The pill behaves like a
/// clipping window that reveals the selected icon underneath.
///
/// To get the same effect, pass [highlightFrac], [highlightWidth],
/// and [highlightHeight] from the same animation/jelly state you use
/// for [buildLiquidGlassBottomNavPill]. The shell will then render
/// each icon twice:
///   • An unselected layer clipped to "outside the pill"
///   • A selected layer clipped to "inside the pill"
///
/// Both layers share the exact same row layout, so they line up
/// perfectly — the pill-shaped boundary cuts cleanly between filled
/// and outlined as the pill slides.
///
/// When [highlightFrac] is `null` the shell falls back to a single
/// pass driven by [selectedIndex] (the legacy behaviour).
class LiquidGlassAnimatedBottomNavBarShell extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final LiquidGlassBottomNavBarLayout layout;

  /// Fractional index (`0..itemCount-1`) of the moving glass pill's
  /// center. Pass the same value you use for
  /// [buildLiquidGlassBottomNavPill]'s `animatedIndex` so the icon
  /// highlight tracks the pill exactly.
  ///
  /// `null` disables the iOS-26 dual-layer rendering and the shell
  /// falls back to highlighting only [selectedIndex].
  final double? highlightFrac;

  /// Current width of the moving glass pill (after any morph-grow
  /// and jelly-squeeze). Pass `layout.pillWidth + extraWidth` from
  /// [buildLiquidGlassBottomNavPill]'s caller.
  final double? highlightWidth;

  /// Current height of the moving glass pill (after any morph-grow
  /// and jelly-stretch). Pass `layout.cellHeight + extraHeight`.
  final double? highlightHeight;

  /// Absolute left of the bar in the parent. When non-null the shell is
  /// placed at this `left` (bottom-left anchored) instead of
  /// bottom-center — used to honor a custom bar position.
  final double? left;

  /// Absolute bottom inset of the bar. Defaults to `layout.bottomMargin`.
  final double? bottom;

  const LiquidGlassAnimatedBottomNavBarShell({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
    this.highlightFrac,
    this.highlightWidth,
    this.highlightHeight,
    this.left,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasHighlight = highlightFrac != null &&
        highlightWidth != null &&
        highlightHeight != null;

    final Widget innerStack = SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        children: [
          // ── Layer 1: unselected icons + labels ────────────
          // When no highlight is supplied, this is the only
          // layer and the selected tab is colored normally.
          // When highlight IS supplied we clip it to "outside
          // the pill" so the pill window can reveal the
          // selected layer behind it.
          if (hasHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: NavBarOutsidePillClipper(
                    pillRect: _pillRect(),
                    pillRadius: highlightHeight! / 2,
                  ),
                  child: NavBarIconRow(
                    items: items,
                    layout: layout,
                    forceUnselected: true,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: IgnorePointer(
                child: NavBarIconRow(
                  items: items,
                  layout: layout,
                  selectedIndex: selectedIndex,
                ),
              ),
            ),
          // ── Layer 2: selected icons + labels ──────────────
          // Only painted when a highlight is active. Clipped
          // to the pill rect so each icon "fills in" behind
          // the moving glass.
          if (hasHighlight)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: NavBarInsidePillClipper(
                    pillRect: _pillRect(),
                    pillRadius: highlightHeight! / 2,
                  ),
                  child: NavBarIconRow(
                    items: items,
                    layout: layout,
                    forceSelected: true,
                  ),
                ),
              ),
            ),
          // ── Tap handling ──────────────────────────────────
          // Sits on top of the icon layers but receives all
          // pointer events; the icon layers are wrapped in
          // IgnorePointer so they never compete.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(layout.padding),
              child: Row(
                children: [
                  for (int i = 0; i < items.length; i++)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () => onChanged(i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final double effBottom = bottom ?? layout.bottomMargin;
    if (left != null) {
      // Absolute bottom-left placement (honors a custom bar position).
      return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.only(left: left!, bottom: effBottom),
          child: innerStack,
        ),
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: effBottom),
        child: innerStack,
      ),
    );
  }

  /// The pill's rectangle in the shell's local coordinate space
  /// (origin at the shell's top-left, `layout.width × layout.height`).
  Rect _pillRect() {
    final pillW = highlightWidth!;
    final pillH = highlightHeight!;
    final cellW = layout.cellWidth;
    // Center of the cell at the fractional index, in local space.
    final cellCenterX =
        layout.padding + (highlightFrac! + 0.5) * cellW;
    // Bar's vertical center inside the local box.
    final cellCenterY = layout.height / 2;
    return Rect.fromCenter(
      center: Offset(cellCenterX, cellCenterY),
      width: pillW,
      height: pillH,
    );
  }
}
