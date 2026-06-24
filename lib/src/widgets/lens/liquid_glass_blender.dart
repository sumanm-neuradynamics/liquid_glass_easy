import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../liquid_glass_style.dart';
import '../painters/liquid_glass_uniforms.dart';
import '../utils/liquid_glass_shape.dart';
import 'liquid_glass_lens_scope.dart';

/// How strongly a neighbour-direction component activates its side:
/// `smoothstep(0, 0.4, x)`. A diagonal neighbour (component ~0.7) fully
/// activates both of its sides; a nearly-perpendicular one barely does.
double _sideDir(double x) {
  final double t = (x / 0.4).clamp(0.0, 1.0).toDouble();
  return t * t * (3.0 - 2.0 * t);
}

/// Blends two to six descendant `LiquidGlassLens` widgets into one surface.
///
/// The descendant lenses keep their normal layout and child content, but their
/// individual glass passes are replaced by one smooth metaball union. The
/// group's [style] controls the shared material; each lens's shape and layout
/// control its contribution to the merged silhouette.
///
/// Place the group inside a `LiquidGlassView.child` for Skia/Web capture
/// support. On Impeller it samples the live backdrop directly.
///
/// ```dart
/// LiquidGlassBlender(
///   smoothness: 48,
///   child: Stack(
///     children: [
///       Positioned(
///         left: 40,
///         top: 80,
///         child: SizedBox(
///           width: 120,
///           height: 80,
///           child: LiquidGlassLens(),
///         ),
///       ),
///       Positioned(
///         left: 130,
///         top: 100,
///         child: SizedBox(
///           width: 100,
///           height: 100,
///           child: LiquidGlassLens(),
///         ),
///       ),
///     ],
///   ),
/// )
/// ```
class LiquidGlassBlender extends StatefulWidget {
  static const int minLensCount = 2;
  static const int maxLensCount = 6;

  const LiquidGlassBlender({
    super.key,
    required this.child,
    this.style = const LiquidGlassStyle(),
    this.smoothness = 48,
    this.perSideMorph = true,
    this.useImpellerBackdrop,
    this.useEngineBlur = true,
  }) : assert(smoothness > 0);

  /// Any widget tree containing two to six `LiquidGlassLens` descendants.
  final Widget child;

  /// The shared material used after the lens silhouettes are merged.
  final LiquidGlassStyle style;

  /// Radius, in logical pixels, over which nearby lens outlines flow together.
  final double smoothness;

  /// How continuous (Apple capsule-style) lenses morph toward a circular
  /// rounded rectangle as neighbours close in — so the capsule corners don't
  /// fight the metaball bridge.
  ///
  /// * `true` (default): **per-side estimation.** Only the corners on the
  ///   side(s) actually facing a close neighbour (and all corners when a
  ///   neighbour sinks inside) morph; the rest of the lens keeps its capsule
  ///   corners. Localized and subtle.
  /// * `false`: **whole-shape morph.** The entire continuous lens morphs to a
  ///   circular rounded rectangle by its overall proximity to any neighbour —
  ///   every corner rounds together, regardless of direction.
  ///
  /// Only continuous lenses are affected either way; squircle and circular
  /// members are never morphed.
  final bool perSideMorph;

  /// Overrides renderer detection. When null, inherits `LiquidGlassView` and
  /// otherwise uses Flutter's shader-filter capability.
  final bool? useImpellerBackdrop;

  /// On the Impeller (live-backdrop) path, blur the backdrop with the engine's
  /// native Gaussian *before* the refraction shader — via
  /// `ImageFilter.compose(outer: shader, inner: blur)` — instead of the
  /// shader's own multi-tap blur. The shader still masks to the merged
  /// silhouette, so out-of-shape blurred pixels are discarded (no halo). This
  /// is cheaper and higher quality; set `false` to fall back to the in-shader
  /// blur (e.g. to A/B, or if a device rejects a composed shader filter). No
  /// effect on the Skia capture path, which always blurs in-shader.
  final bool useEngineBlur;

  @override
  State<LiquidGlassBlender> createState() => _LiquidGlassBlenderState();
}

class _LiquidGlassBlenderState extends State<LiquidGlassBlender> {
  final _LiquidGlassBlenderRegistry _registry = _LiquidGlassBlenderRegistry();
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _LiquidGlassBlenderProgram.ensureLoaded().then((program) {
      if (mounted) {
        setState(() => _shader = program.fragmentShader());
      }
    }).catchError((Object _) {
      // Unsupported/broken shader environments keep the descendant content
      // usable and simply omit the experimental glass pass.
    });
  }

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lensScope = LiquidGlassLensScope.maybeOf(context);
    final bool useImpeller = (widget.useImpellerBackdrop ??
            lensScope?.useImpellerBackdrop ??
            true) &&
        ui.ImageFilter.isShaderFilterSupported;

    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        if (_shader != null)
          Positioned.fill(
            child: _LiquidGlassBlenderSurface(
              registry: _registry,
              shader: _shader!,
              style: widget.style,
              smoothness: widget.smoothness,
              perSideMorph: widget.perSideMorph,
              useImpellerBackdrop: useImpeller,
              useEngineBlur: widget.useEngineBlur,
              lensScope: lensScope,
              screenSize: MediaQuery.sizeOf(context),
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
          ),
        LiquidGlassBlenderScope(
          registry: _registry,
          child: widget.child,
        ),
      ],
    );
  }
}

class _LiquidGlassBlenderProgram {
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram>? _loading;

  static Future<ui.FragmentProgram> ensureLoaded() {
    final cached = _program;
    if (cached != null) return Future.value(cached);
    return _loading ??= _load();
  }

  static Future<ui.FragmentProgram> _load() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'packages/liquid_glass_easy/lib/assets/shaders/metaball_glass.frag',
      );
    } catch (_) {
      _program = await ui.FragmentProgram.fromAsset(
        'lib/assets/shaders/metaball_glass.frag',
      );
    } finally {
      _loading = null;
    }
    return _program!;
  }
}

/// Internal registration scope consumed by `LiquidGlassLens`.
@internal
class LiquidGlassBlenderScope extends InheritedWidget {
  const LiquidGlassBlenderScope({
    super.key,
    required _LiquidGlassBlenderRegistry registry,
    required super.child,
  }) : _registry = registry;

  final _LiquidGlassBlenderRegistry _registry;

  static LiquidGlassBlenderScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LiquidGlassBlenderScope>();
  }

  /// Replaces a lens's individual glass pass with a registered geometry node.
  Widget buildMember({
    required LiquidGlassStyle style,
    required bool visible,
    Widget? child,
  }) {
    final shape =
        style.shape ?? const LiquidGlassShape.continuousRoundedRectangle();
    final clippedChild = child == null
        ? null
        : ClipRRect(
            borderRadius: BorderRadius.circular(
              liquidGlassClipCornerRadius(shape),
            ),
            child: child,
          );

    return _LiquidGlassBlenderMember(
      registry: _registry,
      shape: shape,
      visible: visible,
      child: visible ? clippedChild : null,
    );
  }

  @override
  bool updateShouldNotify(LiquidGlassBlenderScope oldWidget) {
    return _registry != oldWidget._registry;
  }
}

class _LiquidGlassBlenderRegistry extends ChangeNotifier {
  final LinkedHashSet<_RenderLiquidGlassBlenderMember> members =
      LinkedHashSet<_RenderLiquidGlassBlenderMember>.identity();

  void register(_RenderLiquidGlassBlenderMember member) {
    if (!members.add(member)) return;
    assert(() {
      if (members.length > LiquidGlassBlender.maxLensCount) {
        throw FlutterError(
          'LiquidGlassBlender supports at most '
          '${LiquidGlassBlender.maxLensCount} LiquidGlassLens descendants, '
          'but ${members.length} were registered.',
        );
      }
      return true;
    }());
    notifyListeners();
  }

  void unregister(_RenderLiquidGlassBlenderMember member) {
    if (members.remove(member)) notifyListeners();
  }

  void memberChanged() => notifyListeners();
}

class _LiquidGlassBlenderMember extends SingleChildRenderObjectWidget {
  const _LiquidGlassBlenderMember({
    required this.registry,
    required this.shape,
    required this.visible,
    super.child,
  });

  final _LiquidGlassBlenderRegistry registry;
  final LiquidGlassShape shape;
  final bool visible;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLiquidGlassBlenderMember(
      registry: registry,
      shape: shape,
      visible: visible,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLiquidGlassBlenderMember renderObject,
  ) {
    renderObject
      ..registry = registry
      ..shape = shape
      ..visible = visible;
  }
}

class _RenderLiquidGlassBlenderMember extends RenderProxyBox {
  _RenderLiquidGlassBlenderMember({
    required _LiquidGlassBlenderRegistry registry,
    required LiquidGlassShape shape,
    required bool visible,
  })  : _registry = registry,
        _shape = shape,
        _visible = visible;

  _LiquidGlassBlenderRegistry _registry;
  LiquidGlassShape _shape;
  bool _visible;

  _LiquidGlassBlenderRegistry get registry => _registry;
  set registry(_LiquidGlassBlenderRegistry value) {
    if (_registry == value) return;
    if (attached) _registry.unregister(this);
    _registry = value;
    if (attached) _registry.register(this);
    markNeedsPaint();
  }

  LiquidGlassShape get shape => _shape;
  set shape(LiquidGlassShape value) {
    if (_shape == value) return;
    _shape = value;
    _registry.memberChanged();
    markNeedsPaint();
  }

  bool get visible => _visible;
  set visible(bool value) {
    if (_visible == value) return;
    _visible = value;
    _registry.memberChanged();
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry.register(this);
  }

  @override
  void detach() {
    _registry.unregister(this);
    super.detach();
  }

  @override
  void performLayout() {
    final oldSize = hasSize ? size : null;
    super.performLayout();
    if (oldSize != size) _registry.memberChanged();
  }
}

class _LiquidGlassBlenderSurface extends LeafRenderObjectWidget {
  const _LiquidGlassBlenderSurface({
    required this.registry,
    required this.shader,
    required this.style,
    required this.smoothness,
    required this.perSideMorph,
    required this.useImpellerBackdrop,
    required this.useEngineBlur,
    required this.lensScope,
    required this.screenSize,
    required this.devicePixelRatio,
  });

  final _LiquidGlassBlenderRegistry registry;
  final ui.FragmentShader shader;
  final LiquidGlassStyle style;
  final double smoothness;
  final bool perSideMorph;
  final bool useImpellerBackdrop;
  final bool useEngineBlur;
  final LiquidGlassLensScope? lensScope;
  final Size screenSize;
  final double devicePixelRatio;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLiquidGlassBlenderSurface(
      registry: registry,
      shader: shader,
      style: style,
      smoothness: smoothness,
      perSideMorph: perSideMorph,
      useImpellerBackdrop: useImpellerBackdrop,
      useEngineBlur: useEngineBlur,
      lensScope: lensScope,
      screenSize: screenSize,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLiquidGlassBlenderSurface renderObject,
  ) {
    renderObject
      ..registry = registry
      ..shader = shader
      ..style = style
      ..smoothness = smoothness
      ..perSideMorph = perSideMorph
      ..useImpellerBackdrop = useImpellerBackdrop
      ..useEngineBlur = useEngineBlur
      ..lensScope = lensScope
      ..screenSize = screenSize
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderLiquidGlassBlenderSurface extends RenderBox {
  _RenderLiquidGlassBlenderSurface({
    required _LiquidGlassBlenderRegistry registry,
    required ui.FragmentShader shader,
    required LiquidGlassStyle style,
    required double smoothness,
    required bool perSideMorph,
    required bool useImpellerBackdrop,
    required bool useEngineBlur,
    required LiquidGlassLensScope? lensScope,
    required Size screenSize,
    required double devicePixelRatio,
  })  : _registry = registry,
        _shader = shader,
        _style = style,
        _smoothness = smoothness,
        _perSideMorph = perSideMorph,
        _useImpellerBackdrop = useImpellerBackdrop,
        _useEngineBlur = useEngineBlur,
        _lensScope = lensScope,
        _screenSize = screenSize,
        _devicePixelRatio = devicePixelRatio;

  final LayerHandle<BackdropFilterLayer> _shaderLayer =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();

  // Watches the global transform of the surface AND every member, and
  // repaints when any of them moves between frames — even when the move
  // comes from an ancestor (page slide-in, scroll, parent drag) or from a
  // member's own animated transform layer (SlideTransition, Transform,
  // AnimatedBuilder), neither of which re-runs this surface's paint on its
  // own. Without it the merged surface freezes its screen-space uniforms at
  // whatever position it was last painted and only "snaps" back on the next
  // registry notify (a rebuild, resize, or membership change).
  final LayerHandle<_MetaballTransformTrackingLayer> _trackingLayer =
      LayerHandle<_MetaballTransformTrackingLayer>();

  _LiquidGlassBlenderRegistry _registry;
  ui.FragmentShader _shader;
  LiquidGlassStyle _style;
  double _smoothness;
  bool _perSideMorph;
  bool _useImpellerBackdrop;
  bool _useEngineBlur;
  LiquidGlassLensScope? _lensScope;
  Size _screenSize;
  double _devicePixelRatio;

  _LiquidGlassBlenderRegistry get registry => _registry;
  set registry(_LiquidGlassBlenderRegistry value) {
    if (_registry == value) return;
    if (attached) _registry.removeListener(markNeedsPaint);
    _registry = value;
    if (attached) _registry.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  ui.FragmentShader get shader => _shader;
  set shader(ui.FragmentShader value) {
    if (_shader == value) return;
    _shader = value;
    markNeedsPaint();
  }

  LiquidGlassStyle get style => _style;
  set style(LiquidGlassStyle value) {
    if (_style == value) return;
    _style = value;
    markNeedsPaint();
  }

  double get smoothness => _smoothness;
  set smoothness(double value) {
    if (_smoothness == value) return;
    _smoothness = value;
    markNeedsPaint();
  }

  bool get perSideMorph => _perSideMorph;
  set perSideMorph(bool value) {
    if (_perSideMorph == value) return;
    _perSideMorph = value;
    markNeedsPaint();
  }

  bool get useImpellerBackdrop => _useImpellerBackdrop;
  set useImpellerBackdrop(bool value) {
    if (_useImpellerBackdrop == value) return;
    _useImpellerBackdrop = value;
    markNeedsPaint();
    markNeedsCompositingBitsUpdate();
  }

  bool get useEngineBlur => _useEngineBlur;
  set useEngineBlur(bool value) {
    if (_useEngineBlur == value) return;
    _useEngineBlur = value;
    markNeedsPaint();
  }

  LiquidGlassLensScope? get lensScope => _lensScope;
  set lensScope(LiquidGlassLensScope? value) {
    if (_lensScope == value) return;
    if (attached) {
      _lensScope?.captureRevision.removeListener(markNeedsPaint);
    }
    _lensScope = value;
    if (attached) {
      _lensScope?.captureRevision.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  Size get screenSize => _screenSize;
  set screenSize(Size value) {
    if (_screenSize == value) return;
    _screenSize = value;
    markNeedsPaint();
  }

  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry.addListener(markNeedsPaint);
    _lensScope?.captureRevision.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _registry.removeListener(markNeedsPaint);
    _lensScope?.captureRevision.removeListener(markNeedsPaint);
    _trackingLayer.layer
      ?..surface = null
      ..registry = null
      ..onChanged = null;
    super.detach();
  }

  @override
  void dispose() {
    _shaderLayer.layer = null;
    _clipLayer.layer = null;
    _trackingLayer.layer = null;
    super.dispose();
  }

  /// Pushes (and lazily creates) the metaball transform probe — one empty
  /// layer that, after layout/paint, samples this surface's and every
  /// member's `getTransformTo(null)` and repaints when any changed since the
  /// last frame. One probe covers both ancestor motion and per-member
  /// animation, with no extra compositing layers on the members themselves.
  void _pushTransformTracking(PaintingContext context, Offset offset) {
    final layer = _trackingLayer.layer ??= _MetaballTransformTrackingLayer();
    layer
      ..surface = this
      ..registry = _registry
      ..onChanged = () {
        if (attached) markNeedsPaint();
      };
    context.pushLayer(
      layer,
      (PaintingContext context, Offset offset) {},
      offset,
    );
  }

  @override
  void performLayout() {
    size = constraints.biggest.isFinite
        ? constraints.biggest
        : constraints.constrain(Size.zero);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Repaint whenever an ancestor moves us (page transition, scroll, parent
    // drag), so the merged surface's screen-space uniforms stay in sync with
    // where the lenses actually are — same probe the single lens uses.
    _pushTransformTracking(context, offset);

    final members = _registry.members
        .where((member) =>
            member.attached &&
            member.hasSize &&
            member.visible &&
            !member.size.isEmpty)
        .take(LiquidGlassBlender.maxLensCount)
        .toList(growable: false);

    if (members.length < LiquidGlassBlender.minLensCount || size.isEmpty) {
      _shaderLayer.layer = null;
      _clipLayer.layer = null;
      return;
    }

    if (_useImpellerBackdrop) {
      _paintImpeller(context, offset, members);
    } else {
      _paintSkiaCapture(context, offset, members);
    }
  }

  // ── Impeller: live backdrop via ImageFilter.shader ─────────────────
  //
  // FlutterFragCoord() is screen-space PHYSICAL px here, so lens geometry and
  // resolution are global and scaled by dpr (exactly like
  // RenderLiquidGlassLens). The merged silhouette is carved by the shader's
  // shapeMask, so the surface clip is just the (full) bounds.
  //
  // Blur: with [_useEngineBlur] the backdrop is blurred by the engine's native
  // Gaussian BEFORE the shader, via ImageFilter.compose — so the shader sees an
  // already-blurred backdrop and masks it to the silhouette (no rectangular
  // halo, since there's still just one BackdropFilter). The shader's own blur
  // is switched off (blur: 0) on that path. Otherwise the shader blurs itself.
  void _paintImpeller(
    PaintingContext context,
    Offset offset,
    List<_RenderLiquidGlassBlenderMember> members,
  ) {
    final double sigma = _blurSigma;
    final bool engineBlur = _useEngineBlur && sigma > 0;

    // The engine Gaussian inflates its snapshot beyond the (full-surface) clip
    // by ~3·sigma on each side, and the outer shader samples THAT inflated
    // snapshot. Without telling it, the shader maps screen pixels over the bare
    // resolution and reads a too-large window out of the texture — downscaling
    // the refracted content inside the lens. So expand the sampling window by
    // the blur coverage:
    //   • SIZE: the surface's own size (the clip), NOT _screenSize — the surface
    //     is usually shorter than the FlutterView (status bar / system-nav
    //     insets), and sizing against _screenSize.height leaves a vertical-only
    //     downscale.
    //   • OFFSET: just −m. The snapshot's sampling origin already aligns with
    //     the surface, so adding the surface's global top-left would shift the
    //     refracted content off the lens.
    // Logical px; the packer scales by dpr. (3·sigma ≈ Impeller's Gaussian
    // coverage; nudge if a residual uniform scale shows.)
    const double kBlurCoverageSigmas = 3.0;
    final double m = kBlurCoverageSigmas * sigma;
    final Size surfaceSize = engineBlur
        ? MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size)
            .size
        : Size.zero;

    _packShared(
      resolution: _screenSize,
      lenses: _lensesIn(members, null),
      scale: _devicePixelRatio,
      // Engine blur runs before the shader → don't blur again in-shader.
      blur: engineBlur ? 0.0 : sigma,
      imageOffset: engineBlur ? Offset(-m, -m) : Offset.zero,
      imageSize: engineBlur
          ? Size(surfaceSize.width + 2 * m, surfaceSize.height + 2 * m)
          : null,
    );

    final ui.ImageFilter shaderFilter = ui.ImageFilter.shader(_shader);
    final ui.ImageFilter filter = engineBlur
        ? ui.ImageFilter.compose(
            outer: shaderFilter,
            // Sigma is in the shader's space (physical px), so scale by dpr.
            inner: ui.ImageFilter.blur(
              sigmaX: sigma * _devicePixelRatio,
              sigmaY: sigma * _devicePixelRatio,
            ),
          )
        : shaderFilter;

    final layer = _shaderLayer.layer ??= BackdropFilterLayer();
    layer.filter = filter;
    // Clip region for the backdrop pass.
    //
    // Plain shader path: a tight clip (the union of the member rects) just
    // limits where pixels land — the shader's backdrop sampler is the FULL
    // screen regardless — so we keep it as a cost saver.
    //
    // Engine-blur COMPOSE path: the inner blur first renders a snapshot bounded
    // by THIS clip, and the outer shader samples that snapshot while still
    // computing uv = refractedPx / u_resolution over the whole screen
    // (u_imageOffset=0, u_imageSize=resolution). A tight clip would make the
    // shader read a screen-sized UV range out of a union-sized texture —
    // scaling the refracted content by clip.size/screen and shifting it by
    // clip.topLeft (the "content shifts/scales inside the lens" artefact). So we
    // clip to the FULL surface here: the snapshot spans the screen and the
    // shader's full-screen sampling assumption holds. (Costs a full-surface
    // backdrop pass, but only when a blurred style is used.)
    final Rect clipRect = engineBlur
        ? (Offset.zero & size)
        : _glassClipRect(members, this, Offset.zero & size);
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      clipRect,
      (PaintingContext context, Offset offset) {
        context.pushLayer(
          layer,
          (PaintingContext context, Offset offset) {},
          offset,
        );
      },
      oldLayer: _clipLayer.layer,
    );
  }

  // â”€â”€ Skia / Web: sample the view's captured background â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  //
  // Paint.shader evaluates FlutterFragCoord() in the draw's LOCAL space, so
  // (as in RenderLiquidGlassLens) we map the lenses into the captured
  // background box's space, translate the canvas into it, and draw the whole
  // surface rect there. Uniforms are logical px (scale 1).
  void _paintSkiaCapture(
    PaintingContext context,
    Offset offset,
    List<_RenderLiquidGlassBlenderMember> members,
  ) {
    _shaderLayer.layer = null;
    _clipLayer.layer = null;

    final scope = _lensScope;
    final viewBox = scope?.backgroundRenderBox();
    final image = scope?.currentImage() ?? scope?.captureFallback();
    if (viewBox == null ||
        !viewBox.attached ||
        !viewBox.hasSize ||
        image == null) {
      return;
    }

    final Offset surfaceInView =
        MatrixUtils.transformPoint(getTransformTo(viewBox), Offset.zero);
    _packShared(
      resolution: viewBox.size,
      lenses: _lensesIn(members, viewBox),
      scale: 1.0,
      // The Skia path samples a bound image, so there is no live backdrop to
      // compose an engine blur into — blur in-shader here.
      blur: _blurSigma,
    );
    _shader.setImageSampler(0, image);

    // Draw only the glass region (in viewBox space) rather than the whole
    // surface — fewer shaded fragments, same result (shapeMask still carves
    // the silhouette).
    final Rect drawRect =
        _glassClipRect(members, viewBox, surfaceInView & size);

    final ui.Canvas canvas = context.canvas;
    canvas
      ..save()
      ..translate(offset.dx - surfaceInView.dx, offset.dy - surfaceInView.dy)
      ..drawRect(drawRect, Paint()..shader = _shader)
      ..restore();
  }

  /// The enabled members as metaball lenses, in [target]'s coordinate space
  /// (global when [target] is null), in LOGICAL px — `_packShared` applies
  /// the per-path scale.
  List<MetaballLensUniform> _lensesIn(
    List<_RenderLiquidGlassBlenderMember> members,
    RenderObject? target,
  ) {
    final List<Rect> rects = members
        .map((member) => MatrixUtils.transformRect(
              member.getTransformTo(target),
              Offset.zero & member.size,
            ))
        .toList(growable: false);

    return List<MetaballLensUniform>.generate(members.length, (i) {
      final member = members[i];
      final Rect rect = rects[i];
      final double maxCorner = math.min(rect.width, rect.height) * 0.5;

      // Per-side blend activation [right, left, down, up]: a side lights up
      // when a CLOSE neighbour lies in that direction. The shader rounds the
      // corners on each active side. Only continuous lenses use it, so skip
      // the work for the others.
      final List<double> sides = [0.0, 0.0, 0.0, 0.0];
      if (member.shape.cornerStyle ==
          LiquidGlassCornerStyle.continuousRoundedRectangle) {
        for (int j = 0; j < rects.length; j++) {
          if (j == i) continue;
          final Rect other = rects[j];
          final double dx = math.max(
              0.0, math.max(rect.left - other.right, other.left - rect.right));
          final double dy = math.max(
              0.0, math.max(rect.top - other.bottom, other.top - rect.bottom));
          final double gap = math.sqrt(dx * dx + dy * dy);
          // Proximity 1 at touching → 0 at the band edge, sharpened by
          // morphSpeed so it saturates well before contact.
          final double u =
              (gap / math.max(_smoothness, 1.0)).clamp(0.0, 1.0).toDouble();
          const double morphSpeed = 4.0;
          final double sp =
              ((1.0 - u) * morphSpeed).clamp(0.0, 1.0).toDouble();
          final double prox = sp * sp * (3.0 - 2.0 * sp);
          if (prox <= 0.0) continue;

          // Whole-shape morph (per-side estimation off): every corner rounds
          // by the overall proximity, regardless of which way the neighbour
          // lies — the original pre-estimation behaviour.
          if (!perSideMorph) {
            sides[0] = math.max(sides[0], prox);
            sides[1] = math.max(sides[1], prox);
            sides[2] = math.max(sides[2], prox);
            sides[3] = math.max(sides[3], prox);
            continue;
          }

          // When the boxes sink INTO each other (overlap on both axes) the
          // merged silhouette wraps around every side, so morph all four
          // corners — not just the ones facing the neighbour. The deeper the
          // interpenetration, the more isotropic the activation; otherwise the
          // far-side corners stay capsule while the blend warps them.
          final double overlapX = math.min(rect.right, other.right) -
              math.max(rect.left, other.left);
          final double overlapY = math.min(rect.bottom, other.bottom) -
              math.max(rect.top, other.top);
          if (overlapX > 0.0 && overlapY > 0.0) {
            final double minHalf = math.max(
                1.0, math.min(rect.shortestSide, other.shortestSide) * 0.5);
            final double o = (math.min(overlapX, overlapY) / minHalf)
                .clamp(0.0, 1.0)
                .toDouble();
            final double omni = prox * (o * o * (3.0 - 2.0 * o));
            sides[0] = math.max(sides[0], omni);
            sides[1] = math.max(sides[1], omni);
            sides[2] = math.max(sides[2], omni);
            sides[3] = math.max(sides[3], omni);
          }

          // Direction to the neighbour → which side(s) it activates.
          final Offset d = other.center - rect.center;
          final double len = d.distance;
          if (len < 1e-3) continue;
          final double nx = d.dx / len;
          final double ny = d.dy / len;
          sides[0] = math.max(sides[0], prox * _sideDir(nx)); // right
          sides[1] = math.max(sides[1], prox * _sideDir(-nx)); // left
          sides[2] = math.max(sides[2], prox * _sideDir(ny)); // down (+y)
          sides[3] = math.max(sides[3], prox * _sideDir(-ny)); // up (-y)
        }
      }
      final double blend = math.max(
          math.max(sides[0], sides[1]), math.max(sides[2], sides[3]));

      return MetaballLensUniform(
        center: rect.center,
        halfSize: Size(rect.width * 0.5, rect.height * 0.5),
        cornerRadius: math.min(member.shape.cornerRadius, maxCorner),
        cornerStyle: member.shape.cornerStyle.index,
        blend: blend,
        sides: sides,
      );
    }, growable: false);
  }

  /// Tight clip for the costly backdrop pass: the union of the [members]'
  /// rects in [target]'s space, inflated to cover everything that reaches
  /// beyond the bare lens boxes — the border rim, the blur tail, the
  /// refraction band and the metaball bridge — then clamped to [fullRect].
  /// A `Positioned.fill` blender would otherwise run the backdrop filter over
  /// the whole surface; this restricts it to where the glass actually is. The
  /// silhouette itself is still carved by the shader's `shapeMask`, so this is
  /// a pure cost bound, not a visual clip.
  Rect _glassClipRect(
    List<_RenderLiquidGlassBlenderMember> members,
    RenderObject target,
    Rect fullRect,
  ) {
    Rect? union;
    for (final member in members) {
      final Rect rect = MatrixUtils.transformRect(
        member.getTransformTo(target),
        Offset.zero & member.size,
      );
      union = (union == null) ? rect : union.expandToInclude(rect);
    }
    if (union == null) return fullRect;

    final shape =
        _style.shape ?? const LiquidGlassShape.continuousRoundedRectangle();
    final double margin = shape.borderWidth * 2.0 + // rim
        3.0 * _blurSigma + // gaussian tail
        _style.refraction.effectiveDistortionWidth + // refraction band
        _smoothness * 0.5 + // smin bridge bulge
        2.0; // AA
    final Rect clip = union.inflate(margin).intersect(fullRect);
    // Degenerate (e.g. lenses fully off-surface): fall back to the full rect.
    return (clip.isEmpty || !clip.isFinite) ? fullRect : clip;
  }

  /// Packs the shared glass block + lens geometry into [_shader] from the
  /// group [_style], reusing the production uniform layout. Lens-anywhere
  /// surfaces never honor the captured backdrop's alpha (it is treated as
  /// opaque so the optical rim/body survive over dark/empty regions).
  void _packShared({
    required Size resolution,
    required List<MetaballLensUniform> lenses,
    required double scale,
    required double blur,
    // The backdrop sampling window, in logical px (the packer scales by
    // [scale]). Defaults to the full backdrop (offset 0, size = resolution).
    // The engine-blur path overrides these so the shader maps screen pixels
    // into the blur's inflated snapshot instead of downscaling against it.
    Offset imageOffset = Offset.zero,
    Size? imageSize,
  }) {
    final shape =
        _style.shape ?? const LiquidGlassShape.continuousRoundedRectangle();
    final appearance = _style.appearance;
    final refraction = _style.refraction;

    packMetaballGlassUniforms(
      _shader,
      shape: shape,
      scale: scale,
      resolution: resolution,
      lenses: lenses,
      smoothness: _smoothness,
      magnification: refraction.magnification,
      distortion: refraction.effectiveDistortion,
      distortionWidth: refraction.effectiveDistortionWidth,
      enableInnerRadiusTransparent: appearance.enableInnerRadiusTransparent,
      diagonalFlip: refraction.diagonalFlip,
      borderWidth: shape.borderWidth * 2.0 +
          (shape.isOpticalBorder && shape.borderWidth > 0 ? 2.0 : 0.0),
      borderAlpha: 1.0,
      chromaticAberration: refraction.chromaticAberration,
      saturation: appearance.saturation,
      blur: blur,
      refractionMode: refraction.refractionMode,
      refractionType: refraction.refractionType,
      lensColor: appearance.color,
      honorBackdropAlpha: false,
      imageOffset: imageOffset,
      imageSize: imageSize,
    );
  }

  double get _blurSigma =>
      math.max(_style.appearance.blur.sigmaX, _style.appearance.blur.sigmaY);
}

/// A zero-content probe layer for the merged surface.
///
/// The blender's shader uniforms encode every member's on-screen rect, but
/// when an ancestor moves the group (a page slide-in, a scroll) or a member
/// moves under its own animated transform layer (`SlideTransition`,
/// `Transform`, `AnimatedBuilder`), the surface's `paint()` is usually NOT
/// re-run — the compositor just shifts retained layers — so the uniforms go
/// stale and the glass lags behind the content.
///
/// Like [LensTransformTrackingLayer] for the single lens, this layer is
/// re-added every frame ([alwaysNeedsAddToScene]) and its [addToScene] runs
/// *after* all layout and paint, when `getTransformTo(null)` is final. It
/// samples the surface's transform plus each member's, and when the set
/// differs from the previous frame it calls [onChanged] (typically
/// `markNeedsPaint`) so the next frame's uniforms are correct.
///
/// One probe covers the whole group: members stay plain proxy boxes (no
/// per-member compositing). The cost is N `getTransformTo` calls and N matrix
/// compares per frame, for the two-to-six members the blender allows.
///
/// Detection lags movement by one frame by construction (the stale frame is
/// already built when the change is seen); during continuous animation it
/// self-corrects every frame and the final resting frame is exact.
class _MetaballTransformTrackingLayer extends OffsetLayer {
  RenderObject? surface;
  _LiquidGlassBlenderRegistry? registry;
  VoidCallback? onChanged;

  List<Matrix4>? _last;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    // Intentionally does NOT call super: contributes nothing visual; it
    // exists purely as a post-paint transform probe.
    final RenderObject? ro = surface;
    final _LiquidGlassBlenderRegistry? reg = registry;
    if (ro == null || reg == null || !ro.attached) return;

    // Signature: the surface's transform first (catches ancestor motion even
    // on a frame where no member is laid out yet), then each attached,
    // measured member's transform (catches per-member animation).
    final List<Matrix4> current = <Matrix4>[ro.getTransformTo(null)];
    for (final member in reg.members) {
      if (member.attached && member.hasSize) {
        current.add(member.getTransformTo(null));
      }
    }

    final List<Matrix4>? last = _last;
    if (last == null) {
      // First frame: just record — the frame being built already used these
      // transforms, so there is nothing to correct yet.
      _last = current;
      return;
    }

    bool changed = last.length != current.length;
    if (!changed) {
      for (int i = 0; i < current.length; i++) {
        if (!MatrixUtils.matrixEquals(last[i], current[i])) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      _last = current;
      onChanged?.call();
    }
  }
}
