export 'package:liquid_glass_easy/src/widgets/liquid_glass_view.dart';
export 'package:liquid_glass_easy/src/widgets/liquid_glass.dart'
    show LiquidGlass;

export 'package:liquid_glass_easy/src/controllers/liquid_glass_controller.dart';
export 'package:liquid_glass_easy/src/controllers/liquid_glass_view_controller.dart';

export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_blur.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_shape.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_light_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_border_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refraction_mode.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_refresh_rate.dart';
export 'package:liquid_glass_easy/src/widgets/utils/liquid_glass_position.dart';

// ── Public, customizable developer components ──────────────
// Generic glass UI atoms a developer composes into their app.
// Each is a single LiquidGlass lens placed in a LiquidGlassView.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_button.dart';
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_search_bar.dart';
// Dock + its building blocks (a glass container of app icons).
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_app_icon.dart';
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_dock.dart';
// Tab bar: only the non-animated [LiquidGlassTabBar] is public. The
// animated variant ([LiquidGlassAnimatedTabBar]) is hidden while its
// motion work is still being finished.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_tab_bar.dart'
    show
        LiquidGlassTabBar,
        LiquidGlassTabBarItem,
        LiquidGlassTabBarAction;
// Bottom nav: only the single drop-in [LiquidGlassBottomNavBar] is
// public. The lower-level building blocks (shell / capsule / static
// pill / layout) and the animated pieces are hidden — the drop-in
// widget supersedes them for app developers.
export 'package:liquid_glass_easy/src/widgets/components/liquid_glass_bottom_nav_bar.dart'
    show LiquidGlassBottomNavBar;

// ── Internal / showcase-only / animation-in-progress ───────
// The following are intentionally NOT exported:
//   • liquid_glass_notification_card.dart, liquid_glass_music_player.dart,
//     liquid_glass_control_tile.dart — showcase-only demo widgets,
//     not generic developer components.
//   • liquid_glass_segmented_control.dart, liquid_glass_slider.dart,
//     liquid_glass_toggle.dart, liquid_glass_morph_segmented.dart,
//     liquid_glass_morph_pill.dart — they animate, and all animated
//     components stay hidden until their motion work is finalized.
//   • the lower-level bottom-nav building blocks and the animated
//     tab bar / bottom nav shells.
// The example app still drives all of these in its showcase and
// imports them directly from 'src' (with an implementation_imports
// ignore) instead of relying on the public barrel.

export 'package:liquid_glass_easy/src/demos/liquid_glass_showcase.dart';
export 'package:liquid_glass_easy/src/demos/liquid_glass_playground.dart';
