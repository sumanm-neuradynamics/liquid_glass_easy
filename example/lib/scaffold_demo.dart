import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Standalone entry point so this demo can be launched directly with:
///   flutter run -t lib/scaffold_demo.dart
void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
            showPerformanceOverlay: true,

      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const ScaffoldDemo(),
    ),
  );
}

/// Minimal end-to-end demo of [LiquidGlassScaffold]: an app bar, a
/// bottom nav bar, and a side action button — all floating glass over
/// a scrolling photo body, with zero manual `LiquidGlassView` wiring.
///
/// Works unchanged on both Skia and Impeller (the renderer is picked
/// automatically).
class ScaffoldDemo extends StatefulWidget {
  const ScaffoldDemo({super.key});

  @override
  State<ScaffoldDemo> createState() => _ScaffoldDemoState();
}

class _ScaffoldDemoState extends State<ScaffoldDemo> {
  int _index = 0;

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
    return LiquidGlassScaffold(
      // ── body becomes the captured background ──────────────
      pixelRatio:1,
      useSync:true,
      body: ListView.separated(
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
      ),

      // ── floating glass app bar ────────────────────────────
      // The scaffold clears the status bar automatically (safeArea).
      appBar: LiquidGlassAppBar(
        leading: const Icon(Icons.menu_rounded),
        title: const Text('Discover'),
        actions: const [Icon(Icons.search_rounded)],
      ),

      // ── floating glass bottom nav bar ─────────────────────
      bottomNavigationBar: LiquidGlassBottomNavBar(
        items: _items,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        // Glass-refracting morphing pill on Impeller; soft sliding
        // highlight (animated) as the Skia fallback.
        pillStyle: const LiquidGlassNavPillStyle(
          mode: LiquidGlassPillMode.both,
          animated: true,
          growHeight: 15,
          distortion: 0.05,
          distortionWidth: 12,
        ),
        // Custom position is now honored by the glass-pill bar too.
        position: const LiquidGlassAlignPosition(
          alignment: Alignment.bottomLeft,
          margin: EdgeInsets.only(bottom: 20, left: 20),
        ),
        width: 260,
      ),

      // ── the "alone" side action button next to the nav bar ─
      bottomNavigationBarAction: LiquidGlassTabBarAction(
        position: const LiquidGlassAlignPosition(
          alignment: Alignment.bottomRight,
          // Vertically center it on the nav bar (height 64, margin 24).
          margin: EdgeInsets.only(right: 16, bottom: 24),
        ),
        icon: Icons.add_rounded,
        onTap: () {},
      ),
    );
  }
}
