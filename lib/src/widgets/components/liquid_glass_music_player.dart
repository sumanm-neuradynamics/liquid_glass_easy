import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// A miniature "Now Playing" widget rendered as liquid glass.
///
/// Layout matches the typical lock-screen / control-center now-playing
/// pill: a small artwork on the left, track + artist in the middle,
/// and a play / pause button on the right.
class LiquidGlassMusicPlayer extends LiquidGlass {
  LiquidGlassMusicPlayer({
    required super.position,
    required String track,
    required String artist,
    required bool isPlaying,
    VoidCallback? onPlayPause,
    Widget? artwork,
    super.width = 320,
    super.height = 86,
    super.controller,
    super.draggable = false,
    super.outOfBoundaries = false,
  }) : super(
          magnification: 1,
          distortion: 0.08,
          distortionWidth: 32,
          chromaticAberration: 0.002,
          color: Colors.white.withAlpha(28),
          blur: const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
          shape: const RoundedRectangleShape(
            cornerRadius: 22,
            borderWidth: 1.0,
            lightIntensity: 1.1,
            lightDirection: 80,
            borderType: OpticalBorder(
              borderSaturation: 1.2,
              ambientIntensity: 1.0,
              borderSolidity: 0.35,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: artwork ??
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF6B6B),
                                Color(0xFFB23BFF),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.music_note_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        track,
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
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPlayPause,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
}
