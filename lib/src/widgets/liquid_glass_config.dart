import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_mode.dart';

/// Represents a single lens in the LiquidGlass system, configured
/// through four grouped objects:
///
///  • [LiquidGlassGeometry]   — size, shape, placement (required).
///  • [LiquidGlassRefraction] — how the glass bends light (distortion,
///    magnification, chromatic aberration, refraction mode).
///  • [LiquidGlassAppearance] — tint, blur, saturation.
///  • [LiquidGlassBehavior]   — interaction & lifecycle.
///
/// ```dart
/// LiquidGlass(
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
class LiquidGlass {
  /// Optional widget key, propagated to the underlying `LiquidGlassWidget`
  /// inside `LiquidGlassView`. Use it to bind a lens `State` to a logical
  /// slot (e.g. a fixed UI position) rather than to its index in `children`.
  /// Without a stable key, inserting/removing other lenses (e.g. a progress
  /// bar) can cause Flutter to reuse the wrong `State` for a lens.
  final Key? key;

  /// Optional widget content displayed inside the lens area.
  ///
  /// Can be used to show overlays, icons, or custom visual elements.
  final Widget? child;

  /// Size, shape and placement of the lens.
  final LiquidGlassGeometry geometry;

  /// How the glass bends light.
  final LiquidGlassRefraction refraction;

  /// The lens material: tint, blur, saturation.
  final LiquidGlassAppearance appearance;

  /// Interaction & lifecycle: dragging, visibility, controller.
  final LiquidGlassBehavior behavior;

  const LiquidGlass({
    this.key,
    this.child,
    required this.geometry,
    this.refraction = const LiquidGlassRefraction(),
    this.appearance = const LiquidGlassAppearance(),
    this.behavior = const LiquidGlassBehavior(),
  });

  // ── Flat read accessors ──────────────────────────────────────────
  // Plumbing for the renderers (and subclass components), which read
  // individual values. Configuration happens through the groups above.

  /// Programmatic controller. See [LiquidGlassBehavior.controller].
  LiquidGlassController? get controller => behavior.controller;

  /// Lens width in logical pixels. See [LiquidGlassGeometry.width].
  double get width => geometry.width;

  /// Lens height in logical pixels. See [LiquidGlassGeometry.height].
  double get height => geometry.height;

  /// Lens placement. See [LiquidGlassGeometry.position].
  LiquidGlassPosition get position => geometry.position;

  /// Lens shape + border styling. See [LiquidGlassGeometry.shape].
  LiquidGlassShape get shape => geometry.shape;

  /// Whether the lens may leave the parent's bounds.
  /// See [LiquidGlassGeometry.outOfBoundaries].
  bool get outOfBoundaries => geometry.outOfBoundaries;

  /// Content magnification. See [LiquidGlassRefraction.magnification].
  double get magnification => refraction.magnification;

  /// Refraction pattern. See [LiquidGlassRefraction.refractionMode].
  LiquidGlassRefractionMode get refractionMode => refraction.refractionMode;

  /// Bending strength. See [LiquidGlassRefraction.distortion].
  double get distortion => refraction.distortion;

  /// Distortion band thickness. See [LiquidGlassRefraction.distortionWidth].
  double get distortionWidth => refraction.distortionWidth;

  /// Diagonal refraction flip. See [LiquidGlassRefraction.diagonalFlip].
  double get diagonalFlip => refraction.diagonalFlip;

  /// Color-channel separation. See [LiquidGlassRefraction.chromaticAberration].
  double get chromaticAberration => refraction.chromaticAberration;

  /// Output saturation. See [LiquidGlassAppearance.saturation].
  double get saturation => appearance.saturation;

  /// Background blur under the glass. See [LiquidGlassAppearance.blur].
  LiquidGlassBlur get blur => appearance.blur;

  /// Lens tint. See [LiquidGlassAppearance.color].
  Color get color => appearance.color;

  /// Transparent non-distorted center.
  /// See [LiquidGlassAppearance.enableInnerRadiusTransparent].
  bool get enableInnerRadiusTransparent =>
      appearance.enableInnerRadiusTransparent;

  /// Whether the lens is user-draggable. See [LiquidGlassBehavior.draggable].
  bool get draggable => behavior.draggable;

  /// Whether the lens is shown. See [LiquidGlassBehavior.visibility].
  bool get visibility => behavior.visibility;

  /// Returns a copy of this lens config with the given groups replaced.
  ///
  /// Note this always returns a base [LiquidGlass]; subclass identity
  /// (e.g. [LiquidGlass] components) is not preserved, but every visual
  /// value is — which is all [LiquidGlassView] reads. Used internally by
  /// `LiquidGlassScaffold` to re-position a slot (e.g. shift the app bar
  /// below the status bar) without rebuilding the developer's widget.
  /// To change a single value, copy the group:
  /// `lens.copyWith(geometry: lens.geometry.copyWith(width: 240))`.
  LiquidGlass copyWith({
    Key? key,
    Widget? child,
    LiquidGlassGeometry? geometry,
    LiquidGlassRefraction? refraction,
    LiquidGlassAppearance? appearance,
    LiquidGlassBehavior? behavior,
  }) {
    return LiquidGlass(
      key: key ?? this.key,
      child: child ?? this.child,
      geometry: geometry ?? this.geometry,
      refraction: refraction ?? this.refraction,
      appearance: appearance ?? this.appearance,
      behavior: behavior ?? this.behavior,
    );
  }
}

/// **Geometry** group: where the lens is and what shape/size it has.
///
/// One of the four configuration groups accepted by [LiquidGlass].
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
/// One of the four configuration groups accepted by [LiquidGlass].
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
/// One of the four configuration groups accepted by [LiquidGlass].
class LiquidGlassAppearance {
  /// Color saturation of the output (`1.0` = unchanged, `0.0` = grayscale).
  final double saturation;

  /// Blur applied to the content beneath the glass.
  final LiquidGlassBlur blur;

  /// Base color tint of the lens (often semi-transparent).
  final Color color;

  /// Whether the inner, non-distorted region is transparent.
  final bool enableInnerRadiusTransparent;

  const LiquidGlassAppearance({
    this.saturation = 1.0,
    this.blur = const LiquidGlassBlur(),
    this.color = Colors.transparent,
    this.enableInnerRadiusTransparent = false,
  });

  LiquidGlassAppearance copyWith({
    double? saturation,
    LiquidGlassBlur? blur,
    Color? color,
    bool? enableInnerRadiusTransparent,
  }) {
    return LiquidGlassAppearance(
      saturation: saturation ?? this.saturation,
      blur: blur ?? this.blur,
      color: color ?? this.color,
      enableInnerRadiusTransparent:
          enableInnerRadiusTransparent ?? this.enableInnerRadiusTransparent,
    );
  }
}

/// **Behavior** group: interaction and lifecycle.
///
/// One of the four configuration groups accepted by [LiquidGlass].
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
