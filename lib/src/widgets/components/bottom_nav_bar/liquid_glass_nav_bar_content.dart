import 'package:flutter/material.dart';

import '../liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;

/// Crisp content layer (selection pill + icons + labels + taps)
/// drawn on top of the [LiquidGlassBottomNavBar] capsule, inside the
/// lens `child` so it is clipped to the capsule and stays sharp.
class BottomNavBarContent extends StatelessWidget {
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

  const BottomNavBarContent({
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
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(itemPadding),
      child: LayoutBuilder(builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / items.length;
        final cellHeight = constraints.maxHeight;
        return Stack(
          children: [
            // Static selection pill — jumps instantly to the
            // selected cell (no slide). Sits behind the icons.
            if (showSelectionPill)
              Positioned(
                left: selectedIndex * cellWidth,
                top: 0,
                bottom: 0,
                width: cellWidth,
                child: Center(
                  child: Container(
                    width: cellWidth,
                    height: cellHeight,
                    decoration: BoxDecoration(
                      color: selectionColor,
                      borderRadius:
                          BorderRadius.circular(cellHeight / 2),
                    ),
                  ),
                ),
              ),
            // Icon + label row with tap handling.
            Row(
              children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: BottomNavBarItem(
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
    );
  }
}

class BottomNavBarItem extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final double iconSize;
  final double labelFontSize;
  final VoidCallback onTap;

  const BottomNavBarItem({
    super.key,
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
