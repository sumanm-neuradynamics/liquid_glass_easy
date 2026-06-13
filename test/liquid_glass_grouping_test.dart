import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Compares every visual/behavioral field the renderer reads. If these all
/// match, the two configs build an identical lens.
void expectSameLens(LiquidGlass a, LiquidGlass b) {
  expect(a.width, b.width, reason: 'width');
  expect(a.height, b.height, reason: 'height');
  expect(a.position, b.position, reason: 'position');
  expect(a.shape, b.shape, reason: 'shape');
  expect(a.outOfBoundaries, b.outOfBoundaries, reason: 'outOfBoundaries');
  expect(a.distortion, b.distortion, reason: 'distortion');
  expect(a.distortionWidth, b.distortionWidth, reason: 'distortionWidth');
  expect(a.magnification, b.magnification, reason: 'magnification');
  expect(a.chromaticAberration, b.chromaticAberration,
      reason: 'chromaticAberration');
  expect(a.saturation, b.saturation, reason: 'saturation');
  expect(a.refractionMode, b.refractionMode, reason: 'refractionMode');
  expect(a.diagonalFlip, b.diagonalFlip, reason: 'diagonalFlip');
  expect(a.blur, b.blur, reason: 'blur');
  expect(a.color, b.color, reason: 'color');
  expect(a.enableInnerRadiusTransparent, b.enableInnerRadiusTransparent,
      reason: 'enableInnerRadiusTransparent');
  expect(a.draggable, b.draggable, reason: 'draggable');
  expect(a.visibility, b.visibility, reason: 'visibility');
  expect(a.controller, b.controller, reason: 'controller');
}

void main() {
  const center = LiquidGlassAlignPosition(alignment: Alignment.center);

  test('group defaults surface through the flat getters', () {
    final lens = const LiquidGlass(
      geometry: LiquidGlassGeometry(position: center),
    );
    expect(lens.position, center);
    expect(lens.width, 200);
    expect(lens.height, 100);
    expect(lens.shape, const RoundedRectangleShape());
    expect(lens.outOfBoundaries, false);
    expect(lens.distortion, 0.1);
    expect(lens.distortionWidth, 30);
    expect(lens.magnification, 1);
    expect(lens.chromaticAberration, 0.003);
    expect(lens.refractionMode, LiquidGlassRefractionMode.shapeRefraction);
    expect(lens.diagonalFlip, 0);
    expect(lens.saturation, 1.0);
    expect(lens.blur, const LiquidGlassBlur());
    expect(lens.color, Colors.transparent);
    expect(lens.enableInnerRadiusTransparent, false);
    expect(lens.draggable, false);
    expect(lens.visibility, true);
    expect(lens.controller, isNull);
  });

  test('custom group values surface through the flat getters', () {
    final lens = const LiquidGlass(
      geometry: LiquidGlassGeometry(
        position: center,
        width: 240,
        height: 160,
        shape: RoundedRectangleShape(cornerRadius: 36),
        outOfBoundaries: true,
      ),
      refraction: LiquidGlassRefraction(
        distortion: 0.12,
        distortionWidth: 28,
        magnification: 1.2,
        chromaticAberration: 0.004,
        refractionMode: LiquidGlassRefractionMode.radialRefraction,
        diagonalFlip: 0.5,
      ),
      appearance: LiquidGlassAppearance(
        saturation: 1.3,
        blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
        color: Color(0x16FFFFFF),
        enableInnerRadiusTransparent: true,
      ),
      behavior: LiquidGlassBehavior(
        draggable: true,
        visibility: false,
      ),
    );

    expect(lens.position, center);
    expect(lens.width, 240);
    expect(lens.height, 160);
    expect(lens.shape, const RoundedRectangleShape(cornerRadius: 36));
    expect(lens.outOfBoundaries, true);
    expect(lens.distortion, 0.12);
    expect(lens.distortionWidth, 28);
    expect(lens.magnification, 1.2);
    expect(lens.chromaticAberration, 0.004);
    expect(lens.refractionMode, LiquidGlassRefractionMode.radialRefraction);
    expect(lens.diagonalFlip, 0.5);
    expect(lens.saturation, 1.3);
    expect(lens.blur, const LiquidGlassBlur(sigmaX: 2, sigmaY: 2));
    expect(lens.color, const Color(0x16FFFFFF));
    expect(lens.enableInnerRadiusTransparent, true);
    expect(lens.draggable, true);
    expect(lens.visibility, false);
  });

  test('child and key are carried through the constructor', () {
    const key = ValueKey('lens-1');
    const child = SizedBox.shrink();
    final lens = const LiquidGlass(
      key: key,
      child: child,
      geometry: LiquidGlassGeometry(position: center),
    );
    expect(lens.key, key);
    expect(lens.child, same(child));
  });

  test('group getters round-trip back to the same values', () {
    final original = const LiquidGlass(
      geometry: LiquidGlassGeometry(position: center, width: 123, height: 45),
      refraction: LiquidGlassRefraction(distortion: 0.2),
      appearance: LiquidGlassAppearance(
        blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
        color: Color(0x33FF0000),
      ),
      behavior: LiquidGlassBehavior(draggable: true),
    );

    // Pull the stored groups out, rebuild from them — must be identical.
    final rebuilt = LiquidGlass(
      geometry: original.geometry,
      refraction: original.refraction,
      appearance: original.appearance,
      behavior: original.behavior,
    );
    expectSameLens(original, rebuilt);
    expect(rebuilt.geometry, same(original.geometry));
    expect(rebuilt.refraction, same(original.refraction));
    expect(rebuilt.appearance, same(original.appearance));
    expect(rebuilt.behavior, same(original.behavior));
  });

  test('copyWith replaces a single group and keeps the rest', () {
    final original = const LiquidGlass(
      geometry: LiquidGlassGeometry(position: center, width: 100),
      behavior: LiquidGlassBehavior(draggable: true),
    );

    final moved = original.copyWith(
      geometry: original.geometry.copyWith(width: 240),
    );
    expect(moved.width, 240);
    expect(moved.height, original.height);
    expect(moved.position, center);
    expect(moved.draggable, true);
    expect(moved.refraction, same(original.refraction));
    expect(moved.appearance, same(original.appearance));
    expect(moved.behavior, same(original.behavior));
  });
}
