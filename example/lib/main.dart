import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Liquid Glass Easy — self-contained example.
//
// Everything this demo needs lives in THIS single file so you can
// copy `main.dart` into a fresh Flutter project, add `liquid_glass_easy`
// to your pubspec, and run it directly — no sibling files required.
//
// The screens (Control Center, Notifications, raw-lens playground)
// and their helper widgets are all defined below. Backgrounds try a
// bundled asset first and gracefully fall back to an in-code gradient,
// so the demo never crashes even without the example assets.
// =============================================================

/// Base URL for the hosted example wallpapers/images.
const String _kAssetsBaseUrl =
    'https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main';

void main() {
  runApp(const LiquidGlassExampleApp());
}

class LiquidGlassExampleApp extends StatelessWidget {
  const LiquidGlassExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// One "Next Background" button cycles through every demo page:
///
///   0. Control Center
///   1. Notifications
///   2..7. Raw liquid-glass lens playground (one per wallpaper)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  // Control Center + Notifications + one page per lens wallpaper.
  static const int _fixedPages = 2;
  static int get _pageCount => _fixedPages + LensDemoPage.wallpaperCount;

  Widget _page() {
    switch (_index) {
      case 0:
        return const ControlCenterPage();
      case 1:
        return const NotificationPage();
      default:
        return LensDemoPage(bgIndex: _index - _fixedPages);
    }
  }

  void _next() {
    setState(() => _index = (_index + 1) % _pageCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            onPressed: _next,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Next Background'),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// Shared background helpers
// =============================================================

/// Example-only demo wallpaper preset. Just a base + gradient so the
/// liquid-glass lenses have something colourful to refract when a
/// bundled photo asset isn't available.
class DemoWallpaper {
  final String name;
  final List<Color> colors;
  final Alignment focal;

  const DemoWallpaper({
    required this.name,
    required this.colors,
    this.focal = const Alignment(-0.2, -0.4),
  });
}

const DemoWallpaper _kPacific = DemoWallpaper(
  name: 'Pacific',
  colors: [Color(0xFF001A33), Color(0xFF005CB8), Color(0xFF00C4D1)],
  focal: Alignment(0.2, -0.4),
);

/// Renders a [DemoWallpaper] as a full-bleed gradient background.
class DemoWallpaperView extends StatelessWidget {
  final DemoWallpaper wallpaper;

  const DemoWallpaperView({super.key, required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    final base = wallpaper.colors.first;
    final mid = wallpaper.colors[
        wallpaper.colors.length ~/ 2 == 0 ? 0 : wallpaper.colors.length ~/ 2];
    final hot = wallpaper.colors.last;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: base),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: wallpaper.focal,
              radius: 1.1,
              colors: [
                mid.withAlpha(220),
                mid.withAlpha(110),
                Colors.transparent,
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                wallpaper.focal.x + 0.25,
                wallpaper.focal.y - 0.25,
              ),
              radius: 0.6,
              colors: [
                hot.withAlpha(180),
                hot.withAlpha(60),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(80),
              ],
              stops: const [0.6, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-bleed photo background. Loads a hosted image and falls back
/// to a [DemoWallpaperView] gradient if it can't be decoded, so the
/// demo runs even offline.
class PhotoBackground extends StatelessWidget {
  final String imageUrl;
  final DemoWallpaper fallback;
  final int scrimAlpha;

  const PhotoBackground({
    super.key,
    required this.imageUrl,
    this.fallback = _kPacific,
    this.scrimAlpha = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => DemoWallpaperView(wallpaper: fallback),
        ),
        if (scrimAlpha > 0)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withAlpha((scrimAlpha * 0.4).round()),
                  Colors.black.withAlpha(scrimAlpha),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================
// Page 2..7 — raw lens playground
// =============================================================

/// Raw-lens playground page. Shows a single draggable [LiquidGlass]
/// lens over one of several network wallpapers. The wallpaper is
/// chosen by [bgIndex] (0..wallpaperCount-1).
class LensDemoPage extends StatelessWidget {
  /// Which wallpaper + lens configuration to show (0..5).
  final int bgIndex;

  const LensDemoPage({super.key, required this.bgIndex});

  /// Number of wallpaper variations this page can show.
  static const int wallpaperCount = 6;

  Widget _buildBackground() {
    final List<Image> images = [
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/flower.jpg",
        fit: BoxFit.fitWidth,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/rain.jpg",
        fit: BoxFit.fitHeight,
        width: double.infinity,
        height: 300,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/neon.png",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_1.png",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_2.jpg",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
      Image.network(
        "https://raw.githubusercontent.com/AhmeedGamil/liquid_glass_easy_assets/refs/heads/main/socotra_tree_3.jpg",
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        images[bgIndex % images.length],
        const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Text(
              'Liquid Glass Easy Example',
              style: TextStyle(
                fontSize: 26,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        key: ValueKey('lens-demo-$bgIndex'),
        backgroundWidget: _buildBackground(),
        pixelRatio: 1,
        useSync: true,
        realTimeCapture: true,
        refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
        children: [
          if (bgIndex == 0)
            LiquidGlass(
              position:
                  const LiquidGlassAlignPosition(alignment: Alignment.center),
              width: 100,
              height: 100,
              magnification: 1,
              enableInnerRadiusTransparent: false,
              diagonalFlip: 0,
              distortion: 0.1125,
              distortionWidth: 50,
              chromaticAberration: 0.002,
              draggable: true,
              outOfBoundaries: true,
              blur: const LiquidGlassBlur(sigmaX: 3, sigmaY: 3),
              shape: const RoundedRectangleShape(
                  cornerRadius: 50,
                  borderWidth: 3,
                  lightIntensity: 1,
                  lightDirection: 39.0,
                  borderType: OpticalBorder(
                      borderSaturation: 1,
                      ambientIntensity: 0,
                      borderSolidity: 1)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                ),
                child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    child: const SizedBox(
                        height: 50,
                        width: 50,
                        child: Icon(
                          color: Colors.white,
                          Icons.pause,
                          size: 36,
                        ))),
              ),
            ),
          if (bgIndex == 1)
            LiquidGlass(
              position:
                  const LiquidGlassAlignPosition(alignment: Alignment.center),
              width: 240 * 0.8,
              height: 312 * 0.8,
              magnification: 1,
              enableInnerRadiusTransparent: false,
              diagonalFlip: 0,
              distortion: 0.075,
              distortionWidth: 70,
              draggable: true,
              outOfBoundaries: true,
              chromaticAberration: 0.002,
              color: Colors.grey.withAlpha(60),
              blur: const LiquidGlassBlur(sigmaX: 0.5, sigmaY: 0.5),
              shape: const RoundedRectangleShape(
                  cornerRadius: 70 * 0.8,
                  borderWidth: 1,
                  lightMode: LiquidGlassLightMode.radial,
                  borderType: ClassicBorder(
                    borderSoftness: 7.5,
                  ),
                  lightIntensity: 2 * 0.6,
                  lightDirection: 39.0),
              visibility: true,
              child: const Center(
                child: WeatherWidget(
                  cityName: "City",
                  description: "Rainy",
                  temperature: 23.4,
                  minTemp: 22.0,
                  maxTemp: 30.5,
                  humidity: 58,
                  windSpeed: 14.3,
                  weatherIcon: Icons.water_drop_rounded,
                ),
              ),
            ),
          if (bgIndex == 2)
            LiquidGlass(
                position: const LiquidGlassAlignPosition(
                    alignment: Alignment.center),
                width: 250,
                height: 250,
                magnification: 1,
                enableInnerRadiusTransparent: false,
                diagonalFlip: 0,
                distortion: 0.0875,
                distortionWidth: 80,
                draggable: true,
                outOfBoundaries: true,
                shape: const SuperellipseShape(
                    curveExponent: 3,
                    borderWidth: 1,
                    borderType: OpticalBorder(),
                    lightIntensity: 1,
                    lightDirection: 0)),
          if (bgIndex == 3)
            LiquidGlass(
              width: 240,
              height: 200,
              magnification: 1,
              distortion: 0.25,
              draggable: true,
              distortionWidth: 70,
              chromaticAberration: 0.002,
              blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
              position: const LiquidGlassAlignPosition(
                  alignment: Alignment.center),
              shape: const RoundedRectangleShape(
                lightDirection: 140,
                lightIntensity: 1,
                borderWidth: 1,
                borderType: OpticalBorder(borderSolidity: 0.5),
              ),
            ),
          if (bgIndex == 4)
            LiquidGlass(
              width: 240,
              height: 200,
              magnification: 1,
              distortion: 0.1,
              draggable: true,
              outOfBoundaries: true,
              distortionWidth: 70,
              position: const LiquidGlassAlignPosition(
                  alignment: Alignment.center),
              shape: const SuperellipseShape(
                  lightDirection: 140,
                  lightIntensity: 2,
                  borderWidth: 1,
                  borderType: OpticalBorder(borderSolidity: 0.5),
                  curveExponent: 4),
            ),
          if (bgIndex == 5)
            LiquidGlass(
              width: 150,
              height: 150,
              magnification: 1,
              distortion: 0.075,
              draggable: true,
              outOfBoundaries: true,
              distortionWidth: 50,
              position: const LiquidGlassAlignPosition(
                  alignment: Alignment.center),
              shape: const RoundedRectangleShape(
                  lightDirection: 140,
                  lightIntensity: 1.5,
                  borderWidth: 2,
                  borderType: OpticalBorder(
                      borderSaturation: 1,
                      ambientIntensity: 0,
                      borderSolidity: 0.5),
                  cornerRadius: 75),
            ),
        ],
      ),
    );
  }
}

/// Example weather card used as the lens child on wallpaper #1.
class WeatherWidget extends StatelessWidget {
  final String cityName;
  final String description;
  final double temperature;
  final double minTemp;
  final double maxTemp;
  final double humidity;
  final double windSpeed;
  final IconData weatherIcon;

  const WeatherWidget({
    super.key,
    required this.cityName,
    required this.description,
    required this.temperature,
    required this.minTemp,
    required this.maxTemp,
    required this.humidity,
    required this.windSpeed,
    this.weatherIcon = Icons.wb_sunny_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300 * 0.8,
      padding: const EdgeInsets.all(21 * 0.8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24 * 0.8),
        border: Border.all(color: Colors.white.withAlpha(0), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                cityName,
                style: const TextStyle(
                  fontSize: 22 * 0.8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                _formattedDate(),
                style: TextStyle(
                  fontSize: 14 * 0.8,
                  color: Colors.white.withAlpha(204),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16 * 0.8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                weatherIcon,
                size: 44 * 0.8,
                color: Colors.white.withAlpha(229),
              ),
              const SizedBox(width: 12 * 0.8),
              Text(
                "${temperature.toStringAsFixed(1)}°",
                style: const TextStyle(
                  fontSize: 52 * 0.8,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 0.9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8 * 0.8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 18 * 0.8,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16 * 0.8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _tempInfo("Min", minTemp),
              const SizedBox(width: 16 * 0.8),
              _tempInfo("Max", maxTemp),
            ],
          ),
          const SizedBox(height: 16 * 0.8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _extraInfo(Icons.water_drop_rounded, "Humidity", "$humidity%"),
              _extraInfo(Icons.air_rounded, "Wind", "$windSpeed km/h"),
            ],
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    return "${now.day}/${now.month}/${now.year}";
  }

  Widget _tempInfo(String label, double value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14 * 0.8,
            color: Colors.white.withAlpha(204),
          ),
        ),
        Text(
          "${value.toStringAsFixed(1)}°",
          style: const TextStyle(
            fontSize: 16 * 0.8,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _extraInfo(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withAlpha(229), size: 22 * 0.8),
        const SizedBox(height: 4 * 0.8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12 * 0.8,
            color: Colors.white.withAlpha(179),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13 * 0.8,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// Page 1 — Notifications
// =============================================================

/// A lock-screen style notification banner rendered as liquid glass.
/// This is example content — copy this pattern to build your own
/// glass content widgets.
class NotificationCard extends LiquidGlass {
  NotificationCard({
    required super.position,
    required String appName,
    required String title,
    required String body,
    required IconData appIcon,
    String time = 'now',
    Color appIconColor = const Color(0xFF007AFF),
    super.color = const Color(0x1CFFFFFF),
    super.width = 340,
    super.height = 92,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          magnification: 1,
          distortion: 0.07,
          distortionWidth: 32,
          chromaticAberration: 0.002,
          blur: const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
          shape: const RoundedRectangleShape(
            cornerRadius: 22,
            borderWidth: 1.0,
            lightIntensity: 1.0,
            lightDirection: 70,
            borderType: OpticalBorder(
              borderSaturation: 1.1,
              ambientIntensity: 1.0,
              borderSolidity: 0.3,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: appIconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(appIcon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
}

class _NotificationData {
  final String appName;
  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final String time;

  const _NotificationData({
    required this.appName,
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    required this.time,
  });
}

/// Lock-screen style notification page: notification cards stacked
/// one below another, plus iOS flashlight + camera corner buttons.
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _viewController = LiquidGlassViewController();

  static const _notifications = <_NotificationData>[
    _NotificationData(
      appName: 'Messages',
      title: 'Sara',
      body: 'Heading out, see you in 10 minutes!',
      icon: Icons.message_rounded,
      iconColor: Color(0xFF34C759),
      time: '2 min ago',
    ),
    _NotificationData(
      appName: 'Calendar',
      title: 'Standup at 10:00',
      body: 'Daily team sync — Conference Room A.',
      icon: Icons.calendar_today_rounded,
      iconColor: Color(0xFFFF3B30),
      time: 'in 5 min',
    ),
    _NotificationData(
      appName: 'Mail',
      title: 'Invoice #2043',
      body: 'Your monthly statement is ready to view.',
      icon: Icons.mail_rounded,
      iconColor: Color(0xFF007AFF),
      time: '18 min ago',
    ),
  ];

  static const double _cardHeight = 92;
  static const double _cardGap = 14;
  static const double _firstCardTop = 220;

  @override
  void dispose() {
    _viewController.detach();
    super.dispose();
  }

  Widget _buildBackground() {
    return const Stack(
      fit: StackFit.expand,
      children: [
        // Hosted photo; falls back to a gradient if offline.
        PhotoBackground(
          imageUrl: '$_kAssetsBaseUrl/mountain.jpg',
          scrimAlpha: 60,
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Saturday, 30 May',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '9:41',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidGlassView(
        controller: _viewController,
        backgroundWidget: _buildBackground(),
        pixelRatio: 1,
        useSync: true,
        realTimeCapture: true,
        refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
        children: [
          for (int i = 0; i < _notifications.length; i++)
            NotificationCard(
              position: LiquidGlassAlignPosition(
                alignment: Alignment.topCenter,
                margin: EdgeInsets.only(
                  top: _firstCardTop + i * (_cardHeight + _cardGap),
                ),
              ),
              appName: _notifications[i].appName,
              title: _notifications[i].title,
              body: _notifications[i].body,
              appIcon: _notifications[i].icon,
              appIconColor: _notifications[i].iconColor,
              time: _notifications[i].time,
              color: Colors.black.withAlpha(40),
            ),
          _buildCornerButton(
            icon: Icons.flashlight_on_rounded,
            alignment: Alignment.bottomLeft,
            margin: const EdgeInsets.only(left: 32, bottom: 48),
          ),
          _buildCornerButton(
            icon: Icons.photo_camera_rounded,
            alignment: Alignment.bottomRight,
            margin: const EdgeInsets.only(right: 32, bottom: 48),
          ),
        ],
      ),
    );
  }

  LiquidGlass _buildCornerButton({
    required IconData icon,
    required Alignment alignment,
    required EdgeInsets margin,
    double size = 56,
  }) {
    return LiquidGlass(
      position: LiquidGlassAlignPosition(alignment: alignment, margin: margin),
      width: size,
      height: size,
      magnification: 1,
      distortion: 0.07,
      distortionWidth: 28,
      chromaticAberration: 0.002,
      color: Colors.black.withAlpha(60),
      blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
      shape: RoundedRectangleShape(
        cornerRadius: size / 2,
        borderWidth: 1.2,
        lightIntensity: 1.1,
        lightDirection: 80,
        borderType: const OpticalBorder(
          borderSaturation: 1.2,
          ambientIntensity: 1.0,
          borderSolidity: 0.35,
        ),
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: size * 0.42),
      ),
    );
  }
}

// =============================================================
// Page 0 — Control Center
// =============================================================

/// Full-bleed background for the Control Center demo. Loads a hosted
/// image, falls back to a gradient + dark scrim if it can't load.
class ControlCenterBackground extends StatelessWidget {
  static const String _imageUrl = '$_kAssetsBaseUrl/control_center.jpg';

  final DemoWallpaper fallback;

  const ControlCenterBackground({super.key, this.fallback = _kPacific});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => DemoWallpaperView(wallpaper: fallback),
        ),
        ColoredBox(color: Colors.black.withAlpha(60)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(40),
                Colors.black.withAlpha(110),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CcConnectivityState {
  bool airplane;
  bool airdrop;
  bool wifi;
  bool bluetooth;
  bool cellular;
  bool data;

  CcConnectivityState({
    this.airplane = false,
    this.airdrop = true,
    this.wifi = true,
    this.bluetooth = true,
    this.cellular = true,
    this.data = false,
  });
}

class LiquidGlassConnectivityCard extends LiquidGlass {
  LiquidGlassConnectivityCard({
    required super.position,
    required CcConnectivityState state,
    required VoidCallback onToggleAirplane,
    required VoidCallback onToggleAirdrop,
    required VoidCallback onToggleWifi,
    required VoidCallback onToggleBluetooth,
    required VoidCallback onToggleCellular,
    required VoidCallback onToggleData,
    super.width = 200,
    super.height = 200,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          magnification: 1,
          distortion: 0.08,
          distortionWidth: 34,
          chromaticAberration: 0,
          saturation: 1.25,
          color: Colors.white.withAlpha(50),
          blur: const LiquidGlassBlur(),
          shape: const RoundedRectangleShape(
            cornerRadius: 32,
            borderWidth: 1.0,
            lightIntensity: 1.1,
            lightDirection: 80,
            borderType: OpticalBorder(
              borderSaturation: 0.8,
              ambientIntensity: 1.0,
              borderSolidity: 0.35,
            ),
          ),
          child: _ConnectivityGrid(
            state: state,
            onToggleAirplane: onToggleAirplane,
            onToggleAirdrop: onToggleAirdrop,
            onToggleWifi: onToggleWifi,
            onToggleBluetooth: onToggleBluetooth,
            onToggleCellular: onToggleCellular,
            onToggleData: onToggleData,
          ),
        );
}

class _ConnectivityGrid extends StatelessWidget {
  final CcConnectivityState state;
  final VoidCallback onToggleAirplane;
  final VoidCallback onToggleAirdrop;
  final VoidCallback onToggleWifi;
  final VoidCallback onToggleBluetooth;
  final VoidCallback onToggleCellular;
  final VoidCallback onToggleData;

  const _ConnectivityGrid({
    required this.state,
    required this.onToggleAirplane,
    required this.onToggleAirdrop,
    required this.onToggleWifi,
    required this.onToggleBluetooth,
    required this.onToggleCellular,
    required this.onToggleData,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CcRoundIcon(
                    icon: Icons.airplanemode_active_rounded,
                    active: state.airplane,
                    activeColor: const Color(0xFFFF9500),
                    onTap: onToggleAirplane,
                  ),
                ),
                Expanded(
                  child: _CcRoundIcon(
                    icon: Icons.podcasts_rounded,
                    active: state.airdrop,
                    activeColor: const Color(0xFF007AFF),
                    onTap: onToggleAirdrop,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CcRoundIcon(
                    icon: Icons.wifi_rounded,
                    active: state.wifi,
                    activeColor: const Color(0xFF007AFF),
                    onTap: onToggleWifi,
                  ),
                ),
                Expanded(
                  child: _CcRoundIcon(
                    icon: Icons.bluetooth_rounded,
                    active: state.bluetooth,
                    activeColor: const Color(0xFF007AFF),
                    onTap: onToggleBluetooth,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _CcRoundIcon(
                    icon: Icons.signal_cellular_alt_rounded,
                    active: state.cellular,
                    activeColor: const Color(0xFF34C759),
                    onTap: onToggleCellular,
                  ),
                ),
                Expanded(
                  child: _CcRoundIcon(
                    icon: Icons.public_rounded,
                    active: state.data,
                    activeColor: const Color(0xFF007AFF),
                    onTap: onToggleData,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CcRoundIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _CcRoundIcon({
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.white.withAlpha(36),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withAlpha(active ? 60 : 80),
                width: 0.6,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassNowPlayingCard extends LiquidGlass {
  LiquidGlassNowPlayingCard({
    required super.position,
    required String track,
    required String artist,
    required bool isPlaying,
    required VoidCallback onPlayPause,
    VoidCallback? onPrev,
    VoidCallback? onNext,
    VoidCallback? onAirplay,
    Widget? artwork,
    super.width = 200,
    super.height = 200,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          magnification: 1,
          distortion: 0.08,
          distortionWidth: 34,
          chromaticAberration: 0,
          saturation: 1.25,
          color: Colors.white.withAlpha(50),
          blur: const LiquidGlassBlur(),
          shape: const RoundedRectangleShape(
            cornerRadius: 32,
            borderWidth: 1.0,
            lightIntensity: 1.1,
            lightDirection: 80,
            borderType: OpticalBorder(
              borderSaturation: 0.8,
              ambientIntensity: 1.0,
              borderSolidity: 0.35,
            ),
          ),
          child: _NowPlayingBody(
            track: track,
            artist: artist,
            isPlaying: isPlaying,
            onPlayPause: onPlayPause,
            onPrev: onPrev,
            onNext: onNext,
            onAirplay: onAirplay,
            artwork: artwork,
          ),
        );
}

class _NowPlayingBody extends StatelessWidget {
  final String track;
  final String artist;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onAirplay;
  final Widget? artwork;

  const _NowPlayingBody({
    required this.track,
    required this.artist,
    required this.isPlaying,
    required this.onPlayPause,
    this.onPrev,
    this.onNext,
    this.onAirplay,
    this.artwork,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: artwork ??
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF6B7280),
                              Color(0xFF374151),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAirplay,
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            track,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withAlpha(180),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CcTransportButton(
                icon: Icons.fast_rewind_rounded,
                onTap: onPrev,
              ),
              _CcTransportButton(
                icon: isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: onPlayPause,
              ),
              _CcTransportButton(
                icon: Icons.fast_forward_rounded,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CcTransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CcTransportButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class LiquidGlassRoundTile extends LiquidGlass {
  LiquidGlassRoundTile({
    required super.position,
    required IconData icon,
    bool active = false,
    Color activeColor = const Color(0xFFFF9500),
    Color iconColor = Colors.white,
    VoidCallback? onTap,
    double size = 60,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          width: size,
          height: size,
          magnification: 1,
          distortion: 0.1,
          distortionWidth: 30,
          chromaticAberration: 0,
          saturation: 1.25,
          color: active
              ? activeColor.withAlpha(180)
              : Colors.white.withAlpha(50),
          blur: const LiquidGlassBlur(),
          shape: RoundedRectangleShape(
            cornerRadius: size / 2,
            borderWidth: 1.0,
            lightIntensity: active ? 1.5 : 1.1,
            lightDirection: 80,
            borderType: const OpticalBorder(
              borderSaturation: 0.8,
              ambientIntensity: 1.0,
              borderSolidity: 0.4,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Icon(icon, color: iconColor, size: size * 0.45),
              ),
            ),
          ),
        );
}

/// Visual fill drawn under the slider lens (white fill + bottom icon).
class VerticalSliderFill extends StatelessWidget {
  final double value;
  final IconData icon;
  final Color iconColor;
  final double width;
  final double height;

  const VerticalSliderFill({
    super.key,
    required this.value,
    required this.icon,
    this.iconColor = const Color(0xFF007AFF),
    this.width = 84,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final radius = width / 2;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            FractionallySizedBox(
              heightFactor: value.clamp(0.0, 1.0),
              widthFactor: 1,
              child: Container(color: Colors.white),
            ),
            Positioned(
              bottom: 14,
              child: Icon(icon, color: iconColor, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glass pill lens that overlays a [VerticalSliderFill]. Carries the
/// gesture detector mapping vertical drag to a 0..1 value.
LiquidGlass buildVerticalSliderLens({
  required double left,
  required double top,
  required double width,
  required double height,
  required double value,
  required ValueChanged<double> onChanged,
}) {
  return LiquidGlass(
    position: LiquidGlassOffsetPosition(left: left, top: top),
    width: width,
    height: height,
    magnification: 1,
    distortion: 0.1,
    distortionWidth: 30,
    chromaticAberration: 0,
    saturation: 1.25,
    color: Colors.white.withAlpha(50),
    blur: const LiquidGlassBlur(),
    shape: RoundedRectangleShape(
      cornerRadius: width / 2,
      borderWidth: 1.0,
      lightIntensity: 1.2,
      lightDirection: 80,
      borderType: const OpticalBorder(
        borderSaturation: 0.8,
        ambientIntensity: 1.0,
        borderSolidity: 0.5,
      ),
    ),
    child: _VerticalSliderGestureChild(
      width: width,
      height: height,
      onChanged: onChanged,
    ),
  );
}

class _VerticalSliderGestureChild extends StatelessWidget {
  final double width;
  final double height;
  final ValueChanged<double> onChanged;

  const _VerticalSliderGestureChild({
    required this.width,
    required this.height,
    required this.onChanged,
  });

  void _handle(double localY) {
    final clamped = (1.0 - (localY / height)).clamp(0.0, 1.0);
    onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => _handle(d.localPosition.dy),
        onTapDown: (d) => _handle(d.localPosition.dy),
      ),
    );
  }
}

class LiquidGlassFocusPill extends LiquidGlass {
  LiquidGlassFocusPill({
    required super.position,
    required VoidCallback onTap,
    super.width = 200,
    super.height = 64,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          magnification: 1,
          distortion: 0.08,
          distortionWidth: 32,
          chromaticAberration: 0,
          saturation: 1.25,
          color: Colors.white.withAlpha(50),
          blur: const LiquidGlassBlur(),
          shape: RoundedRectangleShape(
            cornerRadius: height / 2,
            borderWidth: 1.0,
            lightIntensity: 1.1,
            lightDirection: 80,
            borderType: const OpticalBorder(
              borderSaturation: 0.8,
              ambientIntensity: 1.0,
              borderSolidity: 0.35,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(height / 2),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.nightlight_round,
                      color: Colors.white,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Focus',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.unfold_more_rounded,
                      color: Colors.white.withAlpha(200),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
}

/// iOS-style Control Center built entirely from liquid-glass lenses.
/// All tiles are siblings inside a single [LiquidGlassView]; the view
/// uses realtime capture so the glass refracts live as tiles update.
class ControlCenterPage extends StatefulWidget {
  const ControlCenterPage({super.key});

  @override
  State<ControlCenterPage> createState() => _ControlCenterPageState();
}

class _ControlCenterPageState extends State<ControlCenterPage> {
  final _viewController = LiquidGlassViewController();

  final CcConnectivityState _cc = CcConnectivityState();
  bool _playing = true;
  bool _lockRotation = false;
  bool _bell = true;
  double _brightness = 0.55;
  double _volume = 0.65;
  bool _torch = false;
  bool _timer = false;
  bool _calc = false;
  bool _camera = false;

  static const double _pagePadding = 18;
  static const double _gutter = 14;
  static const double _topOffset = 130;
  static const double _topCardHeight = 196;
  static const double _roundTileSize = 64;
  static const double _vSliderWidth = 72;
  static const double _vSliderHeight = 170;
  static const double _focusPillHeight = 64;
  static const double _bottomTileSize = 70;

  double _screenWidth = 0;

  double get _cardWidth => (_screenWidth - _pagePadding * 2 - _gutter) / 2;
  double get _leftColLeft => _pagePadding;
  double get _rightColLeft => _pagePadding + _cardWidth + _gutter;

  double get _topRowTop => _topOffset;
  double get _middleRowTop => _topRowTop + _topCardHeight + _gutter;
  double get _leftRoundTileLeft =>
      _leftColLeft + (_cardWidth - _roundTileSize * 2 - _gutter) / 2;
  double get _rightRoundTileLeft =>
      _leftRoundTileLeft + _roundTileSize + _gutter;

  double get _vSliderTop => _middleRowTop;
  double get _brightnessLeft =>
      _rightColLeft + (_cardWidth / 2 - _vSliderWidth) / 2;
  double get _volumeLeft =>
      _rightColLeft + _cardWidth / 2 + (_cardWidth / 2 - _vSliderWidth) / 2;

  double get _focusPillTop => _middleRowTop + _roundTileSize + _gutter;

  double get _bottomRowTop =>
      _topRowTop + _topCardHeight + _gutter + _vSliderHeight + _gutter;
  double _bottomTileLeft(int index) {
    final spacing =
        (_screenWidth - _pagePadding * 2 - _bottomTileSize * 4) / 3;
    return _pagePadding + index * (_bottomTileSize + spacing);
  }

  @override
  void dispose() {
    _viewController.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        _screenWidth = constraints.maxWidth;
        return Stack(
          children: [
            LiquidGlassView(
              controller: _viewController,
              backgroundWidget: const ControlCenterBackground(),
              pixelRatio: 1,
              useSync: true,
              realTimeCapture: true,
              refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
              children: [
                LiquidGlassConnectivityCard(
                  position: LiquidGlassOffsetPosition(
                    left: _leftColLeft,
                    top: _topRowTop,
                  ),
                  width: _cardWidth,
                  height: _topCardHeight,
                  state: _cc,
                  onToggleAirplane: () =>
                      setState(() => _cc.airplane = !_cc.airplane),
                  onToggleAirdrop: () =>
                      setState(() => _cc.airdrop = !_cc.airdrop),
                  onToggleWifi: () => setState(() => _cc.wifi = !_cc.wifi),
                  onToggleBluetooth: () =>
                      setState(() => _cc.bluetooth = !_cc.bluetooth),
                  onToggleCellular: () =>
                      setState(() => _cc.cellular = !_cc.cellular),
                  onToggleData: () => setState(() => _cc.data = !_cc.data),
                ),
                LiquidGlassNowPlayingCard(
                  position: LiquidGlassOffsetPosition(
                    left: _rightColLeft,
                    top: _topRowTop,
                  ),
                  width: _cardWidth,
                  height: _topCardHeight,
                  track: 'Backseat Driver',
                  artist: 'Kane Brown',
                  isPlaying: _playing,
                  onPlayPause: () => setState(() => _playing = !_playing),
                ),
                LiquidGlassRoundTile(
                  position: LiquidGlassOffsetPosition(
                    left: _leftRoundTileLeft,
                    top: _middleRowTop,
                  ),
                  size: _roundTileSize,
                  icon: Icons.screen_lock_rotation_rounded,
                  active: _lockRotation,
                  activeColor: const Color(0xFFFF3B30),
                  onTap: () => setState(() => _lockRotation = !_lockRotation),
                ),
                LiquidGlassRoundTile(
                  position: LiquidGlassOffsetPosition(
                    left: _rightRoundTileLeft,
                    top: _middleRowTop,
                  ),
                  size: _roundTileSize,
                  icon: _bell
                      ? Icons.notifications_rounded
                      : Icons.notifications_off_rounded,
                  active: !_bell,
                  activeColor: const Color(0xFFFF9500),
                  onTap: () => setState(() => _bell = !_bell),
                ),
                buildVerticalSliderLens(
                  left: _brightnessLeft,
                  top: _vSliderTop,
                  width: _vSliderWidth,
                  height: _vSliderHeight,
                  value: _brightness,
                  onChanged: (v) => setState(() => _brightness = v),
                ),
                buildVerticalSliderLens(
                  left: _volumeLeft,
                  top: _vSliderTop,
                  width: _vSliderWidth,
                  height: _vSliderHeight,
                  value: _volume,
                  onChanged: (v) => setState(() => _volume = v),
                ),
                LiquidGlassFocusPill(
                  position: LiquidGlassOffsetPosition(
                    left: _leftColLeft,
                    top: _focusPillTop,
                  ),
                  width: _cardWidth,
                  height: _focusPillHeight,
                  onTap: () {},
                ),
                LiquidGlassRoundTile(
                  position: LiquidGlassOffsetPosition(
                    left: _bottomTileLeft(0),
                    top: _bottomRowTop,
                  ),
                  size: _bottomTileSize,
                  icon: Icons.flashlight_on_rounded,
                  active: _torch,
                  activeColor: const Color(0xFFFFCC00),
                  onTap: () => setState(() => _torch = !_torch),
                ),
                LiquidGlassRoundTile(
                  position: LiquidGlassOffsetPosition(
                    left: _bottomTileLeft(1),
                    top: _bottomRowTop,
                  ),
                  size: _bottomTileSize,
                  icon: Icons.timer_rounded,
                  active: _timer,
                  activeColor: const Color(0xFFFFCC00),
                  onTap: () => setState(() => _timer = !_timer),
                ),
                LiquidGlassRoundTile(
                  position: LiquidGlassOffsetPosition(
                    left: _bottomTileLeft(2),
                    top: _bottomRowTop,
                  ),
                  size: _bottomTileSize,
                  icon: Icons.calculate_rounded,
                  active: _calc,
                  activeColor: const Color(0xFFFF9500),
                  onTap: () => setState(() => _calc = !_calc),
                ),
                LiquidGlassRoundTile(
                  position: LiquidGlassOffsetPosition(
                    left: _bottomTileLeft(3),
                    top: _bottomRowTop,
                  ),
                  size: _bottomTileSize,
                  icon: Icons.photo_camera_rounded,
                  active: _camera,
                  activeColor: const Color(0xFFFFCC00),
                  onTap: () => setState(() => _camera = !_camera),
                ),
              ],
            ),
            // Crisp slider fills drawn ON TOP so they aren't refracted
            // by the glass lens underneath (the lens refracts only the
            // wallpaper). IgnorePointer lets drags reach the lens below.
            Positioned(
              left: _brightnessLeft,
              top: _vSliderTop,
              child: IgnorePointer(
                child: VerticalSliderFill(
                  value: _brightness,
                  icon: Icons.brightness_high_rounded,
                  iconColor: const Color(0xFFFFB800),
                  width: _vSliderWidth,
                  height: _vSliderHeight,
                ),
              ),
            ),
            Positioned(
              left: _volumeLeft,
              top: _vSliderTop,
              child: IgnorePointer(
                child: VerticalSliderFill(
                  value: _volume,
                  icon: Icons.volume_up_rounded,
                  iconColor: const Color(0xFF007AFF),
                  width: _vSliderWidth,
                  height: _vSliderHeight,
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(top: 36),
                  child: Text(
                    'Control Center',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
