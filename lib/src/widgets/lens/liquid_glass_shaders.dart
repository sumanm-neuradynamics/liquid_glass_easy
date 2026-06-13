import 'dart:ui' as ui;

/// App-wide cache for the compiled liquid-glass fragment programs.
///
/// A `FragmentProgram` is expensive to compile and identical for every
/// lens in the app, so it is loaded once and shared. Individual
/// `FragmentShader` *instances* (which hold per-lens uniform state) are
/// created from the cached programs and owned by their lens.
///
/// `LiquidGlassView` and the standalone `LiquidGlassLens` both load
/// through this cache, so whichever mounts first pays the one-time
/// async compile and every later mount gets its shaders synchronously
/// (no first-frame pop).
///
/// Call [ensureLoaded] ahead of time (e.g. in `main()` before
/// `runApp`) to guarantee even the very first lens renders on its
/// first frame:
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await LiquidGlassShaders.ensureLoaded();
///   runApp(const MyApp());
/// }
/// ```
class LiquidGlassShaders {
  LiquidGlassShaders._();

  static ui.FragmentProgram? _mainProgram;
  static ui.FragmentProgram? _borderProgram;
  static Future<void>? _loading;

  /// Whether both programs are compiled and shader instances can be
  /// created synchronously via [createMainShader]/[createBorderShader].
  static bool get isLoaded => _mainProgram != null && _borderProgram != null;

  /// Loads and compiles both fragment programs once. Safe to call
  /// repeatedly and from multiple call sites — concurrent callers share
  /// the same in-flight future, and once loaded it completes
  /// synchronously.
  static Future<void> ensureLoaded() {
    if (isLoaded) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      _mainProgram ??=
          await _loadProgram('lib/assets/shaders/liquid_glass.frag');
      _borderProgram ??=
          await _loadProgram('lib/assets/shaders/liquid_glass_border.frag');
    } finally {
      // Reset so a failed load (e.g. asset missing in a broken build)
      // can be retried instead of caching the failure forever.
      _loading = null;
    }
  }

  static Future<ui.FragmentProgram> _loadProgram(String relativePath) async {
    try {
      // Normal case: this package is a dependency of the running app,
      // so its assets live under the packages/ prefix.
      return await ui.FragmentProgram.fromAsset(
          'packages/liquid_glass_easy/$relativePath');
    } catch (_) {
      // Running inside the package itself (its own widget tests), where
      // the same assets resolve without the prefix.
      return await ui.FragmentProgram.fromAsset(relativePath);
    }
  }

  /// Creates a fresh main-shader instance. [isLoaded] must be true.
  static ui.FragmentShader createMainShader() {
    assert(isLoaded,
        'LiquidGlassShaders not loaded — await ensureLoaded() first.');
    return _mainProgram!.fragmentShader();
  }

  /// Creates a fresh border-shader instance. [isLoaded] must be true.
  static ui.FragmentShader createBorderShader() {
    assert(isLoaded,
        'LiquidGlassShaders not loaded — await ensureLoaded() first.');
    return _borderProgram!.fragmentShader();
  }
}
