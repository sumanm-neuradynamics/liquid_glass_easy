import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// LiquidGlassLens over a background image.
//
// A photo fills the screen and a few `LiquidGlassLens` widgets float on
// top of it — a wide "now playing" card, a circular lens and a capsule
// chip. On Impeller each lens refracts the live photo behind it; on
// Skia/Web it degrades to a frosted look (see LiquidGlassLens docs).
//
//   flutter run -t lib/lens_image_page.dart   (standalone)
//   …or open it from the gallery.
// =============================================================

void main() {
  runApp(const _LensImageApp());
}

class _LensImageApp extends StatelessWidget {
  const _LensImageApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const LensImagePage(),
    );
  }
}

/// A page showcasing [LiquidGlassLens] over a photographic background.
class LensImagePage extends StatelessWidget {
  const LensImagePage({super.key});

  // A full-body person on a city street — portrait crop so the whole
  // figure fills the screen under BoxFit.cover, with busy street detail
  // that makes the refraction easy to read as the lens passes over it.
  static const String _imageUrl =
      'https://images.unsplash.com/photo-1485968579580-b6d095142e6e'
      '?auto=format&fit=crop&w=900&h=1600&q=80';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Lens over image'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // LiquidGlassView provides the captured background the lenses
      // refract. On Impeller it renders normally and the live backdrop is
      // sampled; on Skia / Web this is the capture source (so the lenses
      // refract even without Impeller).
      body: LiquidGlassView(
        backgroundWidget: const _Background(url: _imageUrl),
        // Lenses placed anywhere inside `child` connect to this view
        // automatically. Each is wrapped in a LiquidGlassDraggable.
        child: SafeArea(
          child: Stack(
            children: const [
              Positioned(
                left: 20,
                right: 20,
                top: 80,
                child: LiquidGlassDraggable(child: _NowPlayingCard()),
              ),
              Positioned(
                left: 30,
                top: 260,
                child: LiquidGlassDraggable(child: _CircleLens()),
              ),
              Positioned(
                right: 30,
                top: 260,
                child: LiquidGlassDraggable(child: _SquircleLens()),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 410,
                child: Center(
                  child: LiquidGlassDraggable(child: _GlassChip()),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Text(
                  'Drag any glass card around over the photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The refractable background captured by [LiquidGlassView]: the network
/// photo (with a gradient fallback) plus a soft scrim so white text on the
/// glass stays readable. Folding the scrim in here means the lenses refract
/// the scrimmed photo on the Skia capture path too.
class _Background extends StatelessWidget {
  final String url;
  const _Background({required this.url});

  static const _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E1065), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Stack(
              fit: StackFit.expand,
              children: const [
                _fallback,
                Center(child: CircularProgressIndicator(color: Colors.white)),
              ],
            );
          },
        ),
        // Soft scrim for text legibility.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x33000000), Color(0x66000000)],
            ),
          ),
        ),
      ],
    );
  }
}

/// A wide glass card — the headline lens.
class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: LiquidGlassLens(
        style: const LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 36,lightDirection: 39),
          appearance: LiquidGlassAppearance(color: Color(0x14FFFFFF)),
          refraction: LiquidGlassRefraction(
            refractionMode: LiquidGlassRefractionMode.radialRefraction,
            refractionType: OpticalRefraction(
              refraction: 1.5, // IOR — bend angle (useful ~1.0–2.0)
              refractionWidth: 30, // edge band width
              depth: 0.5, // strength — how much it bends
            ),
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liquid Glass',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Refraction over a live photo',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circular lens — a continuous rounded rect at full radius is a circle.
class _CircleLens extends StatelessWidget {
  const _CircleLens();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: LiquidGlassLens(
        style: const LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 60),
          refraction: LiquidGlassRefraction(
            distortion: 0.18,
            magnification: 1.1,
          ),
        ),
        child: const Center(
          child: Icon(Icons.favorite_rounded, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

/// A squircle lens.
class _SquircleLens extends StatelessWidget {
  const _SquircleLens();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: LiquidGlassLens(
        style: const LiquidGlassStyle(
          shape: LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: 36,
            lightDirection: 39,
            lightIntensity: 3,
            borderWidth: 0,
            borderType: OpticalBorder(
              borderSolidity: 1, // light-driven solid rim
              borderSaturation: 0.7, // desaturate the rim colour
            ),
          ),
          appearance: LiquidGlassAppearance(color: Color(0x14FFFFFF)),
          refraction: LiquidGlassRefraction(
            refractionMode: LiquidGlassRefractionMode.shapeRefraction,
            refractionType: OpticalRefraction(
              refraction: 1.5, // IOR — bend angle (useful ~1.0–2.0)
              refractionWidth: 20, // edge band width
              depth: 1, // strength — how much it bends
            ),
          ),
        ),
        child: const Center(
          child: Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

/// A capsule chip lens.
class _GlassChip extends StatelessWidget {
  const _GlassChip();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 56,
        width: 220,
        child: LiquidGlassLens(
          style: const LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: 28,
            ),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tap to explore',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
