import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of appearance modes ChadMate supports.
///
/// [system] follows the OS-level light/dark setting automatically.
/// The other three are explicit overrides: [light] and [dark] use the
/// app's normal Material 3 palettes, while [amoled] is a dark
/// variant with true-black surfaces (`#000000` rather than a dark
/// gray) so OLED screens can turn those pixels off entirely — better
/// battery life and higher contrast on supported hardware.
enum AppThemeMode {
  light,
  dark,
  amoled,
  system;

  /// Short, user-facing label for this mode, as shown in the theme
  /// picker sheet and the Settings summary row.
  String get label {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.amoled:
        return 'AMOLED Black';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  /// One-line description shown under [label] in the picker sheet.
  String get description {
    switch (this) {
      case AppThemeMode.light:
        return 'Bright surfaces, dark text';
      case AppThemeMode.dark:
        return 'Dark gray surfaces, easy on the eyes';
      case AppThemeMode.amoled:
        return 'True black — saves battery on OLED screens';
      case AppThemeMode.system:
        return "Matches your device's appearance setting";
    }
  }
}

/// Persists and broadcasts the user's chosen appearance mode.
///
/// Backed by [SharedPreferences] under a single string key storing
/// the [AppThemeMode]'s name, so the choice survives app restarts.
/// State is also cached in memory once loaded, so [mode] can be read
/// synchronously (e.g. from a build method) after [load] completes.
///
/// A [ChangeNotifier] rather than a single-widget [State] field so
/// the whole app — not just the Settings screen that changed it —
/// rebuilds the instant the mode changes, the same approach every
/// other persisted preference in the app (favorites, hydration,
/// reminders, ...) already uses.
class ThemeModeService extends ChangeNotifier {
  ThemeModeService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _storageKey = 'app_theme_mode';

  /// The mode used before anything has ever been persisted — matches
  /// the app's previous fixed behavior (following the OS setting) so
  /// upgrading users see no change until they visit Settings.
  static const AppThemeMode defaultMode = AppThemeMode.system;

  final SharedPreferencesAsync _preferences;

  AppThemeMode _mode = defaultMode;
  bool _loaded = false;

  /// Whether [load] has completed at least once. Not currently gated
  /// on by any screen — [_AnimatedAppTheme] in `main.dart` just reads
  /// [mode] directly and falls back to [defaultMode] until [load]
  /// resolves, which happens fast enough (a single local read) that
  /// there's no visible flash in practice.
  bool get isLoaded => _loaded;

  /// The user's currently selected appearance mode. Reads from the
  /// in-memory cache — reports [defaultMode] until [load] has
  /// completed once.
  AppThemeMode get mode => _mode;

  /// Loads the persisted mode from disk. Safe to call more than once;
  /// subsequent calls just re-sync from storage.
  Future<void> load() async {
    final stored = await _preferences.getString(_storageKey);
    _mode = _decode(stored);
    _loaded = true;
    notifyListeners();
  }

  static AppThemeMode _decode(String? raw) {
    if (raw == null) return defaultMode;
    try {
      return AppThemeMode.values.byName(raw);
    } on ArgumentError {
      // Corrupt or unrecognized stored value (e.g. from a future app
      // version's mode this build doesn't know about) shouldn't
      // crash the app; fall back to the default instead.
      return defaultMode;
    }
  }

  /// Updates the appearance mode and persists the change.
  Future<void> setMode(AppThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences.setString(_storageKey, mode.name);
  }
}
