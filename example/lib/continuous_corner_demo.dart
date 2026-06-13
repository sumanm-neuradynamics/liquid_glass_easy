import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// Continuous-corner (Apple squircle) playground.
//
//   flutter run -t lib/continuous_corner_demo.dart
//
// One glass card over a grid background, with sliders controlling:
//   - cornerSmoothing (0 = circular corners, 1 = Apple continuous)
//   - cornerRadius
//   - distortionWidth
//
// The sliders live in the background widget, outside the lens, so they
// stay interactive. On the Impeller path the lens samples the live
// backdrop, so every change is reflected immediately.

void main() => runApp(const ContinuousCornerDemoApp());

class ContinuousCornerDemoApp extends StatelessWidget {
  const ContinuousCornerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const ContinuousCornerDemoPage(),
    );
  }
}

class ContinuousCornerDemoPage extends StatefulWidget {
  const ContinuousCornerDemoPage({super.key});

  @override
  State<ContinuousCornerDemoPage> createState() =>
      _ContinuousCornerDemoPageState();
}

class _ContinuousCornerDemoPageState extends State<ContinuousCornerDemoPage> {
  static const double _lensW = 240.0;
  static const double _lensH = 180.0;

  double _smoothing = 1.0;
  double _radius = 44.0;
  double _distortionWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final lensX = (size.width - _lensW) / 2;
    final lensY = size.height * 0.08;

    // Wide low bar — height 60, nearly full width. Shares the same
    // radius/smoothing/distortion; its radius simply caps at 30 (its
    // half-height), so it shows the capsule limit while the card above
    // still has corner room.
    final barW = size.width - 48;
    const barH = 60.0;
    final barX = (size.width - barW) / 2;
    final barY = lensY + _lensH + 24;

    // Small square card.
    const sqW = 110.0;
    const sqH = 110.0;
    final sqX = (size.width - sqW) / 2;
    final sqY = barY + barH + 24;

    return Scaffold(
      body: LiquidGlassView(
        pixelRatio: 1.0,
        realTimeCapture: false,
        backgroundWidget: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D1B4C),
                    Color(0xFF5B2C83),
                    Color(0xFFE0457B),
                    Color(0xFFF59E0B),
                  ],
                ),
              ),
            ),
            const CustomPaint(painter: _GridPainter()),
            // Controls — below the lenses, outside their rects, so they
            // stay tappable.
            Positioned(
              left: 24,
              right: 24,
              top: sqY + sqH + 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _control(
                    label: 'cornerSmoothing',
                    value: _smoothing,
                    min: 0,
                    max: 1,
                    onChanged: (v) => setState(() => _smoothing = v),
                  ),
                  _control(
                    label: 'cornerRadius',
                    value: _radius,
                    min: 0,
                    max: _lensH / 2,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  _control(
                    label: 'distortionWidth',
                    value: _distortionWidth,
                    min: 0,
                    max: 60,
                    onChanged: (v) => setState(() => _distortionWidth = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          _lens(left: lensX, top: lensY, width: _lensW, height: _lensH),
          _lens(left: barX, top: barY, width: barW, height: barH),
          _lens(left: sqX, top: sqY, width: sqW, height: sqH),
        ],
      ),
    );
  }

  /// One glass lens — all lenses share the same slider-driven radius,
  /// smoothing, and distortion width.
  LiquidGlass _lens({
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    return LiquidGlass(
      geometry: LiquidGlassGeometry(
        position: LiquidGlassOffsetPosition(left: left, top: top),
        width: width,
        height: height,
        shape: RoundedRectangleShape(
          cornerRadius: _radius,
          cornerSmoothing: _smoothing,
          borderWidth: 1.2,
          lightIntensity: 1.2,
          lightDirection: 80,
          borderType: const OpticalBorder(
            borderSaturation: 1.3,
            ambientIntensity: 1.0,
            borderSolidity: 0.5,
          ),
        ),
      ),
      refraction: LiquidGlassRefraction(
        magnification: 1,
        distortion: 0.12,
        distortionWidth: _distortionWidth,
        chromaticAberration: 0.003,
      ),
      appearance: LiquidGlassAppearance(
        color: Colors.white.withAlpha(20),
        blur: const LiquidGlassBlur(sigmaX: 1.5, sigmaY: 1.5),
      ),
    );
  }

  Widget _control({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(2)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Fine grid so the corner outline and edge refraction are easy to read.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(46)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
