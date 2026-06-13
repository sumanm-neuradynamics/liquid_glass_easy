import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_lens_scope.dart';
import 'package:liquid_glass_easy/src/widgets/lens/liquid_glass_shaders.dart';
import 'package:liquid_glass_easy/src/widgets/liquid_glass.dart';
import 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';

// Main container that renders LiquidGlass lenses on top of a background
class LiquidGlassView extends StatefulWidget {
  /// Controls the LiquidGlass rendering performance and synchronization pipeline.
  /// Manages how often background captures and shader updates occur to balance
  /// visual quality and frame rate performance.
  final LiquidGlassViewController? controller;

  /// The list of individual `LiquidGlass` lenses rendered in this view.
  /// Each lens defines its own shape, distortion, and behavior.
  ///
  /// This is the classic, position-driven API. For layout-driven lenses
  /// placed anywhere in a normal widget tree, put `LiquidGlassLens`
  /// widgets inside [child] instead — both can be used together.
  final List<LiquidGlass> children;

  /// An arbitrary widget tree rendered **on top of** [backgroundWidget]
  /// and below the [children] lenses. Place `LiquidGlassLens` widgets
  /// anywhere inside it — in a `Stack`, a `Column`, a scrollable — and
  /// they connect to this view automatically:
  ///
  ///  * On Impeller they refract the live backdrop behind them.
  ///  * On Skia / Web they refract this view's captured
  ///    [backgroundWidget] (which is required for refraction there).
  final Widget? child;

  /// The device pixel ratio used when capturing and rendering the lens effects.
  /// Higher values enhance lens content quality and clarity but also significantly
  /// impact performance by increasing GPU memory usage and rendering cost.
  ///
  /// If the background widget covers the entire screen, this setting can cause a
  /// **high performance impact**. In such cases, it is recommended to keep the
  /// value **below 1.0** and rely on blur effects for smoother visuals instead of
  /// higher pixel density.
  ///
  /// A value of **0.0** uses the device’s default pixel ratio, while **1.0** is the
  /// maximum recommended value for maintaining a balance between visual quality
  /// and frame rate.
  final double pixelRatio;

  /// Enables or disables real-time background capture for the lenses.
  /// When `true`, the background beneath each lens is updated every frame,
  /// producing dynamic refraction.
  /// When `false`, a cached snapshot is reused for better efficiency.
  final bool realTimeCapture;

  /// Determines whether lens rendering is synchronized with Flutter’s frame callbacks.
  /// When `true`, updates are aligned with Flutter’s rendering pipeline, resulting in
  /// smoother animations and generally faster performance.
  ///
  /// When `false`, updates run asynchronously, which can provide higher throughput
  /// on powerful devices, but may introduce slight delays or
  /// less consistent frame timing.
  ///
  /// It is slower than synchronous mode, but it becomes very stable
  /// when the pixel ratio is low (e.g., around 0.5).
  final bool useSync;

  /// The widget tree drawn behind all LiquidGlass lenses.
  /// Typically a static or animated background (such as an `Image`, `Stack`, or
  /// complex layout) over which the lenses apply refraction and effects.
  ///
  /// Optional since the lens-anywhere API: on **Impeller** lenses sample
  /// the live backdrop and need no background at all. On **Skia / Web**
  /// this is what lenses refract — without it, `LiquidGlassLens`
  /// children degrade to a frosted (non-refracting) look and the
  /// classic [children] lenses render nothing.
  final Widget? backgroundWidget;

  /// Controls how frequently the background is re-captured while real-time updates are enabled.
  ///
  /// - [LiquidGlassRefreshRate.low] = ~10 FPS (energy saving)
  /// - [LiquidGlassRefreshRate.medium] = ~24 FPS (balanced)
  /// - [LiquidGlassRefreshRate.high] = ~60 FPS (smooth)
  /// - [LiquidGlassRefreshRate.deviceRefreshRate] = tries to match the display refresh rate
  final LiquidGlassRefreshRate refreshRate;

  /// Override for the Impeller fast-path detection.
  ///
  /// When non-null, forces the renderer to use the
  /// `BackdropFilter(filter: ImageFilter.shader(...))` path (`true`)
  /// or the legacy `RepaintBoundary` + `toImage` capture path
  /// (`false`).
  ///
  /// When null (the default), the renderer auto-detects via
  /// `ui.ImageFilter.isShaderFilterSupported`. Note that this getter
  /// can return `true` on Skia in newer Flutter versions even when
  /// Impeller is disabled — if you launch with
  /// `--no-enable-impeller` and lenses fail to render, set this to
  /// `false` explicitly.
  final bool? useImpellerBackdrop;

  /// Per-lens region capture (Skia **sync** path only).
  ///
  /// When `true`, each per-frame capture grabs one small sub-image per
  /// lens (the lens's own rect plus a small safety margin) instead of
  /// rasterizing the whole [backgroundWidget], and the shader remaps
  /// each sub-image via `u_imageOffset`/`u_imageSize`. Refraction
  /// always samples inward, so the lens rect is all the shader needs.
  ///
  /// This is a performance optimization for views whose lenses cover a
  /// small fraction of a large background (e.g. one draggable lens over
  /// a full-screen photo): the capture cost scales with the captured
  /// area. With many lenses spread across the view the per-capture
  /// overhead multiplies, so measure before enabling.
  ///
  /// No effect on the Impeller path (which samples the live backdrop
  /// directly, with no captures at all) or on views with
  /// `useSync: false` (async captures are always full-frame).
  final bool regionCapture;

  const LiquidGlassView(
      {super.key,
      this.controller,
      this.backgroundWidget,
      this.children = const [],
      this.child,
      this.pixelRatio = 1.0,
      this.realTimeCapture = true,
      this.useSync = true,
      this.refreshRate = LiquidGlassRefreshRate.deviceRefreshRate,
      this.useImpellerBackdrop,
      this.regionCapture = false});

  @override
  State<LiquidGlassView> createState() => _LiquidGlassViewState();
}

class _LiquidGlassViewState extends State<LiquidGlassView>
    with SingleTickerProviderStateMixin {
  final GlobalKey _repaintKey = GlobalKey();
  ui.Image? _image;

  /// Parent-space rectangle [_image] covers, or `null` when [_image] is a
  /// full-frame capture. Set together with [_image] on every capture so the
  /// two never drift (a region image with a stale/null region would
  /// mis-sample). Drives the shader's `u_imageOffset`/`u_imageSize`.
  Rect? _imageRegion;

  Map<String, dynamic> _shaders = {};

  /// Bumped after every successful background capture. Descendant
  /// `LiquidGlassLens` widgets (the lens-anywhere API) listen to this
  /// through [LiquidGlassLensScope] and repaint, reading the new
  /// [_image] at paint time. Deliberately NOT bumped by the paint-time
  /// fallback capture — notifying listeners mid-paint is illegal; the
  /// lenses read that fallback directly through the scope instead.
  final ValueNotifier<int> _captureRevision = ValueNotifier<int>(0);

  /// Drives the per-frame capture pipeline on the **Skia / Web** path
  /// only. On the Impeller path each lens samples the live backdrop
  /// directly via `ImageFilter.shader`, so no parent-side ticker is
  /// needed and this is left null. Avoiding a perpetual
  /// vsync-driven `AnimatedBuilder` rebuild is one of the biggest
  /// wins on mobile Impeller — when no lens is animating and the
  /// user is not dragging, the parent does zero per-frame work.
  AnimationController? _controller;
  bool _realtimeCaptureEnabled = false;
  bool isWeb = kIsWeb;

  /// True when the BackdropFilter+ImageFilter.shader path should be
  /// used instead of the classic capture+CustomPaint pipeline.
  ///
  /// Auto-detected via `ui.ImageFilter.isShaderFilterSupported` —
  /// `true` on Impeller, `false` on Skia. Pass
  /// `useImpellerBackdrop: false` explicitly if your device reports
  /// `true` here despite running on Skia (some Flutter SDKs do
  /// this), and the lenses end up not rendering.
  late final bool _useImpeller =
      widget.useImpellerBackdrop ?? ui.ImageFilter.isShaderFilterSupported;

  /// Whether per-lens shader instances are required. Both Impeller
  /// (BackdropFilter compositing is deferred, so uniforms can't be
  /// shared) and the web HTML/Canvaskit pipeline need this.
  bool get _usePerLensShaders => _useImpeller || isWeb;

  @override
  void initState() {
    super.initState();
    _realtimeCaptureEnabled = widget.realTimeCapture;

    // Impeller path skips the capture pipeline entirely — each lens
    // samples the backdrop live via `ImageFilter.shader`. We
    // therefore avoid creating the perpetual ticker on Impeller so
    // that an idle screen does no per-vsync Dart work at all.
    if (!_useImpeller) {
      DateTime lastCaptureTime = DateTime.now();

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(days: 2),
      )..addListener(() async {
          if (!_realtimeCaptureEnabled) return;
          final interval = _refreshInterval;
          // If deviceRefreshRate → capture every frame
          if (interval == null) {
            await _captureWidgetSafe();
            return;
          }
          // Otherwise throttle based on selected refresh rate
          final now = DateTime.now();
          if (now.difference(lastCaptureTime) >= interval) {
            lastCaptureTime = now;
            await _captureWidgetSafe();
          }
        });
    }
    widget.controller?.attach(
      captureOnce: _captureOnce,
      startRealtime: _startRealtimeCapture,
      stopRealtime: _stopRealtimeCapture,
    );

    // If the programs were already compiled by a previous view (any
    // page after the first), build the shaders synchronously so
    // `shadersReady` is true on the very first frame. Otherwise fall
    // back to the async load (first launch only).
    if (LiquidGlassShaders.isLoaded) {
      _buildShaders();
    } else {
      _loadShaders().then((_) {
        if (mounted) setState(() {});
      });
    }

    // Skia / Web only: kick off the first capture as soon as the first
    // frame has painted. This is independent of shader loading — the
    // two run in parallel instead of the capture waiting behind the
    // shader future. Impeller samples the backdrop live per lens and
    // never needs a capture.
    if (!_useImpeller) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // The frame just painted, so the boundary layer is ready —
        // skip the extra endOfFrame wait that would cost a full frame.
        await _captureWidgetSafe(waitForEndOfFrame: false);
        if (mounted) setState(() {});
      });
      _controller?.forward();
    }
  }

  Duration? get _refreshInterval {
    switch (widget.refreshRate) {
      case LiquidGlassRefreshRate.low:
        return const Duration(milliseconds: 100); // ~10 FPS
      case LiquidGlassRefreshRate.medium:
        return const Duration(milliseconds: 42); // ~24 FPS
      case LiquidGlassRefreshRate.high:
        return const Duration(milliseconds: 16); // ~60 FPS
      case LiquidGlassRefreshRate.deviceRefreshRate:
        return null; // no throttling → capture every frame
    }
  }

  @override
  void didUpdateWidget(covariant LiquidGlassView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If config changes and no animation is running → update instantly

    if (_usePerLensShaders &&
        widget.children.length != oldWidget.children.length) {
      _recreateShaders(widget.children.length);
    }
    if (widget.realTimeCapture != oldWidget.realTimeCapture) {
      _realtimeCaptureEnabled = widget.realTimeCapture;
    }
  }

  Size get captureSize {
    final renderBox =
        _repaintKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size.zero;
  }

  List<ui.FragmentShader> _createShaderList(
    ui.FragmentShader Function() create,
    int count,
  ) {
    return List.generate(count, (_) => create());
  }

  Future<void> _loadShaders() async {
    try {
      await LiquidGlassShaders.ensureLoaded();
    } catch (_) {
      // Shaders unavailable (broken build / unsupported test env):
      // `_shaders` stays empty, so lenses simply don't render instead
      // of crashing the surrounding app.
      return;
    }
    _buildShaders();
  }

  /// Builds the per-view shader instances from the already-compiled
  /// shared programs (see [LiquidGlassShaders]). Synchronous so it can
  /// run inside [initState] when the programs are cached.
  void _buildShaders() {
    if (_usePerLensShaders) {
      // Impeller and web need one dedicated FragmentShader per lens.
      // BackdropFilter compositing (Impeller) and the web pipeline are
      // deferred, so successive draw calls would otherwise reuse the
      // same shader object with the last uniforms set, producing
      // context-switch artifacts (old lens content leaking, new lens
      // appearing transparent).
      final count = widget.children.length;
      _shaders = {
        'liquid_glass_list':
            _createShaderList(LiquidGlassShaders.createMainShader, count),
        'liquid_glass_border_list':
            _createShaderList(LiquidGlassShaders.createBorderShader, count),
      };
    } else {
      // Skia native draws each CustomPaint immediately, so a single
      // shared shader instance is safe and cheaper.
      _shaders = {
        'liquid_glass': LiquidGlassShaders.createMainShader(),
        'liquid_glass_border': LiquidGlassShaders.createBorderShader(),
      };
    }
  }

  Future<void> _recreateShaders(int newCount) async {
    if (!_usePerLensShaders) return;
    if (!LiquidGlassShaders.isLoaded) return;

    setState(() {
      _shaders['liquid_glass_list'] =
          _createShaderList(LiquidGlassShaders.createMainShader, newCount);
      _shaders['liquid_glass_border_list'] =
          _createShaderList(LiquidGlassShaders.createBorderShader, newCount);
    });
  }

  /// Safely captures the background RepaintBoundary.
  ///
  /// Important behavior (please keep — do not remove without testing on
  /// release/profile builds on Android):
  /// - On release/profile builds with Impeller (Android), a
  ///   `RenderRepaintBoundary` can still have no composited `layer` even
  ///   after `endOfFrame` (especially for small or freshly mounted
  ///   boundaries, or ones containing `Image.file`). In that case
  ///   `toImageSync` throws "Null check operator used on a null value".
  /// - So we first check `boundary.layer != null`; if the layer is not
  ///   ready we go straight to the async `toImage()`, which can wait for
  ///   composition to complete.
  /// - If `toImageSync` still throws, we catch it and also fall back to
  ///   async `toImage()`.
  /// - If async `toImage()` also fails, we soft-fail — we do not crash
  ///   the app; the frame is simply skipped and the UI keeps using the
  ///   previous `_image`.
  Future<void> _captureWidgetSafe({bool waitForEndOfFrame = true}) async {
    try {
      final context = _repaintKey.currentContext;
      if (context == null) return;

      final boundary = context.findRenderObject();
      if (boundary is RenderRepaintBoundary && boundary.attached) {
        // Callers running inside a post-frame callback pass false: the
        // frame has already painted, and awaiting endOfFrame there
        // would schedule + wait out one extra frame. The layer-null
        // check below still routes to async toImage() if composition
        // isn't ready, so skipping the wait stays safe.
        if (waitForEndOfFrame) {
          await WidgetsBinding.instance.endOfFrame;
        }
        if (!context.mounted) return;

        double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        double pixelRatio =
            widget.pixelRatio <= 0 ? devicePixelRatio : widget.pixelRatio;
        if (pixelRatio > devicePixelRatio) {
          pixelRatio = devicePixelRatio;
        }

        // ignore: invalid_use_of_protected_member
        final bool layerReady = boundary.layer != null;
        final bool preferSync = widget.useSync && layerReady;

        ui.Image? newImage;
        // Per-lens captures (regionCapture): one small image + its
        // parent-space rect for EACH lens child, index-aligned with
        // widget.children. Null → this capture was full-frame.
        List<ui.Image?>? newImagesPerLens;
        List<Rect?>? newRegionsPerLens;

        if (preferSync) {
          try {
            // Region-capture (Skia): capture each lens's own rect
            // (+ margin) as a separate sub-image and bind it directly —
            // the shader remaps it via u_imageOffset/u_imageSize, so no
            // full-size recomposite is needed. Opt-in per view via
            // LiquidGlassView.regionCapture; when false the original
            // full-frame path runs.
            // Region capture only updates the per-legacy-lens images,
            // not the shared full-frame [_image] that lens-anywhere
            // lenses sample — so force full-frame whenever a `child`
            // subtree (which may contain such lenses) is present.
            if (widget.regionCapture && widget.child == null) {
              // ignore: invalid_use_of_protected_member
              final layer = boundary.layer as OffsetLayer?;
              if (layer != null && widget.children.isNotEmpty) {
                final images = <ui.Image?>[];
                final regions = <Rect?>[];
                bool any = false;
                for (final child in widget.children) {
                  final Offset tl = child.position
                      .resolve(boundary.size, Size(child.width, child.height));
                  final Rect r = (tl & Size(child.width, child.height))
                      .inflate(_kRegionCaptureMargin)
                      .intersect(Offset.zero & boundary.size);
                  if (r.isEmpty) {
                    images.add(null);
                    regions.add(null);
                    continue;
                  }
                  images.add(layer.toImageSync(r, pixelRatio: pixelRatio));
                  regions.add(r);
                  any = true;
                }
                if (any) {
                  newImagesPerLens = images;
                  newRegionsPerLens = regions;
                }
              }
            }
            if (newImagesPerLens == null) {
              newImage = boundary.toImageSync(pixelRatio: pixelRatio);
            }
          } catch (_) {
            newImagesPerLens = null;
            newRegionsPerLens = null;
            try {
              newImage = await boundary.toImage(pixelRatio: pixelRatio);
            } catch (_) {
              newImage = null;
            }
          }
        } else {
          try {
            newImage = await boundary.toImage(pixelRatio: pixelRatio);
          } catch (_) {
            newImage = null;
          }
        }

        if (newImage == null && newImagesPerLens == null) return;
        if (!context.mounted) return;

        if (newImagesPerLens != null) {
          _imagesPerLens = newImagesPerLens;
          _regionsPerLens = newRegionsPerLens;
        } else {
          _image = newImage;
          _imageRegion = null;
          _imagesPerLens = null;
          _regionsPerLens = null;
          // Wake the lens-anywhere lenses (scope listeners). Safe here:
          // captures run from the ticker / post-frame callbacks, never
          // inside paint.
          _captureRevision.value++;
        }
      }
    } catch (_) {
      // Soft-fail: skip this frame, the UI keeps working.
    }
  }

  // ===== Per-lens region capture (Skia) =====
  // Opt-in via LiquidGlassView.regionCapture. Each lens gets its own
  // captured rect, inflated by this safety margin. The shader itself
  // never samples outside the lens rect (refraction pulls inward) —
  // the buffer covers a fast-moving lens drifting a few px past the
  // region between capture and paint, and magnification < 1 (which
  // scales samples outward).
  static const double _kRegionCaptureMargin = 24.0;

  /// Per-lens captured images and their parent-space rects, index-
  /// aligned with `widget.children`. Non-null only while
  /// `widget.regionCapture` is enabled and the last capture succeeded;
  /// entries can be null for off-screen lenses (those fall back to
  /// [_image]).
  List<ui.Image?>? _imagesPerLens;
  List<Rect?>? _regionsPerLens;

  /// Device pixel ratio, refreshed on every build for use inside
  /// paint-time code (where InheritedWidget lookups are not allowed).
  double _devicePixelRatio = 1.0;

  /// Synchronous paint-time capture fallback for the Skia / Web path.
  ///
  /// Called by the lens painters during their `paint()` when no captured
  /// image exists yet — i.e. the very first frame after this view is
  /// created (page change, first mount). The background RepaintBoundary
  /// is an earlier sibling in the Stack, so by the time a lens paints,
  /// the boundary's layer has already been painted **this frame** and
  /// `toImageSync` can rasterize it immediately. That removes the final
  /// one-frame gap where lenses were invisible while waiting for the
  /// post-frame capture.
  ///
  /// Always captures the full frame — never a region — because the
  /// painters calling this were built with null `imageOffset`/`imageSize`
  /// (full-frame sampling). Region capture resumes with the normal
  /// per-frame pipeline. The result is cached into [_image] so the other
  /// lenses painting in the same frame reuse it instead of re-capturing.
  ///
  /// Soft-fails to null (lens skips the frame), matching the existing
  /// capture pipeline's behavior.
  ui.Image? _capturePaintTimeSync() {
    if (_image != null) return _image;
    try {
      final context = _repaintKey.currentContext;
      if (context == null) return null;
      final boundary = context.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.attached) {
        return null;
      }
      // ignore: invalid_use_of_protected_member
      final layer = boundary.layer;
      if (layer is! OffsetLayer) return null;

      double pixelRatio =
          widget.pixelRatio <= 0 ? _devicePixelRatio : widget.pixelRatio;
      if (pixelRatio > _devicePixelRatio) {
        pixelRatio = _devicePixelRatio;
      }

      final img = layer.toImageSync(
        Offset.zero & boundary.size,
        pixelRatio: pixelRatio,
      );
      _image = img;
      _imageRegion = null;
      return img;
    } catch (_) {
      return null;
    }
  }

  Future<void> _captureOnce() async {
    await _captureWidgetSafe();
    if (mounted) setState(() {});
  }

  void _startRealtimeCapture() {
    setState(() {
      _realtimeCaptureEnabled = true;
    });
  }

  void _stopRealtimeCapture() {
    setState(() {
      _realtimeCaptureEnabled = false;
    });
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _controller?.dispose();
    _captureRevision.dispose();
    super.dispose();
  }

  // ===== Lens-anywhere scope accessors =====
  // Instance-method tear-offs stay `==` across rebuilds, so the scope
  // only notifies dependents on real configuration changes.

  /// Latest full-frame capture for descendant `LiquidGlassLens` widgets.
  ui.Image? _currentImageForLens() => _image;

  /// The background boundary box — the coordinate space captures live in.
  RenderBox? _backgroundBoxForLens() =>
      _repaintKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    _devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return Stack(
      // Tight constraints for both the captured background and the
      // lens-rendering layer. Without this, in a loose Stack, the
      // RepaintBoundary and the LayoutBuilder can end up at
      // different sizes (or with stale captureSize), which makes
      // alignment-based lens positions resolve against the wrong
      // parent size on first build and on page changes.
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          key: _repaintKey,
          // Kept even when no background is given so the capture
          // pipeline and coordinate space stay well-defined.
          child: widget.backgroundWidget ?? const SizedBox.expand(),
        ),
        // Lens-anywhere subtree: any widget tree with `LiquidGlassLens`
        // widgets inside it, connected to this view through the scope.
        // Painted above the background and below the classic lenses.
        if (widget.child != null)
          LiquidGlassLensScope(
            useImpellerBackdrop: _useImpeller,
            hasBackground: widget.backgroundWidget != null,
            captureRevision: _captureRevision,
            currentImage: _currentImageForLens,
            captureFallback: _capturePaintTimeSync,
            backgroundRenderBox: _backgroundBoxForLens,
            child: widget.child!,
          ),
        // The lens layout itself is identical on both paths. The
        // difference is what triggers it to rebuild:
        //  - Skia / Web: rebuilds whenever the captured background
        //    image is refreshed (driven by `_controller`).
        //  - Impeller:  rebuilds only on layout changes; each
        //    `LiquidGlassWidget` watches its own animation
        //    controller + touch notifier, so the parent does no
        //    per-frame work when nothing is animating or being
        //    dragged.
        if (_useImpeller)
          _buildLensLayout()
        else
          AnimatedBuilder(
            animation: _controller!,
            builder: (context, _) => _buildLensLayout(),
          ),
      ],
    );
  }

  Widget _buildLensLayout() {
    // Both paths gate solely on shader availability. Impeller samples
    // the live backdrop via BackdropFilter; Skia no longer waits for
    // the first capture either — when `_image` is still null the
    // painters capture the freshly painted background synchronously
    // during paint via [_capturePaintTimeSync], so lenses render on
    // the very first frame of a new view.
    final bool shadersReady = _usePerLensShaders
        ? _shaders.containsKey('liquid_glass_list')
        : _shaders.containsKey('liquid_glass');
    final bool canRender = shadersReady;

    return LayoutBuilder(builder: (context, constraints) {
      // Use the layout constraints as the authoritative parent
      // size. On the Skia path `captureSize` (read from the
      // RepaintBoundary's render box) is only valid after first
      // layout; on the Impeller path the lenses render before any
      // capture happens, so `Size.zero` would push every alignment
      // to (0, 0).
      final Size resolvedParentSize =
          constraints.biggest.isFinite ? constraints.biggest : captureSize;

      final shaderList =
          _shaders['liquid_glass_list'] as List<ui.FragmentShader>?;
      final borderList =
          _shaders['liquid_glass_border_list'] as List<ui.FragmentShader>?;

      return Stack(children: [
        ...widget.children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;

          final bool indexReady = !_usePerLensShaders ||
              (shaderList != null &&
                  borderList != null &&
                  index < shaderList.length &&
                  index < borderList.length);

          if (canRender && indexReady) {
            // Per-lens region capture: when this lens has its own
            // captured sub-image, bind that (+ its rect); otherwise
            // fall back to the shared full-frame capture.
            final perImgs = _imagesPerLens;
            final bool hasOwn = perImgs != null &&
                index < perImgs.length &&
                perImgs[index] != null;
            // Use `config.key` when provided, otherwise a stable
            // index-based key. This prevents Flutter from reusing
            // a lens `State` across the wrong slot when `children`
            // change (insert/remove/reorder).
            return LiquidGlassWidget(
              key: child.key ?? ValueKey('lg_index_$index'),
              config: child,
              parentSize: resolvedParentSize,
              sharedShader: _usePerLensShaders
                  ? shaderList![index]
                  : _shaders['liquid_glass'] as ui.FragmentShader?,
              border: _usePerLensShaders
                  ? borderList![index]
                  : _shaders['liquid_glass_border'] as ui.FragmentShader?,
              sharedImage: hasOwn ? perImgs[index] : _image,
              sharedImageRegion:
                  hasOwn ? _regionsPerLens![index] : _imageRegion,
              captureFallback: _useImpeller ? null : _capturePaintTimeSync,
              useImpellerBackdrop: _useImpeller,
            );
          } else {
            return const SizedBox.shrink();
          }
        }),
      ]);
    });
  }
}
