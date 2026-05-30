import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_tab_bar.dart' show LiquidGlassTabBarItem;

/// A floating, drop-in liquid-glass bottom navigation bar.
///
/// This is the **non-animated**, release-ready bottom nav. It is a
/// single [LiquidGlass] lens (a capsule pinned to the bottom of its
/// parent) with the icons, labels, and a static selection highlight
/// baked into the lens `child` — so it composes in one line, exactly
/// like [LiquidGlassTabBar]:
///
/// ```dart
/// LiquidGlassView(
///   backgroundWidget: myPageContent,
///   children: [
///     LiquidGlassBottomNavBar(
///       items: const [
///         LiquidGlassTabBarItem(icon: Icons.home_outlined,
///             selectedIcon: Icons.home_rounded, label: 'Home'),
///         LiquidGlassTabBarItem(icon: Icons.search_rounded, label: 'Search'),
///         LiquidGlassTabBarItem(icon: Icons.person_outline,
///             selectedIcon: Icons.person_rounded, label: 'Profile'),
///       ],
///       selectedIndex: _index,
///       onChanged: (i) => setState(() => _index = i),
///     ),
///   ],
/// )
/// ```
///
/// The selection moves **instantly** between tabs (no slide / morph).
/// The animated counterpart is still being finished and is not part
/// of the public API yet.
///
/// Almost everything is customizable — size, position, glass tint and
/// blur, distortion, corner radius, the selection-pill color/visibility,
/// and the icon/label colors and sizes. See the constructor parameters.
class LiquidGlassBottomNavBar extends LiquidGlass {
  LiquidGlassBottomNavBar({
    required List<LiquidGlassTabBarItem> items,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
    super.controller,

    // ── Size & position ────────────────────────────────────
    super.width = 320,
    super.height = 64,

    /// Where the bar sits. Defaults to bottom-center with
    /// [bottomMargin] of breathing room. Pass any
    /// [LiquidGlassPosition] (e.g. [LiquidGlassOffsetPosition]) to
    /// override.
    LiquidGlassPosition? position,

    /// Bottom inset used only when [position] is `null`.
    double bottomMargin = 24,

    /// Inner padding between the capsule rim and the icon row.
    double itemPadding = 6,

    /// Corner radius of the capsule. Defaults to a full pill
    /// (`height / 2`).
    double? cornerRadius,

    // ── Glass look ─────────────────────────────────────────
    /// Base tint of the glass capsule.
    Color glassColor = const Color(0x16FFFFFF), // white, alpha 22
    super.blur = const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    super.distortion = 0.07,
    super.distortionWidth = 28,
    super.chromaticAberration = 0.002,
    super.magnification = 1,

    /// Border styling of the capsule rim.
    double borderWidth = 1.2,
    double lightIntensity = 1.1,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.2,
      ambientIntensity: 1.0,
      borderSolidity: 0.35,
    ),

    // ── Selection highlight ────────────────────────────────
    /// Whether to draw the soft pill behind the selected item.
    bool showSelectionPill = true,

    /// Color of the selection pill behind the active item.
    Color selectionColor = const Color(0x26FFFFFF), // white, alpha 38

    // ── Items ──────────────────────────────────────────────
    /// Color of the selected item's icon + label.
    Color selectedItemColor = Colors.white,

    /// Color of unselected items' icons + labels.
    Color unselectedItemColor = Colors.white70,

    /// Icon size for every item.
    double iconSize = 24,

    /// Label font size. Labels are only shown for items that
    /// provide a [LiquidGlassTabBarItem.label].
    double labelFontSize = 10.5,
    super.draggable = false,
    super.outOfBoundaries = false,
  })  : assert(items.isNotEmpty, 'Provide at least one item'),
        assert(selectedIndex >= 0 && selectedIndex < items.length,
            'selectedIndex out of range'),
        super(
          position: position ??
              LiquidGlassAlignPosition(
                alignment: Alignment.bottomCenter,
                margin: EdgeInsets.only(bottom: bottomMargin),
              ),
          color: glassColor,
          shape: RoundedRectangleShape(
            cornerRadius: cornerRadius ?? height / 2,
            borderWidth: borderWidth,
            lightIntensity: lightIntensity,
            lightDirection: lightDirection,
            borderType: borderType,
          ),
          child: _BottomNavBarContent(
            items: items,
            selectedIndex: selectedIndex,
            onChanged: onChanged,
            itemPadding: itemPadding,
            showSelectionPill: showSelectionPill,
            selectionColor: selectionColor,
            selectedItemColor: selectedItemColor,
            unselectedItemColor: unselectedItemColor,
            iconSize: iconSize,
            labelFontSize: labelFontSize,
          ),
        );
}

/// Crisp content layer (selection pill + icons + labels + taps)
/// drawn on top of the [LiquidGlassBottomNavBar] capsule, inside the
/// lens `child` so it is clipped to the capsule and stays sharp.
class _BottomNavBarContent extends StatelessWidget {
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

  const _BottomNavBarContent({
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
                    child: _BottomNavBarItem(
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

class _BottomNavBarItem extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final double iconSize;
  final double labelFontSize;
  final VoidCallback onTap;

  const _BottomNavBarItem({
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

/// Geometry shared between the bar shell, the bar lens, and the
/// moving selection pill of the liquid-glass bottom nav bar.
///
/// The animated bottom nav bar uses a dual liquid-glass pipeline: an
/// INNER view captures the wallpaper + bar capsule, and an OUTER
/// view composites the moving selection pill on top. The result is a
/// selection pill that refracts the bar capsule's own glass output
/// — the iOS-26 "morphing pill" feel.
///
/// The non-animated [LiquidGlassBottomNavBarShell] only needs this
/// for sizing; the moving-pill fields are consumed by the
/// (not-yet-exported) animated variant.
class LiquidGlassBottomNavBarLayout {
  final int itemCount;
  final double width;
  final double height;
  final double bottomMargin;
  final double padding;

  /// How much taller the moving selection pill is than the bar's
  /// inner cell height. A positive value makes the pill extend above
  /// and below the bar so it reads as a clear "raised" element.
  final double pillExtraHeight;

  const LiquidGlassBottomNavBarLayout({
    required this.itemCount,
    this.width = 280,
    this.height = 64,
    this.bottomMargin = 28,
    this.padding = 6,
    this.pillExtraHeight = 36,
  });

  double get cellWidth => (width - padding * 2) / itemCount;
  double get cellHeight => height - padding * 2;
  double get pillWidth => cellWidth;
  double get pillHeight => cellHeight + pillExtraHeight;
}

/// Static icons + labels on top of the bar capsule. Sits inside the
/// liquid-glass pipeline's `backgroundWidget` and owns the tap
/// handling.
///
/// This is the **non-animated**, release-ready bottom nav shell.
/// The selected tab is highlighted instantly (no moving glass pill,
/// no iOS-26 "icon fills through the pill" reveal). Compose it with
/// [buildLiquidGlassBottomNavCapsule] and, optionally,
/// [LiquidGlassBottomNavPillStatic] for the soft selection highlight.
///
/// The animated counterpart
/// ([LiquidGlassAnimatedBottomNavBarShell] +
/// [buildLiquidGlassBottomNavPill]) is intentionally **not exported**
/// while its motion work is still being finished.
///
/// **Important:** wrap this in [IgnorePointer] when you also place a
/// gesture overlay over the bar, otherwise the inner `InkWell`s will
/// race the overlay's drag recognizer.
class LiquidGlassBottomNavBarShell extends StatelessWidget {
  final List<LiquidGlassTabBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final LiquidGlassBottomNavBarLayout layout;

  const LiquidGlassBottomNavBarShell({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
  });

  @override
  Widget build(BuildContext context) {
    final Widget innerStack = SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        children: [
          // ── Icons + labels ────────────────────────────────
          // Single pass: the selected tab is colored normally.
          Positioned.fill(
            child: IgnorePointer(
              child: _IconRow(
                items: items,
                layout: layout,
                selectedIndex: selectedIndex,
              ),
            ),
          ),
          // ── Tap handling ──────────────────────────────────
          // Sits on top of the icon layer but receives all
          // pointer events; the icon layer is wrapped in
          // IgnorePointer so it never competes.
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: layout.bottomMargin),
        child: innerStack,
      ),
    );
  }
}

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

  const LiquidGlassAnimatedBottomNavBarShell({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    required this.layout,
    this.highlightFrac,
    this.highlightWidth,
    this.highlightHeight,
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
                  clipper: _OutsidePillClipper(
                    pillRect: _pillRect(),
                    pillRadius: highlightHeight! / 2,
                  ),
                  child: _IconRow(
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
                child: _IconRow(
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
                  clipper: _InsidePillClipper(
                    pillRect: _pillRect(),
                    pillRadius: highlightHeight! / 2,
                  ),
                  child: _IconRow(
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: layout.bottomMargin),
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

/// Single pass of icons + labels. Used both as the non-animated
/// single-layer renderer and as the dual-layer building block for
/// the iOS-26 highlight effect.
class _IconRow extends StatelessWidget {
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

  const _IconRow({
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
              child: _ShellTab(
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

class _ShellTab extends StatelessWidget {
  final LiquidGlassTabBarItem item;
  final bool selected;

  const _ShellTab({
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

/// Clips its child to the inside of the moving pill's rounded rect.
/// Used by the "selected icons" layer so each icon only paints in
/// the area currently under the pill.
class _InsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  const _InsidePillClipper({
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
  bool shouldReclip(_InsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius;
  }
}

/// Clips its child to "everything except the moving pill". Used by
/// the "unselected icons" layer so the parts of each icon not under
/// the pill stay outlined / dim.
class _OutsidePillClipper extends CustomClipper<Path> {
  final Rect pillRect;
  final double pillRadius;

  const _OutsidePillClipper({
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
  bool shouldReclip(_OutsidePillClipper oldClipper) {
    return oldClipper.pillRect != pillRect ||
        oldClipper.pillRadius != pillRadius;
  }
}

/// Builds the moving liquid-glass selection pill that slides across
/// the bar. Returns a [LiquidGlass] you place in the `children:` list
/// of the OUTER `LiquidGlassView`.
///
/// **Not exported yet** — this is part of the animated bottom nav
/// bar, whose motion work is still in progress. It is consumed only
/// by the package's own example/showcase.
///
/// Pass [animatedIndex] as a fractional value between `0` and
/// `items.length - 1` so the pill can be animated between tabs by
/// the caller (typically via an `AnimationController` running a
/// `Tween<double>` between the previous and next index).
///
/// [extraHeight] overrides the layout's default pill-extra-height
/// for this single frame. Animate it from `0` →
/// `layout.pillExtraHeight` → `0` to make the pill grow out of and
/// shrink back into the static selection highlight, the way iOS
/// does on tap.
///
/// [extraWidth] adds horizontal stretch to the pill — useful for
/// the jelly effect during a drag. Always grows symmetrically (left
/// and right) so the pill stays centered on its base index.
LiquidGlass buildLiquidGlassBottomNavPill({
  required LiquidGlassBottomNavBarLayout layout,
  required double animatedIndex,
  required double parentWidth,
  double? extraHeight,
  double extraWidth = 0,
}) {
  final extra = extraHeight ?? layout.pillExtraHeight;
  final cellW = layout.cellWidth;
  final barLeft = (parentWidth - layout.width) / 2;
  final pillLeft = barLeft + layout.padding + animatedIndex * cellW;
  // Center the pill (which may be taller than the cell) vertically
  // over the bar's inner row.
  final pillBottom = layout.bottomMargin + layout.padding - extra / 2;
  final pillH = layout.cellHeight + extra;
  final pillW = layout.pillWidth + extraWidth;
  // Center the extra width on the index so the pill doesn't drift
  // when stretching.
  final adjustedLeft = pillLeft - extraWidth / 2;

  return LiquidGlass(
    position: LiquidGlassOffsetPosition(
      left: adjustedLeft,
      bottom: pillBottom,
    ),
    width: pillW,
    height: pillH,
    magnification: 1,
    distortion: 0.06,
    distortionWidth: 10,
    chromaticAberration: 0.002,
    color: Colors.white.withAlpha(28),
    blur: const LiquidGlassBlur(sigmaX: 1.5, sigmaY: 1.5),
    shape: RoundedRectangleShape(
      cornerRadius: pillH / 2,
      borderWidth: 1.0,
      lightIntensity: 1.3,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.4,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    ),
  );
}

/// Builds the long bar-capsule lens. Place it in the `children:`
/// list of the INNER `LiquidGlassView`. It refracts the wallpaper
/// that the inner view captures, and contributes its glass
/// appearance to the outer view's snapshot — so the selection pill
/// (built with [buildLiquidGlassBottomNavPill]) running in the
/// OUTER view refracts the bar's glass output.
LiquidGlass buildLiquidGlassBottomNavCapsule({
  required LiquidGlassBottomNavBarLayout layout,
}) {
  return LiquidGlass(
    position: LiquidGlassAlignPosition(
      alignment: Alignment.bottomCenter,
      margin: EdgeInsets.only(bottom: layout.bottomMargin),
    ),
    width: layout.width,
    height: layout.height,
    magnification: 1,
    distortion: 0.07,
    distortionWidth: 28,
    chromaticAberration: 0.002,
    color: Colors.white.withAlpha(22),
    blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
    shape: RoundedRectangleShape(
      cornerRadius: layout.height / 2,
      borderWidth: 1.2,
      lightIntensity: 1.1,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 1.2,
        ambientIntensity: 1.0,
        borderSolidity: 0.35,
      ),
    ),
  );
}

/// Plain (non-shader) version of the selection pill, used while the
/// pill is at rest. Visually mimics the optical-rim look of the
/// liquid-glass pill so swapping between the two is unnoticeable.
class LiquidGlassBottomNavPillStatic extends StatelessWidget {
  final double width;
  final double height;

  const LiquidGlassBottomNavPillStatic({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(38),
          borderRadius: BorderRadius.circular(height / 2),
          // No border — only the moving liquid-glass pill carries
          // the optical rim. The static rest pill is meant to look
          // like a soft highlight, not a framed shape.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}
