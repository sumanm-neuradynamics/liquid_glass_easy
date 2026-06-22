// -----------------------------------------------------------------------------
// EXPERIMENT: Metaball Liquid Glass
//
// Standalone demo for lib/assets/shaders/metaball_glass.frag. Three glass
// blobs sit over a live background; two gently bob and one follows your
// finger. Drag it near the others and they FUSE into a single piece of
// liquid glass — the refraction, rim light and tint all flow across the
// merged outline. The "Gooeyness" slider drives the smooth-min blend (k).
//
// Run it directly:
//     cd example
//     flutter run -t lib/metaball_experiment.dart
// -----------------------------------------------------------------------------

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(const MetaballApp());

class MetaballApp extends StatelessWidget {
  const MetaballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MetaballPage(),
    );
  }
}

/// One blob: center (logical px) + radius (logical px).
class _Blob {
  _Blob(this.center, this.radius);
  Offset center;
  double radius;
}

class MetaballPage extends StatefulWidget {
  const MetaballPage({super.key});

  @override
  State<MetaballPage> createState() => _MetaballPageState();
}

class _MetaballPageState extends State<MetaballPage>
    with SingleTickerProviderStateMixin {
  static const String _shaderAsset =
      'packages/liquid_glass_easy/lib/assets/shaders/metaball_glass.frag';

  final GlobalKey _bgKey = GlobalKey();
  late final Ticker _ticker;

  ui.FragmentShader? _shader;
  ui.Image? _image;

  double _t = 0; // animation clock (seconds)
  Size _size = Size.zero;

  // Tunables.
  double _gooeyness = 60; // smin k in px
  double _distortion = 1.2;
  double _ior = 1.45;
  double _magnify = 1.15;

  // Blobs: [0] and [1] auto-bob; [2] follows the finger.
  final List<_Blob> _blobs = [
    _Blob(Offset.zero, 64),
    _Blob(Offset.zero, 80),
    _Blob(Offset.zero, 70),
  ];
  Offset? _finger;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker(_onTick)..start();
  }

  Future<void> _loadShader() async {
    ui.FragmentProgram program;
    try {
      program = await ui.FragmentProgram.fromAsset(_shaderAsset);
    } catch (_) {
      // When running inside the package itself the prefix is dropped.
      program = await ui.FragmentProgram.fromAsset(
          'lib/assets/shaders/metaball_glass.frag');
    }
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  void _onTick(Duration elapsed) {
    _t = elapsed.inMicroseconds / 1e6;
    _captureBackground();
    if (mounted) setState(() {});
  }

  void _captureBackground() {
    final ctx = _bgKey.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderRepaintBoundary || !ro.attached) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    try {
      // ignore: invalid_use_of_protected_member
      if (ro.layer == null) return; // not composited yet — skip this frame
      _image = ro.toImageSync(pixelRatio: dpr);
    } catch (_) {
      // Soft-fail: keep the previous frame's image.
    }
  }

  // Resolve the animated blob positions for the current frame/size.
  void _updateBlobs(Size size) {
    final c = size.center(Offset.zero);
    // Two blobs orbit slowly so they drift in and out of merge range.
    _blobs[0].center = c + Offset(math.cos(_t * 0.8) * 90, math.sin(_t * 1.1) * 60);
    _blobs[1].center =
        c + Offset(math.cos(_t * 0.6 + 2) * 70, math.sin(_t * 0.9 + 1) * 80);
    // Finger blob: follow touch, else rest just below center.
    _blobs[2].center = _finger ?? (c + const Offset(0, 150));
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        _size = constraints.biggest;
        _updateBlobs(_size);
        return Stack(
          fit: StackFit.expand,
          children: [
            // --- Background that gets refracted ---
            RepaintBoundary(
              key: _bgKey,
              child: const _DemoBackground(),
            ),

            // --- Metaball glass overlay ---
            if (_shader != null && _image != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => setState(() => _finger = d.localPosition),
                onPanUpdate: (d) => setState(() => _finger = d.localPosition),
                child: CustomPaint(
                  size: _size,
                  painter: _MetaballPainter(
                    shader: _shader!,
                    image: _image!,
                    blobs: _blobs,
                    smoothK: _gooeyness,
                    distortion: _distortion,
                    ior: _ior,
                    magnify: _magnify,
                  ),
                ),
              ),

            _controls(),
          ],
        );
      }),
    );
  }

  Widget _controls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        color: Colors.black.withValues(alpha: 0.35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Drag anywhere to move a glass blob and merge it with the others',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            _slider('Gooeyness (smin k)', _gooeyness, 0, 160,
                (v) => _gooeyness = v),
            _slider('Distortion', _distortion, 0, 3, (v) => _distortion = v),
            _slider('Magnify', _magnify, 0.6, 2, (v) => _magnify = v),
            _slider('IOR', _ior, 1.0, 2.0, (v) => _ior = v),
          ],
        ),
      ),
    );
  }

  Widget _slider(
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text('$label  ${value.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: (v) => setState(() => onChanged(v)),
          ),
        ),
      ],
    );
  }
}

class _DemoBackground extends StatelessWidget {
  const _DemoBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1065), Color(0xFF0EA5E9), Color(0xFFF59E0B)],
        ),
      ),
      child: Stack(
        children: [
          // Some high-contrast shapes so the refraction is obvious.
          Positioned(
            top: 120,
            left: 40,
            child: _dot(140, const Color(0xFFEF4444)),
          ),
          Positioned(
            top: 260,
            right: 30,
            child: _dot(90, const Color(0xFF22C55E)),
          ),
          const Center(
            child: Text(
              'METABALL\nGLASS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _MetaballPainter extends CustomPainter {
  _MetaballPainter({
    required this.shader,
    required this.image,
    required this.blobs,
    required this.smoothK,
    required this.distortion,
    required this.ior,
    required this.magnify,
  });

  final ui.FragmentShader shader;
  final ui.Image image;
  final List<_Blob> blobs;
  final double smoothK;
  final double distortion;
  final double ior;
  final double magnify;

  @override
  void paint(Canvas canvas, Size size) {
    int i = 0;
    void f(double v) => shader.setFloat(i++, v);

    // u_resolution
    f(size.width);
    f(size.height);

    // u_blob0..3 : (cx, cy, radius, enabled)
    for (int b = 0; b < 4; b++) {
      if (b < blobs.length) {
        f(blobs[b].center.dx);
        f(blobs[b].center.dy);
        f(blobs[b].radius);
        f(1.0);
      } else {
        f(0); f(0); f(0); f(0);
      }
    }

    f(smoothK); // u_smoothK
    f(28.0); // u_edgeThickness
    f(distortion); // u_distortion
    f(ior); // u_ior
    f(magnify); // u_magnify
    f(6.0); // u_rimWidth
    f(0.35); // u_rimIntensity
    f(2.5); // u_chroma
    // u_tint (subtle cool tint)
    f(0.85); f(0.92); f(1.0); f(0.06);
    // u_lightDir
    f(-0.5); f(-0.85);

    shader.setImageSampler(0, image);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_MetaballPainter old) => true;
}
