import 'package:flutter/material.dart';

/// Clips its child to the inside of the moving pill's rounded rect.
/// Used by the "selected icons" layer so each icon only paints in
/// the area currently under the pill.
class NavBarInsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  const NavBarInsidePillClipper({
    required this.pillRect,
    required this.pillRadius,
  });

  @override
  Path getClip(Size size) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        pillRect,
        Radius.circular(pillRadius),
      ));
  }

  @override
  bool shouldReclip(NavBarInsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius;
  }
}

/// Clips its child to "everything except the moving pill". Used by
/// the "unselected icons" layer so the parts of each icon not under
/// the pill stay outlined / dim.
class NavBarOutsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  const NavBarOutsidePillClipper({
    required this.pillRect,
    required this.pillRadius,
  });

  @override
  Path getClip(Size size) {
    final full = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final pill = Path()
      ..addRRect(RRect.fromRectAndRadius(
        pillRect,
        Radius.circular(pillRadius),
      ));
    return Path.combine(PathOperation.difference, full, pill);
  }

  @override
  bool shouldReclip(NavBarOutsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius;
  }
}
