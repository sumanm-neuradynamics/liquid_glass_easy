import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

void main() {
  const items = [
    LiquidGlassTabBarItem(icon: Icons.home, label: 'Home'),
    LiquidGlassTabBarItem(icon: Icons.search, label: 'Search'),
  ];

  LiquidGlassBottomNavBar bar({
    LiquidGlassNavPillStyle? pillStyle,
    LiquidGlassNavItemStyle? itemStyle,
    LiquidGlassAppearance? appearance,
    LiquidGlassRefraction? refraction,
  }) {
    return LiquidGlassBottomNavBar(
      items: items,
      selectedIndex: 0,
      onChanged: (_) {},
      pillStyle: pillStyle,
      itemStyle: itemStyle,
      appearance: appearance,
      refraction: refraction,
    );
  }

  test('no groups → flat defaults are unchanged', () {
    final b = bar();
    expect(b.glassPill, LiquidGlassPillMode.none);
    expect(b.pillGrowHeight, 16);
    expect(b.pillDistortion, 0.06);
    expect(b.color, const Color(0x16FFFFFF));
    expect(b.distortion, 0.07);
    expect(b.distortionWidth, 28);
    expect(b.chromaticAberration, 0.002);
  });

  test('pillStyle overrides the flat pill params', () {
    final b = bar(
      pillStyle: const LiquidGlassNavPillStyle(
        mode: LiquidGlassPillMode.both,
        growHeight: 24,
        distortion: 0.1,
        distortionWidth: 14,
        magnification: 1.1,
        enableInnerRadiusTransparent: true,
      ),
    );
    expect(b.glassPill, LiquidGlassPillMode.both);
    expect(b.pillGrowHeight, 24);
    expect(b.pillDistortion, 0.1);
    expect(b.pillDistortionWidth, 14);
    expect(b.pillMagnification, 1.1);
    expect(b.pillEnableInnerRadiusTransparent, isTrue);
  });

  test('appearance + refraction override the capsule glass look', () {
    final b = bar(
      appearance: const LiquidGlassAppearance(
        color: Color(0x33FF0000),
        blur: LiquidGlassBlur(sigmaX: 5, sigmaY: 5),
        saturation: 1.4,
      ),
      refraction: const LiquidGlassRefraction(
        distortion: 0.2,
        distortionWidth: 40,
        chromaticAberration: 0.01,
        magnification: 1.2,
      ),
    );
    expect(b.color, const Color(0x33FF0000));
    expect(b.blur.sigmaX, 5);
    expect(b.saturation, 1.4);
    expect(b.distortion, 0.2);
    expect(b.distortionWidth, 40);
    expect(b.chromaticAberration, 0.01);
    expect(b.magnification, 1.2);
  });

  test('resolveGlassPill follows the mode and renderer', () {
    final none = bar();
    expect(none.resolveGlassPill(useImpellerBackdrop: true), isFalse);

    final both = bar(
      pillStyle: const LiquidGlassNavPillStyle(mode: LiquidGlassPillMode.both),
    );
    expect(both.resolveGlassPill(useImpellerBackdrop: false), isTrue);

    final impeller = bar(
      pillStyle: const LiquidGlassNavPillStyle(
        mode: LiquidGlassPillMode.impellerOnly,
      ),
    );
    expect(impeller.resolveGlassPill(useImpellerBackdrop: true), isTrue);
    expect(impeller.resolveGlassPill(useImpellerBackdrop: false), isFalse);
  });
}
