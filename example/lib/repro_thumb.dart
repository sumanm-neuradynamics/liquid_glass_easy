import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// Low-level toggle internals are intentionally not exported from the
// barrel — import them directly for this repro.
import 'package:liquid_glass_easy/src/widgets/components/toggle/liquid_glass_toggle.dart';

// Repro: renders the toggle frozen at several mid-slide animation times
// (what _LiquidGlassToggleState shows while _glassActive) over a magenta
// background, so the green "curve" artifact can be inspected statically.

void main() => runApp(const ReproApp());

class ReproApp extends StatelessWidget {
  const ReproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFC2185B),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final t in const [0.3, 0.6])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FrozenToggle(t: t, on: true), // OFF -> ON
                      const SizedBox(width: 40),
                      _FrozenToggle(t: t, on: false), // ON -> OFF
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

/// Mirrors _LiquidGlassToggleState.build with the animation frozen at
/// time [t] (0..1). [on] true = sliding off->on, false = on->off.
class _FrozenToggle extends StatelessWidget {
  final double t;
  final bool on;

  const _FrozenToggle({required this.t, required this.on});

  @override
  Widget build(BuildContext context) {
    const layout = LiquidGlassToggleLayout();

    final eased = Curves.easeOutCubic.transform(t);
    final travelFraction = on ? eased : 1.0 - eased;
    final growFraction = math.sin(math.pi * t);

    final maxPillW = layout.thumbWidth + layout.thumbExtraWidth;
    final maxPillH = layout.thumbHeight + layout.thumbExtraHeight;
    final travel = layout.travel;
    final rightExtent =
        layout.padding + travel + layout.thumbWidth / 2 + maxPillW / 2;
    final leftExtent = layout.padding + layout.thumbWidth / 2 - maxPillW / 2;
    final padX = math.max(
          math.max(0.0, rightExtent - layout.width),
          math.max(0.0, -leftExtent),
        ) +
        2.0;
    final padY = math.max(0.0, maxPillH / 2 - layout.height / 2) + 2.0;

    return SizedBox(
      width: layout.width + padX * 2,
      height: layout.height + padY * 2,
      child: LiquidGlassView(
        pixelRatio: 1.0,
        realTimeCapture: true,
        useSync: true,
        backgroundWidget: Stack(
          children: [
            Positioned(
              left: padX,
              top: padY,
              child: LiquidGlassToggleTrack(
                value: on,
                onChanged: (_) {},
                layout: layout,
                showRestThumb: false,
                pinchFraction: growFraction,
                travelFraction: travelFraction,
              ),
            ),
          ],
        ),
        children: [
          buildLiquidGlassToggleThumb(
            layout: layout,
            trackLeft: padX,
            trackBottom: padY,
            travelFraction: travelFraction,
            growFraction: growFraction,
          ),
        ],
      ),
    );
  }
}
