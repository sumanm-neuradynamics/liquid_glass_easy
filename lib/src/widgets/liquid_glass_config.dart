import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_mode.dart';

// Represents a single lens in the LiquidGlass system
class LiquidGlass {
  /// Optional widget key, propagated to the underlying `LiquidGlassWidget`
  /// inside `LiquidGlassView`. Use it to bind a lens `State` to a logical
  /// slot (e.g. a fixed UI position) rather than to its index in `children`.
  /// Without a stable key, inserting/removing other lenses (e.g. a progress
  /// bar) can cause Flutter to reuse the wrong `State` for a lens.
  final Key? key;

  /// Controls the lens behavior programmatically, such as toggling visibility or
  /// updating properties dynamically at runtime.
  final LiquidGlassController? controller;

  /// The width of the lens in logical pixels.
  final double width;

  /// The height of the lens in logical pixels.
  final double height;

  /// Defines how much the lens magnifies (zooms in on) the distorted content.
  ///
  /// - `1.0` means no magnification.
  final double magnification;

  /// Defines how light is refracted through the liquid glass surface.
  ///
  /// This determines the visual distortion pattern applied to the
  /// background behind the glass effect:
  ///
  /// • [LiquidGlassRefractionMode.shapeRefraction] — Refracts light
  ///   based on the underlying shape geometry, following the contours
  ///   of the glass for a more physically accurate distortion.
  ///
  /// • [LiquidGlassRefractionMode.radialRefraction] — Refracts light
  ///   radially from a central point, creating a circular
  ///   distortion pattern.
  final LiquidGlassRefractionMode refractionMode;

  /// The bending strength of the distortion effect.
  ///
  /// Controls how much the refracted (bent) background is warped inside the
  /// distortion width area. Higher values increase compression within the
  /// distortion zone, creating a stronger bending effect. Lower values reduce
  /// compression and produce softer distortion.
  ///
  /// - **Range:** `0.0` (no distortion) to `1.0` (maximum distortion).
  final double distortion;

  /// The thickness of the distortion band around the lens perimeter.
  ///
  /// This defines how wide the bending/refraction zone is. Larger values create
  /// a thicker distortion border, affecting more of the background. Smaller values
  /// produce a thinner, tighter distortion edge.
  ///
  /// - **Unit:** logical pixels
  /// - **Typical range:** `0.0` (no distortion band) to around `50.0`+ depending
  ///   on the lens size and desired visual intensity.
  final double distortionWidth;

  /// Applies a diagonal mirroring or flip effect to the refraction direction.
  ///
  /// Used to create artistic or mirrored lens effects.
  final double diagonalFlip;

  /// Determines whether the lens can be dragged (moved) by the user.
  final bool draggable;

  /// Optional widget content displayed inside the lens area.
  ///
  /// Can be used to show overlays, icons, or custom visual elements.
  final Widget? child;

  /// The position of the lens on screen.
  ///
  /// Can be defined either as an absolute `Offset` or a relative `Alignment` value.
  final LiquidGlassPosition position;

  /// The geometric shape of the lens and its optional border.
  ///
  /// Use [RoundedRectangleShape]; its `cornerSmoothing` enables
  /// Apple-style continuous corners.
  final LiquidGlassShape shape;

  /// The blur configuration for the lens background.
  ///
  /// Controls how the underlying content is blurred beneath the glass.
  final LiquidGlassBlur blur;

  /// Controls the intensity of the chromatic aberration effect.
  ///
  /// Higher values increase the separation of color channels,
  /// creating a stronger chromatic distortion. The default value is 0.003. A value of `0.0`
  /// disables the effect.
  final double chromaticAberration;

  /// Controls the color saturation level of the rendered output.
  ///
  /// Values greater than `1.0` increase color intensity, while
  /// values between `0.0` and `1.0` reduce saturation. A value of
  /// `0.0` results in a grayscale image.
  final double saturation;

  /// Whether the inner, non-distorted region should be transparent.
  ///
  /// When enabled, the unaffected center area will reveal the background directly.
  final bool enableInnerRadiusTransparent;

  /// Whether the lens is currently visible or hidden in the view.
  final bool visibility;

  /// The base color tint of the lens.
  ///
  /// Can be semi-transparent to create colored glass effects.
  final Color color;

  /// Whether this lens is allowed to move outside the boundaries
  /// of its parent container.
  ///
  /// When set to `true`, the lens can partially or fully extend beyond
  /// the visible area of the parent, which can be useful for creative
  /// transitions or edge-based effects.
  ///
  /// When set to `false` (default), the lens position is automatically
  /// clamped to remain fully within the parent’s bounds.
  final bool outOfBoundaries;

  /// When `true`, any refracted **background** sample that comes out
  /// (near) black is rendered fully transparent instead of black, so the
  /// real backdrop behind the view shows through.
  ///
  /// This is meant for **small drop-in lenses over a partly-transparent
  /// captured background** (the slider/toggle glass thumbs): on the Skia
  /// capture path a transparent texel decodes to black, which would draw
  /// the lens overhang as a black blob. With this on, that overhang
  /// becomes transparent passthrough instead. The border (rim light) is
  /// still drawn on top.
  ///
  /// Defaults to `false` — a no-op for full-screen / opaque backgrounds.
  /// False positives (genuinely dark content turning transparent) are
  /// accepted by design.
  final bool transparentWhenBlack;

  const LiquidGlass(
      {this.key,
      this.controller,
      this.width = 200,
      this.height = 100,
      this.magnification = 1,
      this.distortion = 0.1,
      this.distortionWidth = 30,
      this.enableInnerRadiusTransparent = false,
      this.diagonalFlip = 0,
      this.draggable = false,
      this.child,
      required this.position,
      this.shape = const RoundedRectangleShape(),
      this.blur = const LiquidGlassBlur(),
      this.chromaticAberration = 0.003,
      this.saturation = 1.0,
      this.refractionMode = LiquidGlassRefractionMode.shapeRefraction,
      this.visibility = true,
      this.color = Colors.transparent,
      this.outOfBoundaries = false,
      this.transparentWhenBlack = false});

  /// Categorized constructor — the same lens, configured through grouped
  /// objects instead of one flat parameter list:
  ///
  ///  • [LiquidGlassGeometry]   — size, shape, placement.
  ///  • [LiquidGlassRefraction] — how the glass bends light (distortion,
  ///    magnification, chromatic aberration, refraction mode).
  ///  • [LiquidGlassAppearance] — appearance: tint, blur, saturation.
  ///  • [LiquidGlassBehavior]   — interaction & lifecycle.
  ///
  /// This is purely additive: it unpacks the groups into the same flat
  /// fields the renderer reads, so the default [LiquidGlass] constructor
  /// keeps working exactly as before. Pick whichever reads better at the
  /// call site.
  ///
  /// ```dart
  /// LiquidGlass.grouped(
  ///   geometry: LiquidGlassGeometry(
  ///     position: const LiquidGlassAlignPosition(alignment: Alignment.center),
  ///     width: 240, height: 160,
  ///     shape: const RoundedRectangleShape(cornerRadius: 36),
  ///   ),
  ///   refraction: const LiquidGlassRefraction(
  ///     distortion: 0.12, distortionWidth: 28,
  ///   ),
  ///   appearance: const LiquidGlassAppearance(
  ///     blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2), color: Color(0x16FFFFFF),
  ///   ),
  ///   behavior: const LiquidGlassBehavior(draggable: true),
  ///   child: const Center(child: Text('drag me')),
  /// );
  /// ```
  LiquidGlass.grouped({
    this.key,
    this.child,
    required LiquidGlassGeometry geometry,
    LiquidGlassRefraction refraction = const LiquidGlassRefraction(),
    LiquidGlassAppearance appearance = const LiquidGlassAppearance(),
    LiquidGlassBehavior behavior = const LiquidGlassBehavior(),
  })  : // ── geometry ──
        width = geometry.width,
        height = geometry.height,
        position = geometry.position,
        shape = geometry.shape,
        outOfBoundaries = geometry.outOfBoundaries,
        // ── refraction ──
        distortion = refraction.distortion,
        distortionWidth = refraction.distortionWidth,
        magnification = refraction.magnification,
        chromaticAberration = refraction.chromaticAberration,
        refractionMode = refraction.refractionMode,
        diagonalFlip = refraction.diagonalFlip,
        // ── appearance ──
        saturation = appearance.saturation,
        blur = appearance.blur,
        color = appearance.color,
        enableInnerRadiusTransparent =
            appearance.enableInnerRadiusTransparent,
        transparentWhenBlack = appearance.transparentWhenBlack,
        // ── behavior ──
        draggable = behavior.draggable,
        visibility = behavior.visibility,
        controller = behavior.controller;

  /// The geometry group (size, shape, placement) for this lens.
  LiquidGlassGeometry get geometry => LiquidGlassGeometry(
        position: position,
        width: width,
        height: height,
        shape: shape,
        outOfBoundaries: outOfBoundaries,
      );

  /// The refraction group (how the glass bends light) for this lens.
  LiquidGlassRefraction get refraction => LiquidGlassRefraction(
        distortion: distortion,
        distortionWidth: distortionWidth,
        magnification: magnification,
        chromaticAberration: chromaticAberration,
        refractionMode: refractionMode,
        diagonalFlip: diagonalFlip,
      );

  /// The appearance group (tint, blur, saturation) for this lens.
  LiquidGlassAppearance get appearance => LiquidGlassAppearance(
        saturation: saturation,
        blur: blur,
        color: color,
        enableInnerRadiusTransparent: enableInnerRadiusTransparent,
        transparentWhenBlack: transparentWhenBlack,
      );

  /// The behavior group (interaction, lifecycle) for this lens.
  LiquidGlassBehavior get behavior => LiquidGlassBehavior(
        draggable: draggable,
        visibility: visibility,
        controller: controller,
      );

  /// Returns a copy of this lens config with the given fields replaced.
  ///
  /// Note this always returns a base [LiquidGlass]; subclass identity
  /// (e.g. [LiquidGlass] components) is not preserved, but every visual
  /// field is — which is all [LiquidGlassView] reads. Used internally by
  /// `LiquidGlassScaffold` to re-position a slot (e.g. shift the app bar
  /// below the status bar) without rebuilding the developer's widget.
  LiquidGlass copyWith({
    Key? key,
    LiquidGlassController? controller,
    double? width,
    double? height,
    double? magnification,
    LiquidGlassRefractionMode? refractionMode,
    double? distortion,
    double? distortionWidth,
    double? diagonalFlip,
    bool? draggable,
    Widget? child,
    LiquidGlassPosition? position,
    LiquidGlassShape? shape,
    LiquidGlassBlur? blur,
    double? chromaticAberration,
    double? saturation,
    bool? enableInnerRadiusTransparent,
    bool? visibility,
    Color? color,
    bool? outOfBoundaries,
    bool? transparentWhenBlack,
  }) {
    return LiquidGlass(
      key: key ?? this.key,
      controller: controller ?? this.controller,
      width: width ?? this.width,
      height: height ?? this.height,
      magnification: magnification ?? this.magnification,
      refractionMode: refractionMode ?? this.refractionMode,
      distortion: distortion ?? this.distortion,
      distortionWidth: distortionWidth ?? this.distortionWidth,
      diagonalFlip: diagonalFlip ?? this.diagonalFlip,
      draggable: draggable ?? this.draggable,
      child: child ?? this.child,
      position: position ?? this.position,
      shape: shape ?? this.shape,
      blur: blur ?? this.blur,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      saturation: saturation ?? this.saturation,
      enableInnerRadiusTransparent:
          enableInnerRadiusTransparent ?? this.enableInnerRadiusTransparent,
      visibility: visibility ?? this.visibility,
      color: color ?? this.color,
      outOfBoundaries: outOfBoundaries ?? this.outOfBoundaries,
      transparentWhenBlack: transparentWhenBlack ?? this.transparentWhenBlack,
    );
  }
}

/// **Geometry** group: where the lens is and what shape/size it has.
///
/// One of the three categories accepted by [LiquidGlass.grouped]. Defaults
/// mirror the flat [LiquidGlass] constructor, so swapping APIs is lossless.
class LiquidGlassGeometry {
  /// The placement of the lens (absolute offset or relative alignment).
  final LiquidGlassPosition position;

  /// The width of the lens in logical pixels.
  final double width;

  /// The height of the lens in logical pixels.
  final double height;

  /// The geometric shape of the lens and its optional border.
  final LiquidGlassShape shape;

  /// Whether the lens may extend outside the parent's bounds (vs. being
  /// clamped inside it).
  final bool outOfBoundaries;

  const LiquidGlassGeometry({
    required this.position,
    this.width = 200,
    this.height = 100,
    this.shape = const RoundedRectangleShape(),
    this.outOfBoundaries = false,
  });

  LiquidGlassGeometry copyWith({
    LiquidGlassPosition? position,
    double? width,
    double? height,
    LiquidGlassShape? shape,
    bool? outOfBoundaries,
  }) {
    return LiquidGlassGeometry(
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      shape: shape ?? this.shape,
      outOfBoundaries: outOfBoundaries ?? this.outOfBoundaries,
    );
  }
}

/// **Refraction** group: how the glass bends light — the optical
/// distortion of the content behind the lens.
///
/// One of the categories accepted by [LiquidGlass.grouped]. Defaults
/// mirror the flat [LiquidGlass] constructor, so swapping APIs is lossless.
class LiquidGlassRefraction {
  /// Bending strength of the distortion (`0.0`–`1.0`).
  final double distortion;

  /// Thickness of the distortion band around the perimeter, in px.
  final double distortionWidth;

  /// Magnification of the content seen through the lens (`1.0` = none).
  final double magnification;

  /// Strength of the chromatic aberration (color-channel separation).
  final double chromaticAberration;

  /// How light is refracted through the surface (shape vs. radial).
  final LiquidGlassRefractionMode refractionMode;

  /// Diagonal mirroring/flip of the refraction direction.
  final double diagonalFlip;

  const LiquidGlassRefraction({
    this.distortion = 0.1,
    this.distortionWidth = 30,
    this.magnification = 1,
    this.chromaticAberration = 0.003,
    this.refractionMode = LiquidGlassRefractionMode.shapeRefraction,
    this.diagonalFlip = 0,
  });

  LiquidGlassRefraction copyWith({
    double? distortion,
    double? distortionWidth,
    double? magnification,
    double? chromaticAberration,
    LiquidGlassRefractionMode? refractionMode,
    double? diagonalFlip,
  }) {
    return LiquidGlassRefraction(
      distortion: distortion ?? this.distortion,
      distortionWidth: distortionWidth ?? this.distortionWidth,
      magnification: magnification ?? this.magnification,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      refractionMode: refractionMode ?? this.refractionMode,
      diagonalFlip: diagonalFlip ?? this.diagonalFlip,
    );
  }
}

/// **Material** group: the lens's appearance — tint, blur, saturation and
/// inner transparency (everything visual that isn't optical refraction).
///
/// One of the categories accepted by [LiquidGlass.grouped]. Defaults
/// mirror the flat [LiquidGlass] constructor, so swapping APIs is lossless.
class LiquidGlassAppearance {
  /// Color saturation of the output (`1.0` = unchanged, `0.0` = grayscale).
  final double saturation;

  /// Blur applied to the content beneath the glass.
  final LiquidGlassBlur blur;

  /// Base color tint of the lens (often semi-transparent).
  final Color color;

  /// Whether the inner, non-distorted region is transparent.
  final bool enableInnerRadiusTransparent;

  /// Whether a refracted background sample that comes out (near) black is
  /// rendered transparent instead of black. See [LiquidGlass.transparentWhenBlack].
  final bool transparentWhenBlack;

  const LiquidGlassAppearance({
    this.saturation = 1.0,
    this.blur = const LiquidGlassBlur(),
    this.color = Colors.transparent,
    this.enableInnerRadiusTransparent = false,
    this.transparentWhenBlack = false,
  });

  LiquidGlassAppearance copyWith({
    double? saturation,
    LiquidGlassBlur? blur,
    Color? color,
    bool? enableInnerRadiusTransparent,
    bool? transparentWhenBlack,
  }) {
    return LiquidGlassAppearance(
      saturation: saturation ?? this.saturation,
      blur: blur ?? this.blur,
      color: color ?? this.color,
      enableInnerRadiusTransparent:
          enableInnerRadiusTransparent ?? this.enableInnerRadiusTransparent,
      transparentWhenBlack: transparentWhenBlack ?? this.transparentWhenBlack,
    );
  }
}

/// **Behavior** group: interaction and lifecycle.
///
/// One of the three categories accepted by [LiquidGlass.grouped]. Defaults
/// mirror the flat [LiquidGlass] constructor, so swapping APIs is lossless.
class LiquidGlassBehavior {
  /// Whether the lens can be dragged by the user.
  final bool draggable;

  /// Whether the lens is currently visible.
  final bool visibility;

  /// Programmatic controller for show/hide/reposition.
  final LiquidGlassController? controller;

  const LiquidGlassBehavior({
    this.draggable = false,
    this.visibility = true,
    this.controller,
  });

  LiquidGlassBehavior copyWith({
    bool? draggable,
    bool? visibility,
    LiquidGlassController? controller,
  }) {
    return LiquidGlassBehavior(
      draggable: draggable ?? this.draggable,
      visibility: visibility ?? this.visibility,
      controller: controller ?? this.controller,
    );
  }
}
