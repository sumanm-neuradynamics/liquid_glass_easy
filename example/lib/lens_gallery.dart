import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Liquid Glass Easy — 7-page test gallery for the new API.
//
//   flutter run -t lib/lens_gallery.dart
//
// Each page exercises a DIFFERENT situation of the lens-anywhere v3
// API so you can eyeball every code path on a real device:
//
//   1. Anywhere   — standalone LiquidGlassLens, no view, no background.
//   2. In a View  — LiquidGlassLens inside LiquidGlassView.child,
//                   refracting the captured backgroundWidget (Skia path).
//   3. Draggable  — the classic LiquidGlass children API + drag.
//   4. Scrolling  — lenses inside a scrollable feed (overscroll off).
//   5. Live       — lenses over a continuously animating background.
//   6. Show/Hide  — the visibility melt animation, toggled live.
//   7. Controls   — the grouped-API components (slider / toggle / button).
//
// On Impeller every page refracts for real. On Skia, the standalone
// pages (1, 4, 5, 6) fall back to frosted glass — that's expected; the
// in-view pages (2, 3, 7) refract their captured background instead.
// =============================================================

void main() => runApp(const LensGalleryApp());

class LensGalleryApp extends StatelessWidget {
  const LensGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _GalleryHome(),
    );
  }
}

class _GalleryHome extends StatefulWidget {
  const _GalleryHome();

  @override
  State<_GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<_GalleryHome> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _titles = [
    'Anywhere',
    'In a View',
    'Draggable',
    'Scrolling',
    'Live',
    'Show / Hide',
    'Controls',
  ];

  late final List<Widget> _pages = const [
    AnywherePage(),
    InViewPage(),
    DraggablePage(),
    ScrollingPage(),
    LivePage(),
    ShowHidePage(),
    ControlsPage(),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _page = i),
        children: _pages,
      ),
      bottomNavigationBar: _ChipBar(
        titles: _titles,
        selected: _page,
        onTap: _go,
      ),
    );
  }
}

/// Horizontally-scrollable selector so all 7 page names fit on a phone.
class _ChipBar extends StatelessWidget {
  final List<String> titles;
  final int selected;
  final ValueChanged<int> onTap;

  const _ChipBar({
    required this.titles,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: titles.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final active = i == selected;
            return GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${i + 1}. ${titles[i]}',
                  style: TextStyle(
                    color: active ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================
// Shared backgrounds (all in-code, offline-safe)
// =============================================================

/// A static, busy mesh-gradient + floating shapes — refraction reads
/// clearly over it.
class MeshBackground extends StatelessWidget {
  final List<Color> colors;
  final int seed;
  const MeshBackground({
    super.key,
    this.colors = const [
      Color(0xFF0F2027),
      Color(0xFF2C5364),
      Color(0xFF8E2DE2),
      Color(0xFFFF6B6B),
    ],
    this.seed = 7,
  });

  @override
  Widget build(BuildContext context) {
    final rnd = math.Random(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          for (int i = 0; i < 16; i++)
            Positioned(
              left: rnd.nextDouble() * 340,
              top: rnd.nextDouble() * 720,
              child: Container(
                width: 40 + rnd.nextDouble() * 90,
                height: 40 + rnd.nextDouble() * 90,
                decoration: BoxDecoration(
                  shape: i.isEven ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius:
                      i.isEven ? null : BorderRadius.circular(24),
                  color: Colors
                      .primaries[i % Colors.primaries.length]
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A crisp text+grid background so distortion/magnification is obvious.
class GridTextBackground extends StatelessWidget {
  final String text;
  final List<Color> colors;
  const GridTextBackground({
    super.key,
    this.text = 'LIQUID',
    this.colors = const [Color(0xFF1A2980), Color(0xFF26D0CE)],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter(), size: Size.infinite),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < 4; i++)
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 56,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.18),
                    letterSpacing: 4,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small per-page caption chip.
class _Caption extends StatelessWidget {
  final String text;
  const _Caption(this.text);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ),
    );
  }
}

// A label drawn inside a lens.
Widget _lensLabel(String s) => Center(
      child: Text(
        s,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );

// =============================================================
// 1. ANYWHERE — standalone LiquidGlassLens, no view, no background
// =============================================================

class AnywherePage extends StatelessWidget {
  const AnywherePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MeshBackground(seed: 3),
        // Lenses dropped straight into the tree — NO LiquidGlassView,
        // NO backgroundWidget. On Impeller they refract the mesh above.
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 280,
                height: 150,
                child: LiquidGlassLens(
                  shape: const RoundedRectangleShape(
                    cornerRadius: 44,
                    cornerSmoothing: 1,
                  ),
                  refraction: const LiquidGlassRefraction(
                    distortion: 0.13,
                    distortionWidth: 34,
                  ),
                  child: _lensLabel('Standalone lens\nno view · no background'),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: LiquidGlassLens(
                      shape: const RoundedRectangleShape(cornerRadius: 60),
                      refraction: const LiquidGlassRefraction(
                        distortion: 0.22,
                        magnification: 1.15,
                      ),
                      child: _lensLabel('circle'),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: LiquidGlassLens(
                      shape: const RoundedRectangleShape(
                        cornerRadius: 18,
                        cornerSmoothing: 0.6,
                      ),
                      appearance: const LiquidGlassAppearance(
                        blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
                        color: Color(0x1AFFFFFF),
                      ),
                      child: _lensLabel('blur +\ntint'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _Caption(
          'Page 1 · Standalone lenses placed directly in a Stack. '
          'No LiquidGlassView, no background passed — refracts the live '
          'backdrop on Impeller (frosted fallback on Skia).',
        ),
      ],
    );
  }
}

// =============================================================
// 2. IN A VIEW — lens inside LiquidGlassView.child over a background
// =============================================================

class InViewPage extends StatelessWidget {
  const InViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassView(
          backgroundWidget: const GridTextBackground(text: 'GLASS'),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  height: 160,
                  child: LiquidGlassLens(
                    shape: const RoundedRectangleShape(
                      cornerRadius: 40,
                      cornerSmoothing: 1,
                    ),
                    refraction: const LiquidGlassRefraction(
                      distortion: 0.12,
                      distortionWidth: 30,
                    ),
                    child: _lensLabel('refracts the\ncaptured background'),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  height: 90,
                  child: LiquidGlassLens(
                    shape: const RoundedRectangleShape(cornerRadius: 45),
                    refraction: const LiquidGlassRefraction(
                      distortion: 0.18,
                      magnification: 1.1,
                      chromaticAberration: 0.006,
                    ),
                    child: _lensLabel('chromatic'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const _Caption(
          'Page 2 · LiquidGlassLens inside LiquidGlassView.child. On Skia '
          'it refracts the captured backgroundWidget; on Impeller, the '
          'live backdrop. Same widget code on both.',
        ),
      ],
    );
  }
}

// =============================================================
// 3. DRAGGABLE — the classic LiquidGlass children API + drag
// =============================================================

class DraggablePage extends StatelessWidget {
  const DraggablePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassView(
          backgroundWidget: const MeshBackground(
            seed: 11,
            colors: [
              Color(0xFF42275A),
              Color(0xFF734B6D),
              Color(0xFFFF8008),
              Color(0xFFFFC837),
            ],
          ),
          // The position-driven classic API — the only one with built-in
          // dragging. Drag the lens around the captured background.
          children: [
            LiquidGlass(
              geometry: const LiquidGlassGeometry(
                position:
                    LiquidGlassAlignPosition(alignment: Alignment.center),
                width: 200,
                height: 200,
                shape: RoundedRectangleShape(
                  cornerRadius: 100,
                  borderWidth: 1.4,
                ),
              ),
              refraction: const LiquidGlassRefraction(
                distortion: 0.2,
                distortionWidth: 36,
                magnification: 1.1,
              ),
              behavior: const LiquidGlassBehavior(draggable: true),
              child: _lensLabel('drag me'),
            ),
          ],
        ),
        const _Caption(
          'Page 3 · The classic LiquidGlass(children:) API — the one with '
          'built-in draggable. Drag the circular lens across the captured '
          'background.',
        ),
      ],
    );
  }
}

// =============================================================
// 4. SCROLLING — lenses inside a scrollable feed
// =============================================================

class ScrollingPage extends StatelessWidget {
  const ScrollingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassView(
          backgroundWidget: const GridTextBackground(
            text: 'SCROLL',
            colors: [Color(0xFF005AA7), Color(0xFFFFFDE4)],
          ),
          // Stretch overscroll isolates the list into its own layer and
          // blacks out backdrop lenses on Impeller — disable it.
          child: ScrollConfiguration(
            behavior:
                const MaterialScrollBehavior().copyWith(overscroll: false),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                28,
                MediaQuery.paddingOf(context).top + 80,
                28,
                28,
              ),
              itemCount: 10,
              itemBuilder: (context, i) => SizedBox(
                height: 110,
                child: LiquidGlassLens(
                  shape: RoundedRectangleShape(
                    cornerRadius: 26 + (i % 3) * 12.0,
                    cornerSmoothing: 1,
                  ),
                  refraction: const LiquidGlassRefraction(
                    distortion: 0.12,
                    distortionWidth: 26,
                  ),
                  child: _lensLabel('card #${i + 1}'),
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 22),
            ),
          ),
        ),
        const _Caption(
          'Page 4 · Lenses inside a scrolling ListView. The transform '
          'tracker keeps their refraction aligned as they move. Overscroll '
          'is disabled (stretch blacks out backdrop lenses on Impeller).',
        ),
      ],
    );
  }
}

// =============================================================
// 5. LIVE — lenses over a continuously animating background
// =============================================================

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Continuously moving colored balls — refraction should update
        // every frame on Impeller.
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _BallsPainter(_c.value),
            size: Size.infinite,
          ),
        ),
        Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: LiquidGlassLens(
              shape: const RoundedRectangleShape(
                cornerRadius: 60,
                cornerSmoothing: 1,
              ),
              refraction: const LiquidGlassRefraction(
                distortion: 0.16,
                distortionWidth: 40,
                magnification: 1.08,
              ),
              child: _lensLabel('live refraction'),
            ),
          ),
        ),
        const _Caption(
          'Page 5 · A standalone lens over a background that animates every '
          'frame. On Impeller the refraction tracks the motion live.',
        ),
      ],
    );
  }
}

class _BallsPainter extends CustomPainter {
  final double t;
  _BallsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF101820),
    );
    for (int i = 0; i < 10; i++) {
      final phase = t * 2 * math.pi + i;
      final cx = size.width * (0.5 + 0.42 * math.cos(phase * (1 + i * 0.1)));
      final cy = size.height * (0.5 + 0.42 * math.sin(phase * (1 + i * 0.07)));
      canvas.drawCircle(
        Offset(cx, cy),
        40 + (i % 4) * 14,
        Paint()
          ..color = Colors.primaries[i % Colors.primaries.length]
              .withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BallsPainter oldDelegate) =>
      oldDelegate.t != t;
}

// =============================================================
// 6. SHOW / HIDE — visibility melt animation, toggled live
// =============================================================

class ShowHidePage extends StatefulWidget {
  const ShowHidePage({super.key});

  @override
  State<ShowHidePage> createState() => _ShowHidePageState();
}

class _ShowHidePageState extends State<ShowHidePage> {
  bool _visible = true;
  int _ms = 600;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MeshBackground(
          seed: 21,
          colors: [
            Color(0xFF000428),
            Color(0xFF004E92),
            Color(0xFF00C9A7),
          ],
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  for (int i = 0; i < 4; i++)
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: LiquidGlassLens(
                        visibility: _visible,
                        visibilityDuration: Duration(milliseconds: _ms),
                        shape: RoundedRectangleShape(
                          cornerRadius: i.isEven ? 65 : 24,
                          cornerSmoothing: 1,
                        ),
                        refraction: const LiquidGlassRefraction(
                          distortion: 0.18,
                          distortionWidth: 30,
                        ),
                        child: _lensLabel('${i + 1}'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(_visible ? Icons.visibility_off : Icons.visibility),
                label: Text(_visible ? 'Hide glass' : 'Show glass'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('duration'),
                  Slider(
                    value: _ms.toDouble(),
                    min: 150,
                    max: 1500,
                    divisions: 9,
                    label: '${_ms}ms',
                    onChanged: (v) => setState(() => _ms = v.round()),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _Caption(
          'Page 6 · The built-in visibility animation: the glass uniforms '
          'relax to neutral and melt out, then back in. Tune the duration.',
        ),
      ],
    );
  }
}

// =============================================================
// 7. CONTROLS — the grouped-API components
// =============================================================

class ControlsPage extends StatefulWidget {
  const ControlsPage({super.key});

  @override
  State<ControlsPage> createState() => _ControlsPageState();
}

class _ControlsPageState extends State<ControlsPage> {
  double _volume = 0.6;
  double _brightness = 0.4;
  bool _wifi = true;
  bool _bluetooth = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MeshBackground(
          seed: 5,
          colors: [
            Color(0xFF232526),
            Color(0xFF414345),
            Color(0xFF8E54E9),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 72, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ControlLabel('Volume'),
                LiquidGlassSlider(
                  value: _volume,
                  onChanged: (v) => setState(() => _volume = v),
                ),
                const SizedBox(height: 28),
                const _ControlLabel('Brightness'),
                LiquidGlassSlider(
                  value: _brightness,
                  activeColor: const Color(0xFFFFC107),
                  onChanged: (v) => setState(() => _brightness = v),
                ),
                const SizedBox(height: 36),
                Row(
                  children: [
                    const _ControlLabel('Wi-Fi'),
                    const Spacer(),
                    LiquidGlassToggle(
                      value: _wifi,
                      onChanged: (v) => setState(() => _wifi = v),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const _ControlLabel('Bluetooth'),
                    const Spacer(),
                    LiquidGlassToggle(
                      value: _bluetooth,
                      activeColor: const Color(0xFF0A84FF),
                      onChanged: (v) => setState(() => _bluetooth = v),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'Self-contained components — each owns its own '
                  'LiquidGlassView. Configured with the new grouped API.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const _Caption(
          'Page 7 · The drop-in components: LiquidGlassSlider + '
          'LiquidGlassToggle. The jelly thumb refracts the track as it moves.',
        ),
      ],
    );
  }
}

class _ControlLabel extends StatelessWidget {
  final String text;
  const _ControlLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
