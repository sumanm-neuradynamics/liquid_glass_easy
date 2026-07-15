import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../utils/liquid_glass_shape.dart';
import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_nav_bar_icon_row.dart';
import 'liquid_glass_nav_bar_pill.dart';
import 'liquid_glass_nav_bar_pill_clippers.dart';
import 'liquid_glass_nav_bar_style.dart';

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
  final LiquidGlassNavItemStyle itemStyle;
  final Duration duration;
  final Curve curve;

  /// Corner shape (and optional border) of the sliding selection pill —
  /// drives the pill fill, its rim (via the shape's `borderColor`), and
  /// the icon-reveal clip. When `null`, a plain capsule is used.
  final LiquidGlassShape? pillShape;

  const AnimatedBottomNavBarContent({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.itemPadding,
    required this.showSelectionPill,
    required this.selectionColor,
    required this.itemStyle,
    required this.duration,
    required this.curve,
    this.pillShape,
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

          // The pill hugs just the icon (Material-3-style icon indicator)
          // instead of the whole icon+label cell, so it sits as a small
          // circle behind the glyph and leaves the label uncovered.
          final iconSize = widget.itemStyle.iconSize;
          final hasLabel = widget.items.any((it) => it.label != null);
          // Approximate the label's line height from its font size —
          // close enough to line the icon up with where it sits in the
          // real icon+label column below.
          final labelBlockHeight = hasLabel
              ? widget.itemStyle.iconLabelGap +
                  widget.itemStyle.labelFontSize * 1.2
              : 0.0;
          final columnHeight = iconSize + labelBlockHeight;
          final pillDiameter =
              math.min(iconSize + 18, math.min(cellWidth, cellHeight));
          final iconCenterY = ((cellHeight - columnHeight) / 2 + iconSize / 2)
              .clamp(pillDiameter / 2, cellHeight - pillDiameter / 2);

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final frac = _currentIndex;
              final pillRect = Rect.fromCenter(
                center: Offset(frac * cellWidth + cellWidth / 2, iconCenterY),
                width: pillDiameter,
                height: pillDiameter,
              );
              final pillRadius = pillDiameter / 2;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Moving selection pill — slides behind the icons.
                  // A soft fill; any rim comes from the pill shape's
                  // `borderColor` (no fake drop shadow).
                  if (widget.showSelectionPill)
                    Positioned.fromRect(
                      rect: pillRect,
                      child: CustomPaint(
                        painter: LiquidGlassNavPillSurfacePainter(
                          color: widget.selectionColor,
                          shape: widget.pillShape,
                        ),
                      ),
                    ),
                  // Unselected icons, clipped to OUTSIDE the pill. Labels
                  // are hidden here — they're drawn once, unclipped, below.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipPath(
                        clipper: NavBarOutsidePillClipper(
                          pillRect: pillRect,
                          pillRadius: pillRadius,
                          shape: widget.pillShape,
                        ),
                        child: _animatedIconRow(
                          forceSelected: false,
                          hideLabel: true,
                        ),
                      ),
                    ),
                  ),
                  // Selected icons, clipped to INSIDE the pill — this is
                  // the part that "fills in" as the pill passes over.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipPath(
                        clipper: NavBarInsidePillClipper(
                          pillRect: pillRect,
                          pillRadius: pillRadius,
                          shape: widget.pillShape,
                        ),
                        child: _animatedIconRow(
                          forceSelected: true,
                          hideLabel: true,
                        ),
                      ),
                    ),
                  ),
                  // Labels — a single unclipped pass, colored by the real
                  // committed selection (not the pill's travel fraction),
                  // since the pill no longer covers them.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _labelRow(),
                    ),
                  ),
                  // Tap layer on top — owns all pointer events.
                  Positioned.fill(
                    child: NavBarTapRow(
                      itemCount: widget.items.length,
                      onChanged: widget.onChanged,
                      cellHeight: cellHeight,
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
  Widget _animatedIconRow({required bool forceSelected, bool hideLabel = false}) {
    return Row(
      children: [
        for (final item in widget.items)
          Expanded(
            child: LiquidGlassNavTabCell(
              item: item,
              selected: forceSelected,
              style: widget.itemStyle,
              hideLabel: hideLabel,
            ),
          ),
      ],
    );
  }

  /// The label-only pass: icons hidden, colored by the real committed
  /// selection rather than the pill's travel fraction.
  Widget _labelRow() {
    return Row(
      children: [
        for (int i = 0; i < widget.items.length; i++)
          Expanded(
            child: LiquidGlassNavTabCell(
              item: widget.items[i],
              selected: i == widget.selectedIndex,
              style: widget.itemStyle,
              hideIcon: true,
            ),
          ),
      ],
    );
  }
}
