import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_light_mode.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_refraction_mode.dart';
import '../utils/liquid_glass_shape.dart';

class LiquidGlassPainter extends CustomPainter {
  final LiquidGlassPosition position;
  final Offset? dragOffset;
  final double lensWidth;
  final double lensHeight;
  final double magnification;
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final bool enableInnerRadiusTransparent;
  final bool draggable;
  final Size parentSize;
  final LiquidGlassShape? border;
  final double borderAlpha;
  final LiquidGlassBlur blur;
  final double chromaticAberration;
  final double saturation;
  final LiquidGlassRefractionMode? refractionMode;
  final Color color;
  final ui.FragmentShader shader;
  final ui.FragmentShader? borderShader;

  final ui.Image image;

  LiquidGlassPainter({
    required this.position,
    required this.dragOffset,
    required this.lensWidth,
    required this.lensHeight,
    required this.magnification,
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.enableInnerRadiusTransparent,
    required this.draggable,
    required this.parentSize,
    required this.border,
    required this.borderAlpha,
    required this.blur,
    required this.color,
    required this.shader,
    this.borderShader,
    required this.chromaticAberration,
    required this.saturation,
    required this.refractionMode,
    required this.image,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bool useBlur = blur.sigmaX > 0 || blur.sigmaY > 0;
    final lensPosition = dragOffset!;
    final double selectedLightMode =
        (border!.lightMode == LiquidGlassLightMode.edge) ? 0 : 1;
    final double selectedRefractionMode =
        (refractionMode == LiquidGlassRefractionMode.shapeRefraction) ? 0 : 1;
    final double selectedBorderMode =
        (border!.borderMode == LiquidGlassBorderMode.classic) ? 0 : 1;

    int index = 0;
    // Pass shader parameters (uniforms) for the GLSL shader
    shader.setFloat(index++, size.width);
    shader.setFloat(index++, size.height);
    shader.setFloat(index++, lensPosition.dx);
    shader.setFloat(index++, lensPosition.dy);

    shader.setFloat(index++, lensWidth);
    shader.setFloat(index++, lensHeight);
    shader.setFloat(index++, border is RoundedRectangleShape ? 0 : 1);
    shader.setFloat(
        index++,
        border is RoundedRectangleShape
            ? (border as RoundedRectangleShape).cornerRadius
            : 0);
    shader.setFloat(
        index++,
        border is SuperellipseShape
            ? (border as SuperellipseShape).curveExponent
            : 0);

    shader.setFloat(index++, magnification);
    shader.setFloat(index++, distortion);
    shader.setFloat(index++, distortionWidth);

    shader.setFloat(index++, enableInnerRadiusTransparent ? 1.0 : 0.0);
    shader.setFloat(index++, diagonalFlip);

    // No-blur path: main shader draws the border itself.
    // Match the second pass's behavior: it doubles the border width
    // (so its `effectiveBorderWidth = u_borderWidth * 2.0` covers the
    // full intended inner width once the outer half is clipped).
    // We do the same here — the main shader's centered band has its
    // outer half clipped by `canvas.clipRRect` below, leaving the
    // full intended border width visible inside the shape.
    // Blur path: suppress the border in the main shader so the
    // second-pass painter draws it sharp on top of the blur.
    shader.setFloat(index++, (!useBlur) ? border!.borderWidth * 2.0 : 0);
    shader.setFloat(index++, border!.borderSoftness);

    shader.setFloat(index++, border!.borderColor?.r ?? 0);
    shader.setFloat(index++, border!.borderColor?.g ?? 0);
    shader.setFloat(index++, border!.borderColor?.b ?? 0);
    shader.setFloat(index++, border!.borderColor?.a ?? 0);
    shader.setFloat(index++, borderAlpha);

    shader.setFloat(index++, border!.lightIntensity);

    shader.setFloat(index++, border!.lightColor.r);
    shader.setFloat(index++, border!.lightColor.g);
    shader.setFloat(index++, border!.lightColor.b);
    shader.setFloat(index++, border!.lightColor.a);

    shader.setFloat(index++, border!.shadowColor.r);
    shader.setFloat(index++, border!.shadowColor.g);
    shader.setFloat(index++, border!.shadowColor.b);
    shader.setFloat(index++, border!.shadowColor.a);

    shader.setFloat(index++, border!.lightDirection);
    shader.setFloat(index++, color.r);
    shader.setFloat(index++, color.b);
    shader.setFloat(index++, color.g);
    shader.setFloat(index++, color.a);
    // One-side / double-side specular highlights are classic-only:
    // in optical mode the directional term saturates the internal
    // brightness cap so these contributions become invisible. Zero
    // them on the wire to keep behavior consistent with the UI.
    shader.setFloat(
        index++,
        border!.isOpticalBorder ? 0.0 : border!.oneSideLightIntensity);
    shader.setFloat(index++, chromaticAberration);
    shader.setFloat(index++, saturation);
    shader.setFloat(index++, selectedLightMode);
    shader.setFloat(index++, selectedRefractionMode);
    shader.setFloat(index++, border!.ambientIntensity);
    shader.setFloat(
        index++,
        border!.isOpticalBorder ? 0.0 : border!.doubleSideLightIntensity);
    shader.setFloat(index++, border!.borderSaturation);
    shader.setFloat(index++, border!.borderSolidity);
    shader.setFloat(index++, selectedBorderMode);

    shader.setImageSampler(0, image);

    // final borderExpand = border!.borderWidth / 2;
    // final rectExpandedBorder = Rect.fromLTWH(
    //   lensPosition.dx - borderExpand,
    //   lensPosition.dy - borderExpand,
    //   lensWidth + 2 * borderExpand,
    //   lensHeight + 2 * borderExpand,
    // );
    final rectExpandedBorder = Rect.fromLTWH(
      lensPosition.dx,
      lensPosition.dy,
      lensWidth,
      lensHeight,
    );

    final rectRRect = RRect.fromRectAndRadius(
      rectExpandedBorder,
      Radius.circular(
        border is RoundedRectangleShape
            ? (border as RoundedRectangleShape).cornerRadius
            : 0,
      ),
    );

    //canvas.save();
    canvas.clipRRect(rectRRect);

    final lensPaint = Paint()..shader = shader;

    if (useBlur && border is SuperellipseShape) {
      // Clamp the superellipse blur to a maximum sigma of 3 to keep
      // the effect tasteful and avoid heavy GPU cost on large shapes.
      const double kSuperellipseMaxBlurSigma = 3.0;
      lensPaint.imageFilter = ui.ImageFilter.blur(
        sigmaX:
            (blur.sigmaX * borderAlpha).clamp(0.0, kSuperellipseMaxBlurSigma),
        sigmaY:
            (blur.sigmaY * borderAlpha).clamp(0.0, kSuperellipseMaxBlurSigma),
        tileMode: ui.TileMode.mirror,
      );
    }
    canvas.drawRRect(rectRRect, lensPaint);
    //canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter oldDelegate) {
    // IMPORTANT (do not shorten this list): the previous implementation
    // compared only `image` and `borderAlpha` and ignored changes to
    // `lensWidth`/`lensHeight`/`cornerRadius`/`color` and other uniforms.
    // In debug builds this was masked by the fact that `_image` changes
    // every frame (so the canvas would repaint regardless). On release
    // builds with Impeller, `toImageSync` can silently fail, so the image
    // stops changing — and the canvas shader then freezes with stale
    // uniforms even though the widget tree already holds a different
    // lens configuration. That's what caused "stale lens content" and
    // "transparent lenses" on release/profile builds.
    //
    // Comparing every parameter guarantees that any real change to the
    // lens configuration triggers a repaint.
    return oldDelegate.image != image ||
        oldDelegate.dragOffset != dragOffset ||
        oldDelegate.lensWidth != lensWidth ||
        oldDelegate.lensHeight != lensHeight ||
        oldDelegate.magnification != magnification ||
        oldDelegate.distortion != distortion ||
        oldDelegate.distortionWidth != distortionWidth ||
        oldDelegate.diagonalFlip != diagonalFlip ||
        oldDelegate.enableInnerRadiusTransparent !=
            enableInnerRadiusTransparent ||
        oldDelegate.parentSize != parentSize ||
        !_shapeEquals(oldDelegate.border, border) ||
        oldDelegate.borderAlpha != borderAlpha ||
        oldDelegate.blur.sigmaX != blur.sigmaX ||
        oldDelegate.blur.sigmaY != blur.sigmaY ||
        oldDelegate.color != color ||
        oldDelegate.chromaticAberration != chromaticAberration ||
        oldDelegate.saturation != saturation ||
        oldDelegate.refractionMode != refractionMode ||
        oldDelegate.shader != shader ||
        oldDelegate.borderShader != borderShader;
  }

  bool _shapeEquals(LiquidGlassShape? a, LiquidGlassShape? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.runtimeType != b.runtimeType) return false;
    if (a.borderWidth != b.borderWidth) return false;
    if (a.borderSoftness != b.borderSoftness) return false;
    if (a.borderColor != b.borderColor) return false;
    if (a.lightIntensity != b.lightIntensity) return false;
    if (a.lightColor != b.lightColor) return false;
    if (a.shadowColor != b.shadowColor) return false;
    if (a.lightDirection != b.lightDirection) return false;
    if (a.oneSideLightIntensity != b.oneSideLightIntensity) return false;
    if (a.lightMode != b.lightMode) return false;
    // Optical-border fields (present on this build): compare them too so
    // a change in optical rim styling triggers a repaint.
    if (a.ambientIntensity != b.ambientIntensity) return false;
    if (a.doubleSideLightIntensity != b.doubleSideLightIntensity) return false;
    if (a.borderSaturation != b.borderSaturation) return false;
    if (a.borderSolidity != b.borderSolidity) return false;
    if (a.borderMode != b.borderMode) return false;
    if (a is RoundedRectangleShape && b is RoundedRectangleShape) {
      return a.cornerRadius == b.cornerRadius;
    }
    if (a is SuperellipseShape && b is SuperellipseShape) {
      return a.curveExponent == b.curveExponent;
    }
    return true;
  }
}

class LiquidGlassBorderPainter extends CustomPainter {
  final ui.FragmentShader borderShader;
  final Offset lensPosition;
  final double lensWidth;
  final double lensHeight;
  final double magnification;
  final double distortion;
  final double distortionWidth;
  final double diagonalFlip;
  final bool enableInnerRadiusTransparent;
  final double chromaticAberration;
  final double saturation;
  final LiquidGlassRefractionMode refractionMode;
  final LiquidGlassShape border;
  final double borderAlpha;
  final ui.Image image;

  LiquidGlassBorderPainter({
    required this.borderShader,
    required this.lensPosition,
    required this.lensWidth,
    required this.lensHeight,
    required this.magnification,
    required this.distortion,
    required this.distortionWidth,
    required this.diagonalFlip,
    required this.enableInnerRadiusTransparent,
    required this.chromaticAberration,
    required this.saturation,
    required this.refractionMode,
    required this.border,
    required this.borderAlpha,
    required this.image,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double selectedLightMode =
        (border.lightMode == LiquidGlassLightMode.edge) ? 0 : 1;
    final double selectedBorderMode =
        (border.borderMode == LiquidGlassBorderMode.classic) ? 0 : 1;
    final double selectedRefractionMode =
        (refractionMode == LiquidGlassRefractionMode.shapeRefraction) ? 0 : 1;

    final rect = Rect.fromLTWH(
      lensPosition.dx,
      lensPosition.dy,
      lensWidth,
      lensHeight,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(
        border is RoundedRectangleShape
            ? (border as RoundedRectangleShape).cornerRadius
            : 0,
      ),
    );

    int index = 0;
    borderShader
      ..setFloat(index++, size.width)
      ..setFloat(index++, size.height)
      ..setFloat(index++, lensPosition.dx)
      ..setFloat(index++, lensPosition.dy)
      ..setFloat(index++, lensWidth)
      ..setFloat(index++, lensHeight)
      ..setFloat(index++, border is SuperellipseShape ? 1 : 0)
      ..setFloat(
          index++,
          border is RoundedRectangleShape
              ? (border as RoundedRectangleShape).cornerRadius
              : 0)
      ..setFloat(
          index++,
          border is SuperellipseShape
              ? (border as SuperellipseShape).curveExponent
              : 0)
      ..setFloat(index++, magnification)
      ..setFloat(index++, distortion)
      ..setFloat(index++, distortionWidth)
      ..setFloat(index++, enableInnerRadiusTransparent ? 1.0 : 0.0)
      ..setFloat(index++, diagonalFlip)
      ..setFloat(index++, border.borderWidth)
      ..setFloat(index++, border.borderSoftness)
      ..setFloat(index++, border.borderColor?.r ?? 0)
      ..setFloat(index++, border.borderColor?.g ?? 0)
      ..setFloat(index++, border.borderColor?.b ?? 0)
      ..setFloat(index++, border.borderColor?.a ?? 0)
      ..setFloat(index++, borderAlpha)
      ..setFloat(index++, border.lightIntensity)
      ..setFloat(index++, border.lightColor.r)
      ..setFloat(index++, border.lightColor.g)
      ..setFloat(index++, border.lightColor.b)
      ..setFloat(index++, border.lightColor.a)
      ..setFloat(index++, border.shadowColor.r)
      ..setFloat(index++, border.shadowColor.g)
      ..setFloat(index++, border.shadowColor.b)
      ..setFloat(index++, border.shadowColor.a)
      ..setFloat(index++, border.lightDirection)
      ..setFloat(
          index++,
          border.isOpticalBorder ? 0.0 : border.oneSideLightIntensity)
      ..setFloat(index++, chromaticAberration)
      ..setFloat(index++, saturation)
      ..setFloat(index++, selectedLightMode)
      ..setFloat(index++, selectedRefractionMode)
      ..setFloat(index++, border.ambientIntensity)
      ..setFloat(
          index++,
          border.isOpticalBorder ? 0.0 : border.doubleSideLightIntensity)
      ..setFloat(index++, border.borderSaturation)
      ..setFloat(index++, border.borderSolidity)
      ..setFloat(index++, selectedBorderMode);

    borderShader.setImageSampler(0, image);

    final paint = Paint()..shader = borderShader;

    // In optical mode, use additive blending
    // if (border.borderMode == LiquidGlassBorderMode.optical) {
    //   paint.blendMode = BlendMode.overlay;
    // }

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant LiquidGlassBorderPainter oldDelegate) {
    // Mirror LiquidGlassPainter.shouldRepaint: only repaint when a value
    // that actually feeds the border shader changes. Previously this
    // returned `true` unconditionally, so the second-pass border shader
    // re-ran every frame even for a completely idle lens.
    return oldDelegate.image != image ||
        oldDelegate.lensPosition != lensPosition ||
        oldDelegate.lensWidth != lensWidth ||
        oldDelegate.lensHeight != lensHeight ||
        oldDelegate.magnification != magnification ||
        oldDelegate.distortion != distortion ||
        oldDelegate.distortionWidth != distortionWidth ||
        oldDelegate.diagonalFlip != diagonalFlip ||
        oldDelegate.enableInnerRadiusTransparent !=
            enableInnerRadiusTransparent ||
        oldDelegate.chromaticAberration != chromaticAberration ||
        oldDelegate.saturation != saturation ||
        oldDelegate.refractionMode != refractionMode ||
        oldDelegate.borderAlpha != borderAlpha ||
        oldDelegate.borderShader != borderShader ||
        !_shapeEquals(oldDelegate.border, border);
  }

  bool _shapeEquals(LiquidGlassShape a, LiquidGlassShape b) {
    if (identical(a, b)) return true;
    if (a.runtimeType != b.runtimeType) return false;
    if (a.borderWidth != b.borderWidth) return false;
    if (a.borderSoftness != b.borderSoftness) return false;
    if (a.borderColor != b.borderColor) return false;
    if (a.lightIntensity != b.lightIntensity) return false;
    if (a.lightColor != b.lightColor) return false;
    if (a.shadowColor != b.shadowColor) return false;
    if (a.lightDirection != b.lightDirection) return false;
    if (a.oneSideLightIntensity != b.oneSideLightIntensity) return false;
    if (a.lightMode != b.lightMode) return false;
    if (a.ambientIntensity != b.ambientIntensity) return false;
    if (a.doubleSideLightIntensity != b.doubleSideLightIntensity) return false;
    if (a.borderSaturation != b.borderSaturation) return false;
    if (a.borderSolidity != b.borderSolidity) return false;
    if (a.borderMode != b.borderMode) return false;
    if (a is RoundedRectangleShape && b is RoundedRectangleShape) {
      return a.cornerRadius == b.cornerRadius;
    }
    if (a is SuperellipseShape && b is SuperellipseShape) {
      return a.curveExponent == b.curveExponent;
    }
    return true;
  }
}
