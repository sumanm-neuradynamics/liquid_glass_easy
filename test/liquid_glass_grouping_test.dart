import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// Compares every visual/behavioral field the renderer reads. If these all
/// match, the flat and grouped APIs build an identical lens.
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

  test('grouped defaults == flat defaults', () {
    final flat = const LiquidGlass(position: center);
    final grouped = LiquidGlass.grouped(
      geometry: const LiquidGlassGeometry(position: center),
    );
    expectSameLens(flat, grouped);
  });

  test('grouped custom values == equivalent flat values', () {
    final flat = const LiquidGlass(
      position: center,
      width: 240,
      height: 160,
      shape: RoundedRectangleShape(cornerRadius: 36),
      outOfBoundaries: true,
      distortion: 0.12,
      distortionWidth: 28,
      magnification: 1.2,
      chromaticAberration: 0.004,
      saturation: 1.3,
      refractionMode: LiquidGlassRefractionMode.radialRefraction,
      diagonalFlip: 0.5,
      blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
      color: Color(0x16FFFFFF),
      enableInnerRadiusTransparent: true,
      draggable: true,
      visibility: false,
    );

    final grouped = LiquidGlass.grouped(
      geometry: const LiquidGlassGeometry(
        position: center,
        width: 240,
        height: 160,
        shape: RoundedRectangleShape(cornerRadius: 36),
        outOfBoundaries: true,
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.12,
        distortionWidth: 28,
        magnification: 1.2,
        chromaticAberration: 0.004,
        refractionMode: LiquidGlassRefractionMode.radialRefraction,
        diagonalFlip: 0.5,
      ),
      appearance: const LiquidGlassAppearance(
        saturation: 1.3,
        blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
        color: Color(0x16FFFFFF),
        enableInnerRadiusTransparent: true,
      ),
      behavior: const LiquidGlassBehavior(
        draggable: true,
        visibility: false,
      ),
    );

    expectSameLens(flat, grouped);
  });

  test('child and key are carried through grouped()', () {
    const key = ValueKey('lens-1');
    const child = SizedBox.shrink();
    final grouped = LiquidGlass.grouped(
      key: key,
      child: child,
      geometry: const LiquidGlassGeometry(position: center),
    );
    expect(grouped.key, key);
    expect(grouped.child, same(child));
  });

  test('group getters round-trip back to the same values', () {
    final flat = const LiquidGlass(
      position: center,
      width: 123,
      height: 45,
      distortion: 0.2,
      blur: LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
      color: Color(0x33FF0000),
      draggable: true,
    );

    // Pull categories out, rebuild from them — must be identical.
    final rebuilt = LiquidGlass.grouped(
      geometry: flat.geometry,
      refraction: flat.refraction,
      appearance: flat.appearance,
      behavior: flat.behavior,
    );
    expectSameLens(flat, rebuilt);
  });
}
