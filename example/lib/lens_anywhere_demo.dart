import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Demo for the lens-anywhere API ([LiquidGlassLens]).
///
/// Run directly:
///   flutter run -t lib/lens_anywhere_demo.dart
///
/// Two pages:
///  1. "Standalone" — lenses dropped straight into a plain widget tree,
///     NO LiquidGlassView and NO background param. On Impeller they
///     refract whatever is behind them; on Skia they show the frosted
///     fallback.
///  2. "In a view" — lenses living inside a `LiquidGlassView.child`
///     scrollable, refracting the view's captured background on Skia
///     and the live backdrop on Impeller. Same widget code.
void main() => runApp(const LensAnywhereDemoApp());

class LensAnywhereDemoApp extends StatelessWidget {
  const LensAnywhereDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _DemoHome(),
    );
  }
}

class _DemoHome extends StatefulWidget {
  const _DemoHome();

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page == 0 ? const _StandalonePage() : const _InViewPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _page,
        onTap: (i) => setState(() => _page = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome), label: 'Standalone'),
          BottomNavigationBarItem(
              icon: Icon(Icons.view_quilt), label: 'In a view'),
        ],
      ),
    );
  }
}

/// A colorful busy background so refraction is obvious.
class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
            Color(0xFF904E95),
            Color(0xFFE96443),
          ],
        ),
      ),
      child: Stack(
        children: [
          for (int i = 0; i < 14; i++)
            Positioned(
              left: (i * 73) % 320 + 10.0,
              top: (i * 131) % 640 + 20.0,
              child: Container(
                width: 60 + (i * 17) % 80,
                height: 60 + (i * 29) % 80,
                decoration: BoxDecoration(
                  shape: i.isEven ? BoxShape.circle : BoxShape.rectangle,
                  color: Colors
                      .primaries[i % Colors.primaries.length]
                      .withValues(alpha: 0.55),
                ),
              ),
            ),
          const Center(
            child: Text(
              'liquid\nglass',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w900,
                color: Colors.white24,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page 1: no LiquidGlassView at all. The lenses sit in a plain Stack
/// over arbitrary UI. Impeller-only refraction (frosted on Skia).
class _StandalonePage extends StatelessWidget {
  const _StandalonePage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _Background(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 260,
                height: 130,
                child: LiquidGlassLens(
                  shape: const RoundedRectangleShape(
                    cornerRadius: 40,
                    cornerSmoothing: 1.0,
                  ),
                  refraction: const LiquidGlassRefraction(
                    distortion: 0.12,
                    distortionWidth: 32,
                  ),
                  child: const Center(
                    child: Text(
                      'no background param,\nno LiquidGlassView',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                height: 90,
                child: LiquidGlassLens(
                  shape: const RoundedRectangleShape(cornerRadius: 45),
                  refraction: const LiquidGlassRefraction(
                    distortion: 0.2,
                    distortionWidth: 24,
                    magnification: 1.1,
                  ),
                  appearance: const LiquidGlassAppearance(
                    blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
                    color: Color(0x14FFFFFF),
                  ),
                  child: const Center(
                    child: Text('blur + tint',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page 2: lenses living inside a LiquidGlassView's `child` scrollable.
/// On Skia the view captures `backgroundWidget` and the lenses refract
/// it from wherever the scroll puts them; on Impeller they refract the
/// live backdrop. Identical widget code either way.
class _InViewPage extends StatelessWidget {
  const _InViewPage();

  @override
  Widget build(BuildContext context) {
    return LiquidGlassView(
      backgroundWidget: const _Background(),
      // IMPORTANT: Android's stretch overscroll isolates the scrollable
      // into its own layer, which blinds BackdropFilter-based lenses on
      // Impeller (they sample transparent → render black) while the
      // stretch plays. Disable the overscroll indicator for scrollables
      // that contain lenses.
      child: ScrollConfiguration(
        behavior:
            const MaterialScrollBehavior().copyWith(overscroll: false),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
          children: [
            for (int i = 0; i < 8; i++) ...[
              SizedBox(
                height: 110,
                child: LiquidGlassLens(
                  shape: RoundedRectangleShape(
                    cornerRadius: 28 + (i % 3) * 14.0,
                    cornerSmoothing: 1.0,
                  ),
                  refraction: const LiquidGlassRefraction(
                    distortion: 0.12,
                    distortionWidth: 28,
                  ),
                  child: Center(
                    child: Text(
                      'scrolling lens #${i + 1}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }
}
