import 'package:flutter/material.dart';

import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;
import 'liquid_glass_nav_bar_layout.dart';

/// Single pass of icons + labels. Used both as the non-animated
/// single-layer renderer and as the dual-layer building block for
/// the iOS-26 highlight effect.
class NavBarIconRow extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final LiquidGlassBottomNavBarLayout layout;

  /// When supplied, the matching cell renders in its selected
  /// state. Ignored when [forceSelected] or [forceUnselected] is
  /// true.
  final int? selectedIndex;

  /// All cells render in their selected state. Used by the
  /// "inside-the-pill" layer.
  final bool forceSelected;

  /// All cells render in their unselected state. Used by the
  /// "outside-the-pill" layer.
  final bool forceUnselected;

  const NavBarIconRow({
    super.key,
    required this.items,
    required this.layout,
    this.selectedIndex,
    this.forceSelected = false,
    this.forceUnselected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(layout.padding),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: NavBarShellTab(
                item: items[i],
                selected: forceSelected
                    ? true
                    : forceUnselected
                        ? false
                        : i == selectedIndex,
              ),
            ),
        ],
      ),
    );
  }
}

class NavBarShellTab extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;

  const NavBarShellTab({
    super.key,
    required this.item,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white70;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? (item.selectedIcon ?? item.icon) : item.icon,
            size: 24,
            color: color,
          ),
          if (item.label != null) ...[
            const SizedBox(height: 2),
            Text(
              item.label!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
