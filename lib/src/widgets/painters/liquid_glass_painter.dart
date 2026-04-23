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

    shader.setFloat(index++, useBlur ? 0 : border!.borderWidth);
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
    shader.setFloat(index++, border!.oneSideLightIntensity);
    shader.setFloat(index++, chromaticAberration);
    shader.setFloat(index++, saturation);
    shader.setFloat(index++, selectedLightMode);
    shader.setFloat(index, selectedRefractionMode);

    shader.setImageSampler(0, image);

    final borderExpand = border!.borderWidth / 2;
    final rectExpandedBorder = Rect.fromLTWH(
      lensPosition.dx - borderExpand,
      lensPosition.dy - borderExpand,
      lensWidth + 2 * borderExpand,
      lensHeight + 2 * borderExpand,
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

    if (useBlur) {
      lensPaint.imageFilter = ui.ImageFilter.blur(
        sigmaX: blur.sigmaX > 3 ? 3 * borderAlpha : blur.sigmaX * borderAlpha,
        sigmaY: blur.sigmaY > 3 ? 3 * borderAlpha : blur.sigmaX * borderAlpha,
        tileMode: ui.TileMode.clamp,
      );
    }
    canvas.drawRRect(rectRRect, lensPaint);
    //canvas.restore();

// --- PASS 2: BORDER SHADER (sharp, no blur) ---
    if (borderShader != null && useBlur) {
      index = 0;
      borderShader!
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
        ..setFloat(index++, border!.borderWidth)
        ..setFloat(index++, border!.borderSoftness)
        ..setFloat(index++, border!.borderColor?.r ?? 0)
        ..setFloat(index++, border!.borderColor?.g ?? 0)
        ..setFloat(index++, border!.borderColor?.b ?? 0)
        ..setFloat(index++, border!.borderColor?.a ?? 0)
        ..setFloat(index++, borderAlpha)
        ..setFloat(index++, border!.lightIntensity)
        ..setFloat(index++, border!.lightColor.r)
        ..setFloat(index++, border!.lightColor.g)
        ..setFloat(index++, border!.lightColor.b)
        ..setFloat(index++, border!.lightColor.a)
        ..setFloat(index++, border!.shadowColor.r)
        ..setFloat(index++, border!.shadowColor.g)
        ..setFloat(index++, border!.shadowColor.b)
        ..setFloat(index++, border!.shadowColor.a)
        ..setFloat(index++, border!.lightDirection)
        ..setFloat(index++, border!.oneSideLightIntensity)
        ..setFloat(index, selectedLightMode);

      final borderPaint = Paint()..shader = borderShader;

      // Draw the sharp border directly on top
      canvas.drawRRect(rectRRect, borderPaint);
    }
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
    if (a is RoundedRectangleShape && b is RoundedRectangleShape) {
      return a.cornerRadius == b.cornerRadius;
    }
    if (a is SuperellipseShape && b is SuperellipseShape) {
      return a.curveExponent == b.curveExponent;
    }
    return true;
  }
}
