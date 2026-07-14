import 'package:flutter/material.dart';

/// Ayantra brand palette — named color constants shared by the brand's
/// liquid-glass components (e.g. `AyantraButtonLiquid`) so tints are
/// referenced by name instead of scattering hex literals across styles.
abstract final class AppColors {
  /// Soft gold — lightest step, used for faint highlights/washes.
  static const Color primary100 = Color(0xFFF9E3BA);

  /// Soft gold — mid-light step.
  static const Color primary200 = Color(0xFFF4C774);

  /// Primary gold — the main brand accent.
  static const Color primary300 = Color(0xFFEEAB2F);

  /// Darker gold — pressed/emphasis step.
  static const Color primary400 = Color(0xFFCB8A11);

  /// Darker gold — deepest step, for shadows/edges on the gold ramp.
  static const Color primary500 = Color(0xFF90610C);

  /// Dark chrome — near-black, used for chrome/background surfaces and
  /// high-contrast text/icons atop the gold accent.
  static const Color secondary500 = Color(0xFF0E0E0E);

  /// Dark chrome surface — the app's base dark surface color.
  static const Color surface = Color(0xFF171717);

  /// Soft white — used at low alpha for frosted-glass edge highlights.
  static const Color neutral100 = Color(0xFFF5F5F5);
}
