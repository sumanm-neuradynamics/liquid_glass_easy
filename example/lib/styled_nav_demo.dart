import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// Sandbox imports — the styled nav bar + shared style groups are not part of
// the public API yet, so reach into src directly for this standalone test.
import 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_nav_bar_layout.dart'
    show LiquidGlassBottomNavBarLayout;
import 'package:liquid_glass_easy/src/widgets/components/styled/liquid_glass_styled_nav_bar.dart';
import 'package:liquid_glass_easy/src/widgets/components/styled/liquid_glass_styles.dart';

/// Standalone test for the GROUPED/categorized nav-bar API. Launch with:
///   flutter run -t lib/styled_nav_demo.dart
///
/// This drives [LiquidGlassStyledNavBar] directly (no scaffold) and feeds it
/// the shared style groups. Toggle [customize] to compare the default look
/// (bit-for-bit the shipping bar) against fully-restyled values that the old
/// glass-pill path used to silently drop.
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const StyledNavDemo(),
    ),
  );
}

class StyledNavDemo extends StatefulWidget {
  const StyledNavDemo({super.key});

  @override
  State<StyledNavDemo> createState() => _StyledNavDemoState();
}

class _StyledNavDemoState extends State<StyledNavDemo> {
  int _index = 0;

  /// Flip to false to render the groups at their defaults (should match the
  /// existing animated nav bar exactly).
  bool _customize = true;

  static const _items = [
    LiquidGlassTabBarItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: 'Explore',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      label: 'You',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;

    // The page content captured behind the glass.
    final body = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 92, 16, 120),
      itemCount: 12,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          'https://picsum.photos/seed/$i/800/480',
          height: 180,
          fit: BoxFit.cover,
        ),
      ),
    );

    // Previously-dropped fields, now passed as optional config-group
    // overrides. `null` (the default branch) keeps the bar's supplied default.
    final refraction =
        _customize ? const LiquidGlassRefraction(distortion: 0.10) : null;
    final appearance = _customize
        ? const LiquidGlassAppearance(
            color: Color(0x2200E5FF), // tinted cyan capsule
            blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
          )
        : null;
    final shape = _customize
        ? const RoundedRectangleShape(
            cornerRadius: 32,
            borderWidth: 1.2,
            lightIntensity: 1.1,
            lightDirection: 80,
            borderType: OpticalBorder(
              borderSaturation: 1.6,
              ambientIntensity: 1.0,
              borderSolidity: 0.5,
            ),
          )
        : null;

    final itemStyle = _customize
        ? const LiquidGlassNavBarItemStyle(
            selectedItemColor: Color(0xFF00E5FF),
            unselectedItemColor: Colors.white60,
            iconSize: 26,
            labelFontSize: 11,
            selectionColor: Color(0x3300E5FF),
          )
        : const LiquidGlassNavBarItemStyle();

    final motion = _customize
        ? const LiquidGlassMotion(
            duration: Duration(milliseconds: 480),
            curve: Curves.easeOutBack,
          )
        : const LiquidGlassMotion();

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _customize = !_customize),
        label: Text(_customize ? 'Custom groups' : 'Default groups'),
        icon: const Icon(Icons.style),
      ),
      body: LiquidGlassStyledNavBar(
        body: body,
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        layout: LiquidGlassBottomNavBarLayout(
          itemCount: _items.length,
          width: 300,
          height: 64,
          bottomMargin: 24 + pad.bottom,
          padding: 6,
        ),
        refraction: refraction,
        appearance: appearance,
        shape: shape,
        itemStyle: itemStyle,
        motion: motion,
        pill: const LiquidGlassNavPillStyle(
          growHeight: 15,
          distortion: 0.05,
          distortionWidth: 12,
        ),
      ),
    );
  }
}
