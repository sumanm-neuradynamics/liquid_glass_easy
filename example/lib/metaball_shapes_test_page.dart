import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Metaball shapes test.
//
// Three SAME-HEIGHT draggable lenses, one per corner style:
//   • CIRCULAR rounded rectangle (plain rounded corners)
//   • CONTINUOUS rounded rectangle (Apple capsule-style corners)
//   • SQUIRCLE (L^n superellipse corners)
//
// Toggle "Blend" to wrap them in a LiquidGlassBlender. The blender reads each
// member's corner STYLE (not just its radius), so every shape keeps its own
// corners through the merge. Drag them together to watch the distinct corners
// fuse.
// =============================================================

class MetaballShapesTestPage extends StatefulWidget {
  const MetaballShapesTestPage({super.key});

  @override
  State<MetaballShapesTestPage> createState() => _MetaballShapesTestPageState();
}

class _MetaballShapesTestPageState extends State<MetaballShapesTestPage> {
  // Every lens is the same width × height so the ONLY difference is the
  // corner style. Same height is the explicit requirement.
  static const double _w = 190;
  static const double _h = 140;
  static const double _radius = 44;

  // Top-left of each lens, in the Stack's coordinate space.
  Offset _rounded = const Offset(40, 220);
  Offset _continuous = const Offset(150, 360);
  Offset _squircle = const Offset(60, 520);

  bool _blend = true;

  // Per-lens styles — identical except for the corner style. The blender reads
  // each member's corner STYLE (not just its radius), so each shape keeps its
  // own corners through the merge.
  static const _roundedStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: _radius),
                appearance: LiquidGlassAppearance(blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2)),

  );
  static const _continuousStyle = LiquidGlassStyle(
            appearance: LiquidGlassAppearance(blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2)),

    shape: LiquidGlassShape.roundedRectangle(cornerRadius: 50),
  );
  static const _squircleStyle = LiquidGlassStyle(
            appearance: LiquidGlassAppearance(blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2)),

    shape: LiquidGlassShape.roundedRectangle(cornerRadius: _radius),
  );

  @override
  Widget build(BuildContext context) {
    final Widget lenses = Stack(
      children: [
        _draggable(
          pos: _rounded,
          style: _roundedStyle,
          label: 'rounded',
          onMove: (d) => setState(() => _rounded += d),
        ),
        _draggable(
          pos: _continuous,
          style: _continuousStyle,
          label: 'continuous',
          onMove: (d) => setState(() => _continuous += d),
        ),
        _draggable(
          pos: _squircle,
          style: _squircleStyle,
          label: 'squircle',
          onMove: (d) => setState(() => _squircle += d),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metaball shapes test'),
        actions: [
          Row(
            children: [
              const Text('Blend'),
              Switch(
                value: _blend,
                onChanged: (v) => setState(() => _blend = v),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          const _Backdrop(),
          if (_blend)
            LiquidGlassBlender(
              smoothness: 50,
              style: _continuousStyle,
              child: lenses,
            )
          else
            lenses,
        ],
      ),
    );
  }

  Widget _draggable({
    required Offset pos,
    required LiquidGlassStyle style,
    required String label,
    required ValueChanged<Offset> onMove,
  }) {
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: _w,
      height: _h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onMove(details.delta),
        child: LiquidGlassLens(
          style: style,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A colourful backdrop so the refraction (and the merged silhouette) is
/// obvious.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          const Align(
            alignment: Alignment(0, -0.92),
            child: Text(
              'drag the shapes together',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: Color(0x66FFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A faint grid whose straight lines reveal the glass refraction.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
