# liquid_glass_easy_example

A self-contained demo of the [`liquid_glass_easy`](https://pub.dev/packages/liquid_glass_easy)
package. Everything lives in a single `lib/main.dart`, so you can copy it into a
fresh Flutter project, add the package to your `pubspec.yaml`, and run it as-is.

## What it shows

A single **Next Background** button at the bottom cycles through every demo page:

1. **Control Center** — an iOS-style control center built entirely from liquid glass
   (connectivity grid, now-playing card, brightness/volume sliders, and round toggle tiles).
2. **Notifications** — a lock-screen with stacked glass notification cards plus
   flashlight and camera corner buttons, each using the new `OpticalBorder`.
3. **Lens playground (6 wallpapers)** — a single draggable `LiquidGlass` lens over
   different network wallpapers, showcasing both `OpticalBorder` and `ClassicBorder`,
   superellipse and rounded-rectangle shapes, blur, and chromatic aberration.

The backgrounds load hosted images and gracefully fall back to in-code gradients,
so the demo runs even offline.

## Run

```bash
cd example
flutter run
```

## Using your own images (optional)

The lens playground loads wallpapers over the network. To use bundled assets instead:

1. Add your files under `example/assets/` (e.g. `forest.jpg`, `mountain.jpg`).
2. Uncomment the `assets:` section in `example/pubspec.yaml`.
3. Replace the `Image.network(...)` calls in `_buildBackground()` (inside `main.dart`)
   with `Image.asset(..., fit: BoxFit.cover)`.
