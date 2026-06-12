import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  test('spring step converges on its target', () {
    var x = 0.0;
    var v = 0.0;
    for (var i = 0; i < 240; i++) {
      final r = liquidGlassSpringStep(x: x, vel: v, target: 1, dt: 1 / 60);
      x = r.$1;
      v = r.$2;
    }
    expect(x, closeTo(1.0, 0.001));
    expect(v.abs(), lessThan(0.01));
  });

  test('spring is underdamped (overshoots once)', () {
    var x = 0.0;
    var v = 0.0;
    var maxX = 0.0;
    for (var i = 0; i < 240; i++) {
      final r = liquidGlassSpringStep(x: x, vel: v, target: 1, dt: 1 / 60);
      x = r.$1;
      v = r.$2;
      if (x > maxX) maxX = x;
    }
    expect(maxX, greaterThan(1.0));
  });

  test('jelly loads under a fast pump and settles after release', () async {
    final jelly = LiquidGlassJellySpring();
    jelly.start(0);

    // Pump a fast forward drag; wall-clock dt must be > 0.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    jelly.pump(0.5);

    var settled = jelly.tick(1 / 60, dragging: true);
    expect(settled, isFalse);
    expect(jelly.stretch, isNot(0));
    expect(jelly.direction, greaterThan(0));

    // Release and run the simulation until it reports settled.
    jelly.release();
    var ticks = 0;
    while (!settled && ticks < 600) {
      settled = jelly.tick(1 / 60, dragging: false);
      ticks++;
    }
    expect(settled, isTrue, reason: 'jelly never settled in 10s simulated');
    expect(jelly.stretch, 0);
    expect(jelly.deform, 0);
  });

  test('reversal swings the deform spring negative (squash recoil)', () async {
    final jelly = LiquidGlassJellySpring();
    jelly.start(0);

    // Establish forward motion + direction memory long enough for the
    // deform spring to load up near its steady-state stretch.
    var value = 0.0;
    for (var i = 0; i < 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 8));
      value += 0.05;
      jelly.pump(value);
      jelly.tick(1 / 60, dragging: true);
    }
    expect(jelly.direction, greaterThan(0.5));
    final deformBefore = jelly.deform;
    expect(deformBefore, greaterThan(0.3));

    // Sudden reversal: velocity opposes the remembered direction, so
    // the deform target swings negative until the memory re-adapts
    // (over ~directionTau). The deform must dip through zero — the
    // squash-recoil phase.
    await Future<void>.delayed(const Duration(milliseconds: 8));
    jelly.pump(value - 0.3);
    var minDeform = jelly.deform;
    for (var i = 0; i < 20; i++) {
      jelly.tick(1 / 60, dragging: true);
      if (jelly.deform < minDeform) minDeform = jelly.deform;
    }
    expect(minDeform, lessThan(0));
  });
}
