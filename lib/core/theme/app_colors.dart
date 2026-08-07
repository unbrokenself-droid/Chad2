import 'package:flutter/material.dart';

/// Centralized color palette for the ChadMate app.
///
/// The design brief intentionally limits the palette to four colors:
/// black, white, light gray, and a blue accent. All theming should be
/// derived from these constants rather than hard-coded elsewhere.
class AppColors {
  const AppColors._();

  /// Primary black, used for high-emphasis text and dark surfaces.
  static const Color black = Color(0xFF000000);

  /// Primary white, used for backgrounds and high-contrast text.
  static const Color white = Color(0xFFFFFFFF);

  /// Light gray, used for subtle surfaces, dividers, and disabled states.
  static const Color lightGray = Color(0xFFF2F2F2);

  /// Blue accent, used for primary actions and interactive elements.
  static const Color blueAccent = Color(0xFF2962FF);
}
