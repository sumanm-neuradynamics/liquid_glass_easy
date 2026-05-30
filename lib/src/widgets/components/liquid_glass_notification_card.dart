import 'package:flutter/material.dart';

import '../liquid_glass.dart';
import '../utils/liquid_glass_blur.dart';
import '../utils/liquid_glass_border_mode.dart';
import '../utils/liquid_glass_shape.dart';

/// A lock-screen style notification banner rendered as liquid glass.
///
/// Renders an app icon, app name, time stamp, title, and body inside
/// a translucent liquid-glass card. Use it directly inside a
/// [LiquidGlassView]'s `children:` list.
class LiquidGlassNotificationCard extends LiquidGlass {
  LiquidGlassNotificationCard({
    required super.position,
    required String appName,
    required String title,
    required String body,
    required IconData appIcon,
    String time = 'now',
    Color appIconColor = const Color(0xFF007AFF),

    /// Glass tint of the card body. Defaults to a faint white.
    /// Pass a translucent black (e.g. `Colors.black.withAlpha(40)`)
    /// for a darker, dimmed-glass look.
    super.color = const Color(0x1CFFFFFF), // white, alpha 28
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
