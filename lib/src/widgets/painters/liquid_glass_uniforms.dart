import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../utils/liquid_glass_light_mode.dart';
import '../utils/liquid_glass_refraction_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// Single source of truth for the liquid-glass fragment-shader uniform
/// block.
///
/// The same ~38-uniform layout is shared by **three** call sites that
/// previously each hand-copied the `setFloat(i++, ...)` sequence in the
/// exact order the `.frag` declares its uniforms:
///
///  1. `LiquidGlassPainter`        — Skia main pass        (scale `1.0`)
///  2. `LiquidGlassBorderPainter`  — Skia blur border pass (scale `1.0`)
///  3. `_setMainShaderUniformsForBackdrop` — Impeller path (scale `dpr`)
///
/// Keeping the order in one function makes Impeller↔Skia drift
/// structurally impossible: reorder/add a uniform here once and all
/// three paths stay in sync.
///
/// ## Scale
/// Spatial uniforms (resolution, touch, lens size, corner radius,
/// distortion thickness, border width) are multiplied by [scale].
/// The Skia paths bind the shader via `Paint.shader` and run in
/// **logical** pixels, so they pass `scale: 1.0`. The Impeller path
/// binds via `ImageFilter.shader`, where `FlutterFragCoord()` returns
/// **physical** pixels, so it passes `scale: devicePixelRatio`. Callers
/// always provide logical values; the physical conversion lives here.
///
/// ## Border shader variant
/// The border shader (`liquid_glass_border.frag`) is identical to the
/// main shader except it has **no `u_lensColor`**. Pass
/// [includeLensColor] `false` for that shader so the four lens-color
/// floats are skipped and the remaining indices stay aligned.
///
/// ## Sampler
/// This function only writes the `setFloat` uniforms. The image sampler
/// (`u_texture_input`) is intentionally **not** bound here: the Skia
/// paths bind a captured image (`setImageSampler`), while the Impeller
/// path lets `BackdropFilter` feed the live backdrop automatically. The
/// caller owns that decision.
void packLiquidGlassUniforms(
  ui.FragmentShader shader, {
  required LiquidGlassShape shape,
  required double scale,
  required Size resolution,
  required Offset lensPosition,
  required double lensWidth,
  required double lensHeight,
  required double magnification,
  required double distortion,

  /// Effective (anim-adjusted) distortion band thickness, in logical px.
  required double distortionWidth,
  required bool enableInnerRadiusTransparent,
  required double diagonalFlip,

  /// Border width in logical px. The caller decides the multiplier:
  /// the main pass uses `borderWidth * 2` (or `0` when the border is
  /// suppressed for the blur path), the border pass uses `borderWidth`.
  required double borderWidth,
  required double borderAlpha,
  required double chromaticAberration,
  required double saturation,
  required LiquidGlassRefractionMode? refractionMode,

  /// Whether to emit the four `u_lensColor` floats. `true` for the main
  /// shader, `false` for the border shader (which lacks that uniform).
  required bool includeLensColor,
  Color lensColor = const Color(0x00000000),

  /// Whether the shader should fold the sampled backdrop's alpha into the
  /// lens coverage. `true` on the Skia capture path (the bound snapshot
  /// has meaningful authored transparency); `false` on the Impeller path
  /// (the live backdrop's alpha is not a transparency signal and reads 0
  /// over dark regions). Only emitted for the main shader — the border
  /// shader has no coverage step and no such uniform.
  bool honorBackdropAlpha = true,

  /// Parent-space rectangle the bound texture covers, in logical px.
  /// Defaults (offset `(0,0)`, size == [resolution]) reproduce the old
  /// full-frame `refrPx / u_resolution` sampling. The Impeller path always
  /// samples the full live backdrop, so it leaves these at the defaults.
  Offset imageOffset = Offset.zero,
  Size? imageSize,
}) {
  final double selectedLightMode =
      (shape.lightMode == LiquidGlassLightMode.edge) ? 0 : 1;
  final double selectedRefractionMode =
      (refractionMode == LiquidGlassRefractionMode.shapeRefraction) ? 0 : 1;
  final double selectedBorderMode =
      (shape.borderMode == LiquidGlassBorderMode.classic) ? 0 : 1;

  final double cornerRadius = shape.cornerRadius;
  // The shape type alone selects the corner SDF in the shader:
  // 2 = continuous (capsule), 1 = squircle (full smoothing), 0 = circular.
  final double cornerStyle = liquidGlassCornerStyle(shape);

  int i = 0;
  // u_resolution
  shader.setFloat(i++, resolution.width * scale);
  shader.setFloat(i++, resolution.height * scale);
  // u_touch (lens top-left)
  shader.setFloat(i++, lensPosition.dx * scale);
  shader.setFloat(i++, lensPosition.dy * scale);

  // u_lensWidth / u_lensHeight
  shader.setFloat(i++, lensWidth * scale);
  shader.setFloat(i++, lensHeight * scale);
  // u_cornerRadius
  shader.setFloat(i++, cornerRadius * scale);
  // u_cornerStyle (0 = circular, 1 = squircle, 2 = continuous — never scaled)
  shader.setFloat(i++, cornerStyle);

  shader.setFloat(i++, magnification);
  shader.setFloat(i++, distortion);
  // u_distortionThicknessPx
  shader.setFloat(i++, distortionWidth * scale);

  shader.setFloat(i++, enableInnerRadiusTransparent ? 1.0 : 0.0);
  shader.setFloat(i++, diagonalFlip);

  // u_borderWidth
  shader.setFloat(i++, borderWidth * scale);
  shader.setFloat(i++, shape.borderSoftness);

  shader.setFloat(i++, shape.borderColor?.r ?? 0);
  shader.setFloat(i++, shape.borderColor?.g ?? 0);
  shader.setFloat(i++, shape.borderColor?.b ?? 0);
  shader.setFloat(i++, shape.borderColor?.a ?? 0);
  shader.setFloat(i++, borderAlpha);

  shader.setFloat(i++, shape.lightIntensity);

  shader.setFloat(i++, shape.lightColor.r);
  shader.setFloat(i++, shape.lightColor.g);
  shader.setFloat(i++, shape.lightColor.b);
  shader.setFloat(i++, shape.lightColor.a);

  shader.setFloat(i++, shape.shadowColor.r);
  shader.setFloat(i++, shape.shadowColor.g);
  shader.setFloat(i++, shape.shadowColor.b);
  shader.setFloat(i++, shape.shadowColor.a);

  shader.setFloat(i++, shape.lightDirection);

  // u_lensColor — present only on the main shader.
  if (includeLensColor) {
    shader.setFloat(i++, lensColor.r);
    shader.setFloat(i++, lensColor.g);
    shader.setFloat(i++, lensColor.b);
    shader.setFloat(i++, lensColor.a);
  }

  // One-/double-side specular highlights are classic-only: in optical
  // mode the directional term saturates the brightness cap so these
  // contributions become invisible. Zero them on the wire to keep
  // behavior consistent with the UI.
  shader.setFloat(
      i++, shape.isOpticalBorder ? 0.0 : shape.oneSideLightIntensity);
  shader.setFloat(i++, chromaticAberration);
  shader.setFloat(i++, saturation);
  shader.setFloat(i++, selectedLightMode);
  shader.setFloat(i++, selectedRefractionMode);
  shader.setFloat(i++, shape.ambientIntensity);
  shader.setFloat(
      i++, shape.isOpticalBorder ? 0.0 : shape.doubleSideLightIntensity);
  shader.setFloat(i++, shape.borderSaturation);
  shader.setFloat(i++, shape.borderSolidity);
  shader.setFloat(i++, selectedBorderMode);

  // u_imageOffset / u_imageSize — present on BOTH shaders, so always
  // written. Scaled like the other spatial uniforms.
  final Size imgSize = imageSize ?? resolution;
  shader.setFloat(i++, imageOffset.dx * scale);
  shader.setFloat(i++, imageOffset.dy * scale);
  shader.setFloat(i++, imgSize.width * scale);
  shader.setFloat(i++, imgSize.height * scale);

  // u_honorBackdropAlpha + u_shapeAaPx — main shader only (the last two
  // uniforms in liquid_glass.frag; the border shader declares neither, so
  // writing them there would overflow its uniform array).
  if (includeLensColor) {
    shader.setFloat(i++, honorBackdropAlpha ? 1.0 : 0.0);
    // u_shapeAaPx — edge-AA band width in fragment px = one logical pixel.
    // `scale` is 1.0 on Skia (logical-px shader) and dpr on Impeller
    // (physical-px shader), so the coverage ramp is the same physical width
    // on both backends.
    shader.setFloat(i++, scale);
  }
}
