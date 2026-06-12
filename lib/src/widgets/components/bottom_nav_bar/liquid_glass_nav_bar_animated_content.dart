import 'package:flutter/material.dart';

import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_nav_bar_pill_clippers.dart';

/// Animated content layer for [LiquidGlassBottomNavBar] when
/// `animated: true`.
///
/// Owns its own [AnimationController] and runs the whole effect inside
/// the lens `child`, so nothing is required from the caller and it
/// composites identically on Skia and Impeller:
///   • the soft selection pill **slides** from the old tab to the new
///     one along [curve], and
///   • the icon currently under the pill renders in its selected
///     (filled / bright) state while the rest stays unselected — the
///     iOS-26 "icon highlights through the moving pill" reveal —
///     implemented by drawing the icon row twice and clipping one copy
///     to the inside of the moving pill and the other to the outside.
class AnimatedBottomNavBarContent extends StatefulWidget {
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double itemPadding;
  final bool showSelectionPill;
  final Color selectionColor;
  final Color selectedItemColor;
  final Color unselectedItemColor;
  final double iconSize;
  final double labelFontSize;
  final Duration duration;
  final Curve curve;

  const AnimatedBottomNavBarContent({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.itemPadding,
    required this.showSelectionPill,
    required this.selectionColor,
    required this.selectedItemColor,
    required this.unselectedItemColor,
    required this.iconSize,
    required this.labelFontSize,
    required this.duration,
    required this.curve,
  });

  @override
  State<AnimatedBottomNavBarContent> createState() =>
      _AnimatedBottomNavBarContentState();
}

class _AnimatedBottomNavBarContentState
    extends State<AnimatedBottomNavBarContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Fractional index the pill is travelling **from**.
  late double _fromIndex;

  /// Fractional index the pill is travelling **to** (the committed
  /// [LiquidGlassBottomNavBar.selectedIndex]).
  late double _toIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex.toDouble();
    _toIndex = _fromIndex;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1, // start settled on the initial selection
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedBottomNavBarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      // Animate from wherever the pill currently is (so a tap during a
      // slide is handled gracefully) to the new selection.
      _fromIndex = _currentIndex;
      _toIndex = widget.selectedIndex.toDouble();
      _controller.forward(from: 0);
    }
  }

  /// The pill's fractional index at this instant.
  double get _currentIndex {
    final t = widget.curve.transform(_controller.value);
    return _fromIndex + (_toIndex - _fromIndex) * t;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The lens `child` subtree has no ambient Material, so wrap it in a
    // transparent one — this provides the [DefaultTextStyle] the labels
    // need (otherwise they render with the debug yellow underline) and
    // the ink surface for the tap targets.
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.all(widget.itemPadding),
        child: LayoutBuilder(builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / widget.items.length;
        final cellHeight = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final frac = _currentIndex;
            final pillRect = Rect.fromLTWH(
              frac * cellWidth,
              0,
              cellWidth,
              cellHeight,
            );
            final pillRadius = cellHeight / 2;
            return Stack(
              children: [
                // Moving selection pill — slides behind the icons.
                // A soft fill plus a faint rim + shadow so it reads as a
                // raised glass pill rather than a barely-there tint.
                if (widget.showSelectionPill)
                  Positioned.fromRect(
                    rect: pillRect,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.selectionColor,
                        borderRadius: BorderRadius.circular(pillRadius),
                        border: Border.all(
                          color: Colors.white.withAlpha(70),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(28),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Unselected icon row, clipped to OUTSIDE the pill.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: NavBarOutsidePillClipper(
                        pillRect: pillRect,
                        pillRadius: pillRadius,
                      ),
                      child: _animatedIconRow(forceSelected: false),
                    ),
                  ),
                ),
                // Selected icon row, clipped to INSIDE the pill — this
                // is the part that "fills in" as the pill passes over.
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: NavBarInsidePillClipper(
                        pillRect: pillRect,
                        pillRadius: pillRadius,
                      ),
                      child: _animatedIconRow(forceSelected: true),
                    ),
                  ),
                ),
                // Tap layer on top — owns all pointer events.
                Positioned.fill(
                  child: Row(
                    children: [
                      for (int i = 0; i < widget.items.length; i++)
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () => widget.onChanged(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
        }),
      ),
    );
  }

  /// One full row of icons + labels, all rendered in their selected
  /// or unselected state. The two copies (selected / unselected) share
  /// the exact same layout, so the pill-shaped clip cuts cleanly
  /// between filled and outlined.
  Widget _animatedIconRow({required bool forceSelected}) {
    return Row(
      children: [
        for (final item in widget.items)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    forceSelected
                        ? (item.selectedIcon ?? item.icon)
                        : item.icon,
                    size: widget.iconSize,
                    color: forceSelected
                        ? widget.selectedItemColor
                        : widget.unselectedItemColor,
                  ),
                  if (item.label != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.label!,
                      style: TextStyle(
                        fontSize: widget.labelFontSize,
                        fontWeight: forceSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: forceSelected
                            ? widget.selectedItemColor
                            : widget.unselectedItemColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
