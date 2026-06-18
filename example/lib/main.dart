import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

// A minimal, self-contained Liquid Glass example: one lens over a background.
// On Impeller (the default on modern iOS/Android) the lens refracts the live
// backdrop with no extra setup. On Skia, wrap your UI in a `LiquidGlassView`
// with a `backgroundWidget` so the lens has a background to refract.
//
// -------------------------------------------------------------------------
// Want the full demos shown in the package README (control center, slider,
// toggle, nav bar, corner styles)? They live next to this file in
// example/lib/. Run the gallery with:
//
//     flutter run -t lib/gallery.dart
//
// (or uncomment the import below, swap the `main` lines, and run normally.)
// -------------------------------------------------------------------------
// import 'gallery.dart';

void main() => runApp(const MyApp());
// void main() => runApp(const GalleryApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Anything you want refracted behind the glass.
            Image.network('https://picsum.photos/800/1600', fit: BoxFit.cover),
            Center(
              child: SizedBox(
                width: 260,
                height: 150,
                child: LiquidGlassLens(
                  style: const LiquidGlassStyle(
                    shape: LiquidGlassShape.squircle(cornerRadius: 44),
                    refraction: LiquidGlassRefraction(
                      distortion: 0.13,
                      distortionWidth: 34,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Liquid Glass',
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
