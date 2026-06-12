import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Drop-in slider + toggle demo.
//
// Run it directly:
//   flutter run -t lib/slider_toggle_demo.dart
//
// `LiquidGlassSlider` and `LiquidGlassToggle` are self-contained: each
// owns its own LiquidGlassView, so you just drop them over any
// background and give them a value + onChanged, like a normal Slider /
// Switch. No outer LiquidGlassView required.
//
// The "Transparent when black" switch at the bottom flips the
// `transparentWhenBlack` option on both controls so you can see the
// difference: with it ON, the glass thumb's overhang passes the
// background through; with it OFF (on the Skia capture path) the
// overhang draws black where it samples the transparent area around the
// track.
// =============================================================

void main() {
  runApp(const SliderToggleDemoApp());
}

class SliderToggleDemoApp extends StatelessWidget {
  const SliderToggleDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SliderToggleDemoPage(),
    );
  }
}

class SliderToggleDemoPage extends StatefulWidget {
  const SliderToggleDemoPage({super.key});

  @override
  State<SliderToggleDemoPage> createState() => _SliderToggleDemoPageState();
}

class _SliderToggleDemoPageState extends State<SliderToggleDemoPage> {
  double _volume = 0.45;
  double _brightness = 0.7;
  bool _wifi = true;
  bool _airplane = false;

  /// Flipped live so you can compare the black overhang vs transparent
  /// passthrough on the glass thumbs.
  bool _transparentWhenBlack = true;

  // ── Jelly lab — live tuning for the thumb deformation ────────────
  // Tune on the device, then report the numbers shown in the readout.
  // TEMP: start in the ORIGINAL pinch & extrude mode for testing.
  // Flip back to `true` (or use the in-app switch) for the iOS stretch.
  bool _iosJelly = false;
  double _stiffness = 320;
  // Lower than the pinch style's 22 so the speed spring visibly
  // overshoots negative on a hard stop — that overshoot IS the
  // squash-horizontal / stretch-vertical recoil.
  double _damping = 14;
  double _maxVelocity = 1.5;
  double _stretchWidth = 14;
  double _squashHeight = 6;
  double _anchorBias = -0.6;
  double _recoilScale = 1.6;
  double _recoilAnchor = 1.0;
  double _directionTau = 0.12;

  // With the switch OFF, use the pure defaults (pinchExtrude with the
  // historical spring constants) instead of feeding the stretch-tuned
  // lab values into the pinch style — that's the exact original feel.
  LiquidGlassSliderJelly get _jelly => _iosJelly
      ? LiquidGlassSliderJelly(
          style: LiquidGlassSliderJellyStyle.stretch,
          stiffness: _stiffness,
          damping: _damping,
          maxVelocity: _maxVelocity,
          stretchWidth: _stretchWidth,
          squashHeight: _squashHeight,
          anchorBias: _anchorBias,
          recoilScale: _recoilScale,
          recoilAnchor: _recoilAnchor,
          directionTau: _directionTau,
        )
      : const LiquidGlassSliderJelly();

  @override
  Widget build(BuildContext context) {
    // Span the full content width (screen minus the 24px page padding on
    // each side) so the slider's inset padding reads symmetric instead
    // of a fixed 280 sitting left-aligned in a wider screen.
    final sliderWidth = MediaQuery.sizeOf(context).width - 48;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A vivid gradient so the glass clearly refracts something.
          const _DemoBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liquid Glass controls',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _label('Volume'),
                  LiquidGlassSlider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                    layout: LiquidGlassSliderLayout(width: sliderWidth),
                    transparentWhenBlack: _transparentWhenBlack,
                    jelly: _jelly,
                  ),
                  const SizedBox(height: 24),

                  _label('Brightness'),
                  LiquidGlassSlider(
                    value: _brightness,
                    onChanged: (v) => setState(() => _brightness = v),
                    layout: LiquidGlassSliderLayout(width: sliderWidth),
                    activeColor: const Color(0xFFFFC107),
                    transparentWhenBlack: _transparentWhenBlack,
                    jelly: _jelly,
                  ),
                  const SizedBox(height: 36),

                  // ── Jelly lab ─────────────────────────────────────
                  const Divider(color: Colors.white24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'iOS jelly (stretch) — off = original',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: _iosJelly,
                        onChanged: (v) => setState(() => _iosJelly = v),
                      ),
                    ],
                  ),
                  _tune('stiffness', _stiffness, 100, 800,
                      (v) => setState(() => _stiffness = v)),
                  _tune('damping', _damping, 5, 40,
                      (v) => setState(() => _damping = v)),
                  _tune('maxVelocity', _maxVelocity, 0.3, 4,
                      (v) => setState(() => _maxVelocity = v)),
                  if (_iosJelly) ...[
                    _tune('stretchWidth', _stretchWidth, 0, 30,
                        (v) => setState(() => _stretchWidth = v)),
                    _tune('squashHeight', _squashHeight, 0, 12,
                        (v) => setState(() => _squashHeight = v)),
                    _tune('anchorBias', _anchorBias, -1, 1,
                        (v) => setState(() => _anchorBias = v)),
                    _tune('recoilScale', _recoilScale, 0, 3,
                        (v) => setState(() => _recoilScale = v)),
                    _tune('recoilAnchor', _recoilAnchor, 0, 1,
                        (v) => setState(() => _recoilAnchor = v)),
                    _tune('directionTau', _directionTau, 0.04, 0.3,
                        (v) => setState(() => _directionTau = v)),
                  ],
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      _label('Wi-Fi'),
                      const Spacer(),
                      LiquidGlassToggle(
                        value: _wifi,
                        onChanged: (v) => setState(() => _wifi = v),
                        transparentWhenBlack: _transparentWhenBlack,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _label('Airplane mode'),
                      const Spacer(),
                      LiquidGlassToggle(
                        value: _airplane,
                        onChanged: (v) => setState(() => _airplane = v),
                        activeColor: const Color(0xFFFF9500),
                        transparentWhenBlack: _transparentWhenBlack,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'transparentWhenBlack',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: _transparentWhenBlack,
                        onChanged: (v) =>
                            setState(() => _transparentWhenBlack = v),
                      ),
                    ],
                  ),
                  const Text(
                    'Toggle off (on Skia) to see the black overhang.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact tuning row: name + live value readout + a plain Material
  /// slider. The readout is what you report back once it feels right.
  Widget _tune(String name, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            name,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            value.toStringAsFixed(value.abs() < 10 ? 2 : 0),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 28,
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

/// Offline gradient background — no network needed so the demo always
/// runs.
class _DemoBackground extends StatelessWidget {
  const _DemoBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
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
          stops: [0.0, 0.4, 0.75, 1.0],
        ),
      ),
    );
  }
}
