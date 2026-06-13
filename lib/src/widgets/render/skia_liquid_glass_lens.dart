import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../liquid_glass_config.dart';
import '../painters/liquid_glass_painter.dart';
import '../utils/liquid_glass_shape.dart';

/// Skia / Web render path for a single lens, extracted from
/// `LiquidGlassWidget`.
///
/// Samples a **captured** snapshot of the background ([image]) through
/// a `CustomPaint` + [LiquidGlassPainter]. When blur is enabled it adds
/// a `BackdropFilter` blur plus a second, sharp border pass
/// ([LiquidGlassBorderPainter]) on top.
///
/// This path does **not** own an `AnimatedBuilder` for the show/hide
/// animation: it reads the already-resolved [animValue] directly and is
/// re-driven by the parent `LiquidGlassView`'s capture ticker (which
/// rebuilds the whole lens every captured frame). The drag [touch]
/// notifier is still listened to locally for the movable hit target.
class SkiaLiquidGlassLens extends StatelessWidget {
  final LiquidGlass config;
  final Size parentSize;

  /// Shared main shader. Null while the program is still loading.
  final ui.FragmentShader? shader;

  /// Captured background snapshot. Null until the first capture lands.
  final ui.Image? image;

  /// Paint-time synchronous capture fallback, used by the painters when
  /// [image] is still null (the first frame after the parent view is
  /// created). Lets a freshly mounted lens refract on its very first
  /// frame instead of waiting for the post-frame capture.
  final ui.Image? Function()? imageFallback;

  /// Shared border shader, used for the sharp second border pass under
  /// blur.
  final ui.FragmentShader? borderShader;

  /// Drag position (lens top-left), owned by the coordinator.
  final ValueNotifier<Offset> touch;

  /// Already-resolved show/hide animation value (`0` = shown, `1` =
  /// hidden), supplied by the coordinator on each parent rebuild.
  final double animValue;

  /// Parent-space rectangle that [image] covers. `null` → the image is a
  /// full-frame capture (image == whole parent). When set, the image is a
  /// captured sub-rect and the shader samples it via that offset/size.
  final Rect? imageRegion;

  const SkiaLiquidGlassLens({
    super.key,
    required this.config,
    required this.parentSize,
    required this.shader,
    required this.image,
    this.imageFallback,
    required this.borderShader,
    required this.touch,
    required this.animValue,
    this.imageRegion,
  });

  @override
  Widget build(BuildContext context) {
    final bool useBlur = config.blur.sigmaX > 0 || config.blur.sigmaY > 0;

    return Stack(
      children: [
        // Shader layer
        IgnorePointer(
          ignoring: true,
          child: SizedBox(
            width: parentSize.width,
            height: parentSize.height,
            child: CustomPaint(
              painter: (shader != null &&
                      (image != null || imageFallback != null))
                  ? LiquidGlassPainter(
                      dragOffset: touch.value,
                      position: config.position,
                      lensWidth: config.width,
                      lensHeight: config.height,
                      magnification: (animValue) +
                          (config.magnification * (1 - animValue)),
                      distortion: config.distortion,
                      distortionWidth: (config.distortionWidth -
                          animValue * config.distortionWidth),
                      diagonalFlip: config.diagonalFlip,
                      enableInnerRadiusTransparent:
                          config.enableInnerRadiusTransparent,
                      draggable: config.draggable,
                      parentSize: parentSize,
                      border: config.shape,
                      borderAlpha: (1 - animValue),
                      blur: config.blur,
                      color: config.color,
                      shader: shader!,
                      image: image,
                      imageFallback: imageFallback,
                      borderShader: borderShader,
                      chromaticAberration:
                          config.chromaticAberration * (1 - animValue),
                      saturation:
                          (animValue) + (config.saturation * (1 - animValue)),
                      refractionMode: config.refractionMode,
                      imageOffset: imageRegion?.topLeft,
                      imageSize: imageRegion?.size,
                    )
                  : null,
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // BackdropFilter blur for rounded-clip shapes (rounded-rect / squircle)
        if (borderShader != null &&
            useBlur &&
            liquidGlassUsesRoundedClip(config.shape))
          Positioned(
            left: touch.value.dx,
            top: touch.value.dy,
            width: config.width,
            height: config.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                liquidGlassClipCornerRadius(config.shape),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: config.blur.sigmaX * (1 - animValue),
                  sigmaY: config.blur.sigmaY * (1 - animValue),
                ),
                child: Container(),
              ),
            ),
          ),

        // // SECOND PASS: border painter ONLY (sharp, isolated)
        if (borderShader != null &&
            (image != null || imageFallback != null) &&
            useBlur)
          IgnorePointer(
            ignoring: true,
            child: CustomPaint(
              painter: LiquidGlassBorderPainter(
                borderShader: borderShader!,
                lensPosition: touch.value,
                lensWidth: config.width,
                lensHeight: config.height,
                magnification:
                    (animValue) + (config.magnification * (1 - animValue)),
                distortion: config.distortion,
                distortionWidth: (config.distortionWidth -
                    animValue * config.distortionWidth),
                diagonalFlip: config.diagonalFlip,
                enableInnerRadiusTransparent:
                    config.enableInnerRadiusTransparent,
                chromaticAberration:
                    config.chromaticAberration * (1 - animValue),
                saturation: (animValue) + (config.saturation * (1 - animValue)),
                refractionMode: config.refractionMode,
                border: config.shape,
                borderAlpha: (1 - animValue),
                image: image,
                imageFallback: imageFallback,
                imageOffset: imageRegion?.topLeft,
                imageSize: imageRegion?.size,
              ),
              size: Size.infinite,
            ),
          ),

        // Draggable lens
        ValueListenableBuilder<Offset>(
          valueListenable: touch,
          builder: (context, offset, child) {
            return Positioned(
              left: offset.dx,
              top: offset.dy,
              width: config.width - config.shape.borderWidth / 2,
              height: config.height - config.shape.borderWidth / 2,
              child: GestureDetector(
                behavior: HitTestBehavior
                    .opaque, // ensures full area receives gestures
                onPanUpdate: config.draggable
                    ? (details) {
                        touch.value += details.delta;
                      }
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    liquidGlassClipCornerRadius(config.shape),
                  ),
                  child: config.child ??
                      Container(
                        color: Colors.transparent,
                      ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
