import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Nav bar + action button "unite" demo (Apple-style).
//
// A glass nav bar and a circular action button are BOTH members of one
// LiquidGlassBlender. Tap anywhere (or the button) to spring the action
// button down into the bar — their silhouettes flow into a single metaball
// surface, exactly like iOS's action button dissolving into the tab bar —
// then tap again to release it back out.
//
// The button is moved by a SlideTransition, which updates its transform
// LAYER every frame WITHOUT rebuilding the lens. That is the case the
// blender's transform probe exists for: without it the merged glass would
// freeze in place and only snap to the button on the next rebuild. With it,
// the metaball bridge forms and releases frame-by-frame through the spring.
// =============================================================

class NavUniteDemo extends StatefulWidget {
  const NavUniteDemo({super.key});

  @override
  State<NavUniteDemo> createState() => _NavUniteDemoState();
}

class _NavUniteDemoState extends State<NavUniteDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  // value 0 → button lifted above the bar (separated)
  // value 1 → button sitting on the bar (united)
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.9), // lifted ~1.9× its own height
    end: Offset.zero, //            resting on the bar (overlapping → merged)
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack, //   springy approach
    reverseCurve: Curves.easeInBack,
  ));

  bool get _united => _controller.value > 0.5;

  void _toggle() {
    if (_united) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Bar capsule + circular button. Same material so the merge reads as one
  // continuous surface.
  static const _barStyle = LiquidGlassStyle(
    shape: LiquidGlassShape.continuousRoundedRectangle(cornerRadius: 33),
  );
  static const double _buttonSize = 72;
  static const _buttonStyle = LiquidGlassStyle(
    // A circle: corner radius = half the side.
    shape: LiquidGlassShape.roundedRectangle(cornerRadius: _buttonSize / 2),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nav bar + action button unite'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        // DIAGNOSTIC: wrap the (working) blender setup in a LiquidGlassView to
        // see if the view's capture pipeline breaks the blender's members.
        child: LiquidGlassView(
          pixelRatio: 1,
          useSync: true,
          backgroundWidget: const _Backdrop(),
          child: Stack(
          children: [
            // Both lenses live inside ONE blender so they can merge.
            LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;
                const double barHeight = 66;
                const double barBottom = 48;
                const double barSideInset = 24;

                // Button rests centred on the bar: its centre on the bar's
                // centre, so the SlideTransition end (Offset.zero) overlaps.
                final double barCenterFromBottom = barBottom + barHeight / 2;
                final double buttonBottom = barCenterFromBottom - _buttonSize / 2;
                final double buttonLeft = (w - _buttonSize) / 2;

                return LiquidGlassBlender(
                  smoothness: 58,
                  style: _barStyle,
                  child: Stack(
                    children: [
                      // The nav bar (a member).
                      Positioned(
                        left: barSideInset,
                        right: barSideInset,
                        bottom: barBottom,
                        height: barHeight,
                        child: LiquidGlassLens(
                          style: _barStyle,
                          child: const _BarContents(),
                        ),
                      ),

                      // The action button (a member), moved by a transform
                      // layer — no rebuild — as it springs into the bar.
                      Positioned(
                        left: buttonLeft,
                        bottom: buttonBottom,
                        width: _buttonSize,
                        height: _buttonSize,
                        child: SlideTransition(
                          position: _slide,
                          child: const LiquidGlassLens(
                            style: _buttonStyle,
                            child: Center(
                              child: Icon(Icons.add_rounded,
                                  color: Colors.white, size: 34),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Hint.
            const Align(
              alignment: Alignment(0, -0.55),
              child: Text(
                'tap anywhere to unite / release',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Color(0x88FFFFFF),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

/// Tab icons inside the bar capsule.
class _BarContents extends StatelessWidget {
  const _BarContents();

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.favorite_rounded,
      Icons.person_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final i in icons)
            Icon(i, color: const Color(0xCCFFFFFF), size: 26),
        ],
      ),
    );
  }
}

/// A colourful backdrop with a grid so the refraction and the merged
/// silhouette are obvious.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D2671), Color(0xFFC33764), Color(0xFFFF8C42)],
        ),
      ),
      child: Positioned.fill(child: CustomPaint(painter: _GridPainter())),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1AFFFFFF)
      ..strokeWidth = 1;
    const step = 40.0;
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
