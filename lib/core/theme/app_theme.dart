import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide Material 3 theme configuration for ChadMate.
///
/// Built entirely from the four-color palette defined in [AppColors],
/// plus the handful of near-black grays [dark] and [amoled] need to
/// keep cards and dividers visible against their backgrounds. Three
/// concrete palettes are exposed — [light], [dark], and [amoled] — a
/// system-following mode doesn't need one of its own: it's just
/// [light] or [dark] chosen at runtime from the OS setting (see
/// `main.dart`).
class AppTheme {
  const AppTheme._();

  /// Elevated-surface gray used by [dark] (e.g. card backgrounds).
  /// Distinct from true black so cards read as "raised" against the
  /// scaffold behind them.
  static const Color _darkElevatedSurface = Color(0xFF1C1C1C);

  /// Divider gray used by both dark variants — light enough to be
  /// visible against true black, unlike [AppColors.lightGray] which
  /// is tuned for the light theme.
  static const Color _darkDivider = Color(0xFF2A2A2A);

  /// Slightly-raised-off-black used by [amoled] for cards. Kept very
  /// close to pure black (rather than reusing [_darkElevatedSurface])
  /// so large surfaces still read as "true black" at a glance, while
  /// staying just barely distinguishable from the scaffold so card
  /// edges remain legible.
  static const Color _amoledElevatedSurface = Color(0xFF0A0A0A);

  /// Light theme: white surfaces, black text, blue accent.
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blueAccent,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.blueAccent,
      onPrimary: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.black,
      surfaceContainerHighest: AppColors.lightGray,
    );

    return _themeFrom(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.white,
      dividerColor: AppColors.lightGray,
      appBarForeground: AppColors.black,
    );
  }

  /// Dark theme: dark gray surfaces, white text, the same blue
  /// accent. The default dark mode — comfortable contrast without
  /// the starker look of [amoled].
  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blueAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.blueAccent,
      onPrimary: AppColors.white,
      surface: AppColors.black,
      onSurface: AppColors.white,
      surfaceContainerHighest: _darkElevatedSurface,
    );

    return _themeFrom(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.black,
      dividerColor: _darkDivider,
      appBarForeground: AppColors.white,
    );
  }

  /// AMOLED Black theme: pure `#000000` everywhere — scaffold, app
  /// bar, and even card surfaces sit at or near true black — so OLED
  /// panels can switch those pixels off entirely rather than driving
  /// them at a dark gray. Cards are distinguished from the
  /// background mainly by a subtle border rather than a lighter
  /// fill, since a lighter fill would defeat the point.
  static ThemeData get amoled {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blueAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.blueAccent,
      onPrimary: AppColors.white,
      surface: AppColors.black,
      onSurface: AppColors.white,
      surfaceContainerHighest: _amoledElevatedSurface,
      outlineVariant: _darkDivider,
    );

    return _themeFrom(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.black,
      dividerColor: _darkDivider,
      appBarForeground: AppColors.white,
    );
  }

  /// Shared [ThemeData] construction for all three palettes, so
  /// component theming (app bar, buttons, dividers) can't drift out
  /// of sync between them — only the [colorScheme] and the handful of
  /// values that don't derive cleanly from it differ per palette.
  static ThemeData _themeFrom({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color dividerColor,
    required Color appBarForeground,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: dividerColor,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: appBarForeground,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blueAccent,
          foregroundColor: AppColors.white,
          minimumSize: const Size(48, 48),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }

  /// Applies a high-contrast pass on top of an already-resolved
  /// [ThemeData] — pure white/black text against pure white/black
  /// surfaces (no gray text), a stronger divider, and outlined card
  /// borders. Layered on top of [light], [dark], or [amoled] rather
  /// than being a fourth standalone palette, so high contrast
  /// composes with the user's chosen appearance mode instead of
  /// replacing it.
  static ThemeData applyHighContrast(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.white : AppColors.black;
    final outline = isDark ? AppColors.white : AppColors.black;

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        onSurface: onSurface,
        onSurfaceVariant: onSurface,
        outline: outline,
        outlineVariant: outline.withValues(alpha: 0.6),
      ),
      dividerColor: outline,
      textTheme: base.textTheme.apply(
        bodyColor: onSurface,
        displayColor: onSurface,
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: outline.withValues(alpha: 0.5), width: 1.5),
        ),
      ),
    );
  }
}

