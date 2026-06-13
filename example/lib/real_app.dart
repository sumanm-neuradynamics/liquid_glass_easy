import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// =============================================================
// Liquid Glass Easy — a small but REAL app.
//
//   flutter run -t lib/real_app.dart
//
// Four polished screens wired into a single LiquidGlassScaffold whose
// glass app bar + bottom nav refract the live content behind them:
//
//   • Home      — weather hero + glass stat tiles
//   • Music     — now-playing with glass scrubber & volume sliders
//   • Home Kit  — smart-home room with glass toggles & dimmers
//   • Settings  — a settings list of glass toggle rows
//
// Everything is offline-safe (in-code gradients), so it just runs.
// =============================================================

void main() => runApp(const RealApp());

class RealApp extends StatelessWidget {
  const RealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamilyFallback: const ['SF Pro', 'Roboto'],
            ),
      ),
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _index = 0;

  static const _titles = ['Today', 'Now Playing', 'My Home', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final Widget body = switch (_index) {
      0 => const HomeScreen(),
      1 => const MusicScreen(),
      2 => const HomeKitScreen(),
      _ => const SettingsScreen(),
    };

    return LiquidGlassScaffold(
      // The page content IS the background the glass bars refract.
      body: body,
      appBar: LiquidGlassAppBar(
        width: width - 32,
        title: Text(_titles[_index]),
        leading: const Icon(Icons.grid_view_rounded, size: 22),
        actions: const [Icon(Icons.notifications_none_rounded, size: 22)],
      ),
      bottomNavigationBar: LiquidGlassBottomNavBar(
        width: width - 32,
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        pillStyle: const LiquidGlassNavPillStyle(
          mode: LiquidGlassPillMode.both,
          animated: true,
        ),
        items: const [
          LiquidGlassTabBarItem(
              icon: Icons.wb_sunny_outlined,
              selectedIcon: Icons.wb_sunny_rounded,
              label: 'Today'),
          LiquidGlassTabBarItem(
              icon: Icons.music_note_outlined,
              selectedIcon: Icons.music_note_rounded,
              label: 'Music'),
          LiquidGlassTabBarItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home'),
          LiquidGlassTabBarItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'Settings'),
        ],
      ),
    );
  }
}

// =============================================================
// Shared building blocks
// =============================================================

/// Full-screen vertical gradient wallpaper.
class _Wallpaper extends StatelessWidget {
  final List<Color> colors;
  final Widget child;
  const _Wallpaper({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

/// A refracting glass card built on the new lens-anywhere API —
/// [LiquidGlassLens] dropped straight into the screen. On Impeller it
/// refracts the live wallpaper behind it; on Skia it falls back to
/// frosted glass. A light blur + tint keeps content legible on top.
class GlassCard extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Widget child;

  const GlassCard({
    super.key,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: LiquidGlassLens(
        shape: RoundedRectangleShape(
          cornerRadius: radius,
          cornerSmoothing: 1,
          borderWidth: 1.1,
        ),
        refraction: const LiquidGlassRefraction(
          distortion: 0.1,
          distortionWidth: 22,
        ),
        appearance: const LiquidGlassAppearance(
          blur: LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
          color: Color(0x12FFFFFF),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Top padding that clears the floating app bar.
double _topInset(BuildContext context) =>
    MediaQuery.paddingOf(context).top + 76;

// =============================================================
// 1. HOME / WEATHER
// =============================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _Wallpaper(
      colors: const [
        Color(0xFF1B3A6B),
        Color(0xFF3A6EA5),
        Color(0xFFE08A4C),
        Color(0xFFF4C57E),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, _topInset(context), 20, 140),
        children: [
          // Hero weather card
          GlassCard(
            height: 220,
            padding: const EdgeInsets.all(26),
            radius: 34,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('San Francisco',
                    style: TextStyle(fontSize: 18, color: Colors.white70)),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('21°',
                        style: TextStyle(
                            fontSize: 76,
                            fontWeight: FontWeight.w200,
                            height: 1)),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(Icons.wb_sunny_rounded,
                            size: 44, color: Color(0xFFFFD479)),
                        const SizedBox(height: 6),
                        Text('Mostly Sunny',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('H:24°   L:15°',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Hourly strip
          GlassCard(
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: _hours.length,
              separatorBuilder: (_, __) => const SizedBox(width: 22),
              itemBuilder: (_, i) {
                final h = _hours[i];
                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(h.$1,
                        style: const TextStyle(color: Colors.white70)),
                    Icon(h.$2, color: Colors.white, size: 24),
                    Text('${h.$3}°',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Two stat tiles
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  height: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TileHeader(icon: Icons.air_rounded, label: 'WIND'),
                      Spacer(),
                      Text('12',
                          style: TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w300)),
                      Text('km/h  NE',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassCard(
                  height: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TileHeader(
                          icon: Icons.water_drop_outlined, label: 'HUMIDITY'),
                      Spacer(),
                      Text('63',
                          style: TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w300)),
                      Text('% · dew 12°',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const List<(String, IconData, int)> _hours = [
    ('Now', Icons.wb_sunny_rounded, 21),
    ('1PM', Icons.wb_sunny_rounded, 22),
    ('2PM', Icons.wb_cloudy_rounded, 22),
    ('3PM', Icons.wb_cloudy_rounded, 21),
    ('4PM', Icons.grain_rounded, 19),
    ('5PM', Icons.grain_rounded, 18),
    ('6PM', Icons.nights_stay_rounded, 16),
  ];
}

class _TileHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TileHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                color: Colors.white70,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// =============================================================
// 2. MUSIC / NOW PLAYING
// =============================================================

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  double _progress = 0.32;
  double _volume = 0.7;
  bool _playing = true;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return _Wallpaper(
      colors: const [
        Color(0xFF2B1055),
        Color(0xFF7597DE),
        Color(0xFFB06AB3),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, _topInset(context), 24, 150),
        children: [
          // Album art
          Center(
            child: Container(
              width: w * 0.62,
              height: w * 0.62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
                ),
              ),
              child: const Icon(Icons.album_rounded,
                  size: 120, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 30),
          const Text('Midnight City',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('M83 · Hurry Up, We\'re Dreaming',
              style: TextStyle(fontSize: 15, color: Colors.white70)),
          const SizedBox(height: 24),
          // Glass scrubber
          Center(
            child: LiquidGlassSlider(
              value: _progress,
              activeColor: Colors.white,
              layout: LiquidGlassSliderLayout(width: w - 48),
              onChanged: (v) => setState(() => _progress = v),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1:18', style: TextStyle(color: Colors.white60)),
                Text('-2:42', style: TextStyle(color: Colors.white60)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Transport controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shuffle_rounded, color: Colors.white70),
              const SizedBox(width: 28),
              const Icon(Icons.skip_previous_rounded, size: 42),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => setState(() => _playing = !_playing),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              const Icon(Icons.skip_next_rounded, size: 42),
              const SizedBox(width: 28),
              const Icon(Icons.repeat_rounded, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 28),
          // Volume row with glass slider
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: LiquidGlassSlider(
                  value: _volume,
                  activeColor: Colors.white,
                  layout: LiquidGlassSliderLayout(width: w - 48 - 72),
                  onChanged: (v) => setState(() => _volume = v),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.volume_up_rounded, color: Colors.white70),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 3. SMART HOME
// =============================================================

class HomeKitScreen extends StatefulWidget {
  const HomeKitScreen({super.key});

  @override
  State<HomeKitScreen> createState() => _HomeKitScreenState();
}

class _HomeKitScreenState extends State<HomeKitScreen> {
  bool _lights = true;
  bool _ac = false;
  bool _tv = false;
  double _brightness = 0.65;
  double _temp = 0.5;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return _Wallpaper(
      colors: const [
        Color(0xFF0F2027),
        Color(0xFF203A43),
        Color(0xFF2C5364),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, _topInset(context), 20, 140),
        children: [
          const Text('Living Room',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('3 devices · 22°C',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          // Device quick-toggles
          Row(
            children: [
              Expanded(
                child: _DeviceTile(
                  icon: Icons.lightbulb_rounded,
                  label: 'Lights',
                  on: _lights,
                  onChanged: (v) => setState(() => _lights = v),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DeviceTile(
                  icon: Icons.ac_unit_rounded,
                  label: 'A/C',
                  on: _ac,
                  onChanged: (v) => setState(() => _ac = v),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DeviceTile(
                  icon: Icons.tv_rounded,
                  label: 'TV',
                  on: _tv,
                  onChanged: (v) => setState(() => _tv = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Brightness dimmer
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TileHeader(
                    icon: Icons.brightness_6_rounded, label: 'BRIGHTNESS'),
                const SizedBox(height: 16),
                Center(
                  child: LiquidGlassSlider(
                    value: _brightness,
                    activeColor: const Color(0xFFFFD479),
                    layout: LiquidGlassSliderLayout(width: w - 80),
                    onChanged: (v) => setState(() => _brightness = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Thermostat
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TileHeader(
                    icon: Icons.thermostat_rounded, label: 'TEMPERATURE'),
                const SizedBox(height: 4),
                Text('${(16 + _temp * 14).round()}°C',
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w300)),
                const SizedBox(height: 12),
                Center(
                  child: LiquidGlassSlider(
                    value: _temp,
                    activeColor: const Color(0xFFFF7043),
                    layout: LiquidGlassSliderLayout(width: w - 80),
                    onChanged: (v) => setState(() => _temp = v),
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

class _DeviceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final ValueChanged<bool> onChanged;

  const _DeviceTile({
    required this.icon,
    required this.label,
    required this.on,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      height: 150,
      padding: const EdgeInsets.all(16),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 28,
              color: on ? const Color(0xFFFFD479) : Colors.white54),
          const Spacer(),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          Text(on ? 'On' : 'Off',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: LiquidGlassToggle(
              value: on,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// 4. SETTINGS
// =============================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, bool> _values = {
    'Airplane Mode': false,
    'Wi-Fi': true,
    'Bluetooth': true,
    'Cellular Data': true,
    'Low Power Mode': false,
    'Dark Appearance': true,
  };

  static const _icons = {
    'Airplane Mode': Icons.airplanemode_active_rounded,
    'Wi-Fi': Icons.wifi_rounded,
    'Bluetooth': Icons.bluetooth_rounded,
    'Cellular Data': Icons.signal_cellular_alt_rounded,
    'Low Power Mode': Icons.battery_saver_rounded,
    'Dark Appearance': Icons.dark_mode_rounded,
  };

  static const _tints = {
    'Airplane Mode': Color(0xFFFF9500),
    'Wi-Fi': Color(0xFF0A84FF),
    'Bluetooth': Color(0xFF0A84FF),
    'Cellular Data': Color(0xFF34C759),
    'Low Power Mode': Color(0xFFFFD60A),
    'Dark Appearance': Color(0xFF8E8E93),
  };

  @override
  Widget build(BuildContext context) {
    final keys = _values.keys.toList();
    return _Wallpaper(
      colors: const [
        Color(0xFF232526),
        Color(0xFF414345),
        Color(0xFF6A3093),
      ],
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, _topInset(context), 20, 140),
        children: [
          // Profile card
          GlassCard(
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF00C6FB), Color(0xFF005BEA)],
                    ),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 34, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Alex Morgan',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Apple ID · iCloud · Media',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Settings group as one glass card with toggle rows
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (int i = 0; i < keys.length; i++) ...[
                  _SettingRow(
                    icon: _icons[keys[i]]!,
                    tint: _tints[keys[i]]!,
                    label: keys[i],
                    value: _values[keys[i]]!,
                    onChanged: (v) => setState(() => _values[keys[i]] = v),
                  ),
                  if (i != keys.length - 1)
                    const Divider(
                      height: 1,
                      indent: 64,
                      color: Colors.white12,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Text(label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
          const Spacer(),
          LiquidGlassToggle(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
