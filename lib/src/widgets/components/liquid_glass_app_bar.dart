import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_position.dart';
import '../utils/liquid_glass_shape.dart';

/// A floating, drop-in liquid-glass **app bar** — a translucent bar
/// that floats at the top of the screen with an optional [leading]
/// widget, a [title], and trailing [actions], all refracting the
/// content scrolling underneath it.
///
/// Like every other component in this package it is a single
/// [LiquidGlass] lens, so it drops straight into the `children:` of a
/// [LiquidGlassView] — or, more conveniently, into the `appBar:` slot
/// of a `LiquidGlassScaffold`, which positions and composites it for
/// you:
///
/// ```dart
/// LiquidGlassScaffold(
///   appBar: LiquidGlassAppBar(
///     leading: const Icon(Icons.menu),
///     title: const Text('Gallery'),
///     actions: const [Icon(Icons.search), Icon(Icons.more_vert)],
///   ),
///   body: myPageContent,
/// )
/// ```
///
/// By default the bar pins itself to the top-center of its parent with
/// a small [topMargin] of breathing room. Pass any [position] to
/// override (e.g. a full-bleed bar via [LiquidGlassOffsetPosition]).
///
/// Foreground color is applied to the icons and text through an
/// [IconTheme] / [DefaultTextStyle], so a plain `Icon(...)` or
/// `Text(...)` automatically picks up [foregroundColor].
class LiquidGlassAppBar extends LiquidGlass {
  LiquidGlassAppBar({
    /// Leading widget (typically a menu or back button). Shown at the
    /// start of the bar.
    Widget? leading,

    /// The bar's title. Usually a [Text]; inherits [foregroundColor]
    /// and a semi-bold style unless the widget overrides it.
    Widget? title,

    /// Trailing widgets (search, overflow menu, avatar, …). Laid out
    /// at the end of the bar in order.
    List<Widget> actions = const [],

    /// Whether the [title] is centered. When `false` the title is
    /// left-aligned next to the [leading] widget (Material style).
    bool centerTitle = true,
    super.controller,

    // ── Size & position ────────────────────────────────────
    super.height = 56,

    /// Width of the floating bar. Defaults to a wide floating capsule.
    /// For a full-bleed bar pass
    /// `MediaQuery.of(context).size.width - 2 * margin`.
    super.width = 360,

    /// Where the bar sits. Defaults to top-center with [topMargin] of
    /// breathing room. Pass any [LiquidGlassPosition] to override.
    LiquidGlassPosition? position,

    /// Extra space above the bar, used only when [position] is `null`.
    ///
    /// Inside a `LiquidGlassScaffold` with `safeArea: true` (the
    /// default) the scaffold already pushes the bar below the status
    /// bar, so this is *additional* spacing on top of that — `0` (the
    /// default) makes the bar sit flush under the status bar.
    double topMargin = 0,

    /// Horizontal padding between the bar rim and its content.
    double horizontalPadding = 14,

    /// Spacing between the title and the action widgets.
    double actionSpacing = 8,

    /// Corner radius of the bar. Defaults to a full pill
    /// (`height / 2`). Pass a smaller value for a rounded-rectangle
    /// bar.
    double? cornerRadius,

    // ── Glass look ─────────────────────────────────────────
    /// Base tint of the glass bar.
    Color glassColor = const Color(0x1CFFFFFF), // white, alpha 28
    super.blur = const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
    super.distortion = 0.07,
    super.distortionWidth = 28,
    super.chromaticAberration = 0.002,
    super.magnification = 1,

    /// Border styling of the bar rim.
    double borderWidth = 1.2,
    double lightIntensity = 1.1,
    double lightDirection = 80,
    OpticalBorder borderType = const OpticalBorder(
      borderSaturation: 1.2,
      ambientIntensity: 1.0,
      borderSolidity: 0.35,
    ),

    // ── Content ────────────────────────────────────────────
    /// Color applied to icons and text inside the bar.
    Color foregroundColor = Colors.white,

    /// Font size of the [title] when it is a plain [Text].
    double titleFontSize = 18,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          position: position ??
              LiquidGlassAlignPosition(
                alignment: Alignment.topCenter,
                margin: EdgeInsets.only(top: topMargin),
              ),
          color: glassColor,
          shape: RoundedRectangleShape(
            cornerRadius: cornerRadius ?? height / 2,
            borderWidth: borderWidth,
            lightIntensity: lightIntensity,
            lightDirection: lightDirection,
            borderType: borderType,
          ),
          child: _AppBarContent(
            leading: leading,
            title: title,
            actions: actions,
            centerTitle: centerTitle,
            horizontalPadding: horizontalPadding,
            actionSpacing: actionSpacing,
            foregroundColor: foregroundColor,
            titleFontSize: titleFontSize,
          ),
        );
}

/// Crisp content layer (leading + title + actions) drawn on top of
/// the [LiquidGlassAppBar] capsule, inside the lens `child` so it is
/// clipped to the bar and stays sharp.
class _AppBarContent extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final List<Widget> actions;
  final bool centerTitle;
  final double horizontalPadding;
  final double actionSpacing;
  final Color foregroundColor;
  final double titleFontSize;

  const _AppBarContent({
    required this.leading,
    required this.title,
    required this.actions,
    required this.centerTitle,
    required this.horizontalPadding,
    required this.actionSpacing,
    required this.foregroundColor,
    required this.titleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    // Theme icons + text so a bare Icon()/Text() inherits the bar's
    // foreground color without the caller having to set it.
    final Widget content = IconTheme.merge(
      data: IconThemeData(color: foregroundColor, size: 24),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: foregroundColor,
          fontSize: titleFontSize,
          fontWeight: FontWeight.w600,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: centerTitle ? _centered() : _leftAligned(),
        ),
      ),
    );
    return content;
  }

  Widget _trailing() {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          if (i != 0) SizedBox(width: actionSpacing),
          actions[i],
        ],
      ],
    );
  }

  // Title pinned to the true center of the bar, with leading at the
  // start and actions at the end, each in its own [Positioned]-like
  // slot so the title stays centered regardless of their widths.
  Widget _centered() {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (title != null) Center(child: title!),
        Align(
          alignment: Alignment.centerLeft,
          child: leading ?? const SizedBox.shrink(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _trailing(),
        ),
      ],
    );
  }

  // Material-style: leading, then left-aligned title that expands to
  // push the actions to the end.
  Widget _leftAligned() {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: title ?? const SizedBox.shrink(),
          ),
        ),
        _trailing(),
      ],
    );
  }
}
