import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Glass shapes over a text background.
//
// A wall of text sits behind four independent liquid-glass lenses — no
// metaball blending. Drag any two together and they simply overlap; each
// keeps its own corners:
//   • 2 × CIRCLE    — a circular rounded-rectangle on a square box whose
//                     corner radius is half the side (= a perfect circle)
//   • 1 × SQUIRCLE  — iOS-style continuous-curvature corners
//   • 1 × CONTINUOUS rounded rectangle — Apple capsule-style corners
//
// On Impeller each lens refracts the live backdrop with no extra setup.
// =============================================================

class GlassShapesShowcase extends StatefulWidget {
  const GlassShapesShowcase({super.key});

  @override
  State<GlassShapesShowcase> createState() => _GlassShapesShowcaseState();
}

class _GlassShapesShowcaseState extends State<GlassShapesShowcase> {
  // Each lens starts at this top-left offset in the Stack and can be
  // dragged anywhere over the text.
  Offset _circleA = const Offset(40, 140);
  Offset _circleB = const Offset(210, 470);
  Offset _squircle = const Offset(60, 300);
  Offset _continuous = const Offset(150, 620);

  // A circle is just a circular rounded-rectangle on a square box whose
  // corner radius is half the side.
  static const double _circleSize = 130;
  static const _circleStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: _circleSize / 2),
  );

  static const _squircleStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.squircle(cornerRadius: 56),
  );

  static const _continuousStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 48),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      appBar: AppBar(
        title: const Text('Glass shapes over text'),
        backgroundColor: const Color(0xFF0E1116),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1) The text background.
          const Positioned.fill(child: _TextBackground()),

          // 2) The four lenses, each rendering its OWN glass surface — no
          //    metaball merge. Drag them together and they simply overlap;
          //    each keeps its own corner style (circle / squircle /
          //    continuous).
          Positioned.fill(
            child: Stack(
              children: [
                _draggable(
                  pos: _circleA,
                  size: const Size.square(_circleSize),
                  style: _circleStyle,
                  label: 'circle',
                  onMove: (d) => setState(() => _circleA += d),
                ),
                _draggable(
                  pos: _circleB,
                  size: const Size.square(_circleSize),
                  style: _circleStyle,
                  label: 'circle',
                  onMove: (d) => setState(() => _circleB += d),
                ),
                _draggable(
                  pos: _squircle,
                  size: const Size(200, 150),
                  style: _squircleStyle,
                  label: 'squircle',
                  onMove: (d) => setState(() => _squircle += d),
                ),
                _draggable(
                  pos: _continuous,
                  size: const Size(240, 130),
                  style: _continuousStyle,
                  label: 'continuous',
                  onMove: (d) => setState(() => _continuous += d),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _draggable({
    required Offset pos,
    required Size size,
    required LiquidGlassStyle style,
    required String label,
    required ValueChanged<Offset> onMove,
  }) {
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      width: size.width,
      height: size.height,
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

/// A wall of readable text behind the glass — straight lines of type make
/// the refraction obvious as the lenses pass over them.
class _TextBackground extends StatelessWidget {
  const _TextBackground();

  static const String _para =
      'The quick brown fox jumps over the lazy dog. Pack my box with five '
      'dozen liquid glass jugs. How vexingly quick daft zebras jump! '
      'Sphinx of black quartz, judge my vow. ';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF182848), Color(0xFF4B6CB7)],
        ),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Liquid Glass',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _para * 18,
              style: const TextStyle(
                fontSize: 18,
                height: 1.55,
                color: Color(0xCCFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
