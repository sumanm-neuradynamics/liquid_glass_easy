import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../liquid_glass_config.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_lens_scope.dart';
import 'liquid_glass_shaders.dart';
import 'render_liquid_glass_lens.dart';

/// A liquid-glass lens you can place **anywhere in the widget tree**.
///
/// Unlike the `children:` slot of `LiquidGlassView`, this lens is
/// layout-driven: it has no position or size parameters — it is exactly
/// where layout puts it and exactly as big as its constraints/[child]
/// make it (wrap it in a `SizedBox` to give it explicit dimensions).
///
/// ## Render modes (resolved automatically)
///
/// * **Impeller** (`ImageFilter.isShaderFilterSupported`): the lens
///   refracts the live backdrop — whatever your app painted behind it.
///   No `LiquidGlassView` and **no background widget needed at all**;
///   drop it over any UI and it works.
/// * **Skia / Web with an ancestor [LiquidGlassView]** that has a
///   `backgroundWidget`: the lens refracts the view's captured
///   background, wherever the lens sits inside the view's `child`.
/// * **Skia / Web without a view (or without a background)**: refraction
///   is impossible, so the lens degrades to a frosted look — backdrop
///   blur + tint + border, no refraction — and logs a one-time debug
///   warning.
///
/// The mode is an implementation detail: the widget tree you write is
/// identical in all three cases.
///
/// ```dart
/// SizedBox(
///   width: 220,
///   height: 120,
///   child: LiquidGlassLens(
///     shape: const RoundedRectangleShape(cornerRadius: 36),
///     child: const Center(child: Text('glass')),
///   ),
/// )
/// ```
class LiquidGlassLens extends StatefulWidget {
  /// The geometric shape of the lens and its border styling.
  final LiquidGlassShape shape;

  /// How the glass bends light (distortion, magnification, chromatic
  /// aberration, refraction mode).
  final LiquidGlassRefraction refraction;

  /// The lens material: tint, blur, saturation.
  final LiquidGlassAppearance appearance;

  /// Whether the glass effect is shown. Changing this animates the
  /// glass in/out over [visibilityDuration] (the [child] stays —
  /// control it separately if it should hide too).
  final bool visibility;

  /// Duration of the show/hide animation driven by [visibility].
  final Duration visibilityDuration;

  /// Override for the Impeller fast-path detection, like
  /// `LiquidGlassView.useImpellerBackdrop`. When null, inherits the
  /// ancestor view's setting, falling back to
  /// `ImageFilter.isShaderFilterSupported`.
  final bool? useImpellerBackdrop;

  /// Content rendered on top of the glass, clipped to the lens shape.
  final Widget? child;

  const LiquidGlassLens({
    super.key,
    this.shape = const RoundedRectangleShape(),
    this.refraction = const LiquidGlassRefraction(),
    this.appearance = const LiquidGlassAppearance(),
    this.visibility = true,
    this.visibilityDuration = const Duration(milliseconds: 600),
    this.useImpellerBackdrop,
    this.child,
  });

  @override
  State<LiquidGlassLens> createState() => _LiquidGlassLensState();
}

class _LiquidGlassLensState extends State<LiquidGlassLens>
    with SingleTickerProviderStateMixin {
  /// One-time debug notice when a lens has to degrade to frosted glass.
  static bool _warnedFrostedFallback = false;

  /// Show/hide animation driver. Created lazily on the FIRST visibility
  /// change — a lens whose `visibility` never changes carries no
  /// controller and no ticker at all. (Never a lazy `late final`: that
  /// would get its first touch inside dispose(), creating a ticker
  /// during tree finalization — an illegal ancestor lookup.)
  AnimationController? _visibilityController;

  /// Per-lens shader instances, created from the shared program cache.
  /// Deliberately not disposed manually: retained layers may still
  /// reference them during teardown (mirrors the legacy view, which
  /// also relies on GC finalizers for shader instances).
  ui.FragmentShader? _mainShader;
  ui.FragmentShader? _borderShader;

  @override
  void initState() {
    super.initState();
    if (!LiquidGlassShaders.isLoaded) {
      LiquidGlassShaders.ensureLoaded().then((_) {
        if (mounted) setState(() {});
      }).catchError((Object _) {
        // Shaders unavailable (broken build / unsupported test env):
        // the lens simply stays on the frosted fallback.
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassLens oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visibilityController?.duration = widget.visibilityDuration;
    if (widget.visibility != oldWidget.visibility) {
      final controller = _visibilityController ??= AnimationController(
        vsync: this,
        duration: widget.visibilityDuration,
        // 0 = fully shown, 1 = fully hidden (legacy convention). Start
        // from the state we are leaving.
        value: oldWidget.visibility ? 0.0 : 1.0,
      );
      controller.animateTo(
        widget.visibility ? 0.0 : 1.0,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _visibilityController?.dispose();
    super.dispose();
  }

  /// Resolves the show/hide animation into plain parameter values —
  /// the ONE place the hide interpolation is defined for this widget.
  /// At `anim == 0` the caller's values pass through untouched; at
  /// `anim == 1` the glass is optically neutral (and the render object
  /// is disabled entirely via `glassEnabled`).
  ({
    LiquidGlassRefraction refraction,
    LiquidGlassAppearance appearance,
    double borderAlpha,
  }) _resolveHideAnimation(double anim) {
    if (anim == 0.0) {
      return (
        refraction: widget.refraction,
        appearance: widget.appearance,
        borderAlpha: 1.0,
      );
    }
    final r = widget.refraction;
    final a = widget.appearance;
    return (
      refraction: r.copyWith(
        magnification: anim + r.magnification * (1 - anim),
        distortionWidth: r.distortionWidth * (1 - anim),
        chromaticAberration: r.chromaticAberration * (1 - anim),
      ),
      appearance: a.copyWith(
        saturation: anim + a.saturation * (1 - anim),
        blur: LiquidGlassBlur(
          sigmaX: a.blur.sigmaX * (1 - anim),
          sigmaY: a.blur.sigmaY * (1 - anim),
        ),
      ),
      borderAlpha: 1 - anim,
    );
  }

  void _warnFrostedOnce(String reason) {
    assert(() {
      if (!_warnedFrostedFallback) {
        _warnedFrostedFallback = true;
        debugPrint(
          'LiquidGlassLens: refraction unavailable ($reason). '
          'Falling back to a frosted (blur + tint) look. Refraction '
          'needs Impeller, or an ancestor LiquidGlassView with a '
          'backgroundWidget on Skia/Web.',
        );
      }
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    final LiquidGlassLensScope? scope = LiquidGlassLensScope.maybeOf(context);
    final bool impeller = widget.useImpellerBackdrop ??
        scope?.useImpellerBackdrop ??
        ui.ImageFilter.isShaderFilterSupported;

    LiquidGlassLensRenderMode? mode;
    if (impeller) {
      mode = LiquidGlassLensRenderMode.impellerBackdrop;
    } else if (scope != null && scope.hasBackground) {
      mode = LiquidGlassLensRenderMode.skiaCapture;
    } else {
      _warnFrostedOnce(scope == null
          ? 'no Impeller and no ancestor LiquidGlassView'
          : 'no Impeller and the ancestor LiquidGlassView has no '
              'backgroundWidget');
    }

    if (mode == null || !LiquidGlassShaders.isLoaded) {
      // Frosted fallback — also shown for the brief async shader load
      // on the very first lens of the app's lifetime.
      return _FrostedGlassFallback(
        shape: widget.shape,
        appearance: widget.appearance,
        visible: widget.visibility,
        duration: widget.visibilityDuration,
        child: widget.child,
      );
    }

    _mainShader ??= LiquidGlassShaders.createMainShader();
    if (mode == LiquidGlassLensRenderMode.skiaCapture) {
      _borderShader ??= LiquidGlassShaders.createBorderShader();
    }

    final Size screenSize = MediaQuery.sizeOf(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);

    final Widget? clippedChild = widget.child == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(
              liquidGlassClipCornerRadius(widget.shape),
            ),
            child: widget.child,
          );

    Widget buildLens(double anim) {
      final effective = _resolveHideAnimation(anim);
      return _RawLiquidGlassLens(
        mode: mode!,
        mainShader: _mainShader!,
        borderShader: _borderShader,
        shape: widget.shape,
        refraction: effective.refraction,
        appearance: effective.appearance,
        borderAlpha: effective.borderAlpha,
        glassEnabled: anim < 1.0,
        screenSize: screenSize,
        devicePixelRatio: dpr,
        scope: scope,
        child: clippedChild,
      );
    }

    final AnimationController? controller = _visibilityController;
    if (controller == null) {
      // Visibility never changed: no ticker, no per-frame work — the
      // lens is statically shown or statically hidden.
      return buildLens(widget.visibility ? 0.0 : 1.0);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => buildLens(controller.value),
    );
  }
}

class _RawLiquidGlassLens extends SingleChildRenderObjectWidget {
  final LiquidGlassLensRenderMode mode;
  final ui.FragmentShader mainShader;
  final ui.FragmentShader? borderShader;
  final LiquidGlassShape shape;
  final LiquidGlassRefraction refraction;
  final LiquidGlassAppearance appearance;
  final double borderAlpha;
  final bool glassEnabled;
  final Size screenSize;
  final double devicePixelRatio;
  final LiquidGlassLensScope? scope;

  const _RawLiquidGlassLens({
    required this.mode,
    required this.mainShader,
    required this.borderShader,
    required this.shape,
    required this.refraction,
    required this.appearance,
    required this.borderAlpha,
    required this.glassEnabled,
    required this.screenSize,
    required this.devicePixelRatio,
    required this.scope,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLiquidGlassLens(
      mode: mode,
      mainShader: mainShader,
      borderShader: borderShader,
      shape: shape,
      refraction: refraction,
      appearance: appearance,
      borderAlpha: borderAlpha,
      glassEnabled: glassEnabled,
      screenSize: screenSize,
      devicePixelRatio: devicePixelRatio,
      captureRevision: scope?.captureRevision,
      currentImage: scope?.currentImage,
      captureFallback: scope?.captureFallback,
      backgroundRenderBox: scope?.backgroundRenderBox,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderLiquidGlassLens renderObject) {
    renderObject
      ..mode = mode
      ..mainShader = mainShader
      ..borderShader = borderShader
      ..shape = shape
      ..refraction = refraction
      ..appearance = appearance
      ..borderAlpha = borderAlpha
      ..glassEnabled = glassEnabled
      ..screenSize = screenSize
      ..devicePixelRatio = devicePixelRatio
      ..captureRevision = scope?.captureRevision
      ..currentImage = scope?.currentImage
      ..captureFallback = scope?.captureFallback
      ..backgroundRenderBox = scope?.backgroundRenderBox;
  }
}

/// Non-refracting stand-in: backdrop blur + tint + hairline border.
/// Used where real refraction is impossible (Skia without a captured
/// background) and during the one-time async shader load.
class _FrostedGlassFallback extends StatelessWidget {
  final LiquidGlassShape shape;
  final LiquidGlassAppearance appearance;
  final bool visible;
  final Duration duration;
  final Widget? child;

  const _FrostedGlassFallback({
    required this.shape,
    required this.appearance,
    required this.visible,
    required this.duration,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = liquidGlassClipCornerRadius(shape);
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    // Without refraction, blur is what sells "glass" — give it a floor
    // so a lens configured with zero blur still reads as frosted.
    final double sigmaX =
        appearance.blur.sigmaX > 0 ? appearance.blur.sigmaX : 10.0;
    final double sigmaY =
        appearance.blur.sigmaY > 0 ? appearance.blur.sigmaY : 10.0;
    final Color tint = appearance.color.a > 0
        ? appearance.color
        : const Color(0x14FFFFFF);
    final Color borderColor =
        shape.borderColor ?? const Color(0x40FFFFFF);

    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: duration,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tint,
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor,
                width: shape.borderWidth > 0 ? shape.borderWidth : 1.0,
              ),
            ),
            child: child ?? const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
