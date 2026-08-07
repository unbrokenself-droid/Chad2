import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The set of text-size steps ChadMate supports, layered on top
/// of whatever text-scale the OS already applies.
///
/// Each step multiplies the OS scale factor rather than replacing it,
/// so a user who already has large system text gets it scaled up
/// further, not reset to the app's own baseline.
enum AppTextScale {
  standard,
  large,
  extraLarge;

  /// Short, user-facing label shown in the accessibility picker.
  String get label {
    switch (this) {
      case AppTextScale.standard:
        return 'Standard';
      case AppTextScale.large:
        return 'Large';
      case AppTextScale.extraLarge:
        return 'Extra Large';
    }
  }

  /// One-line description shown under [label] in the picker.
  String get description {
    switch (this) {
      case AppTextScale.standard:
        return "Matches your device's text size";
      case AppTextScale.large:
        return 'About 15% bigger than standard';
      case AppTextScale.extraLarge:
        return 'About 30% bigger than standard';
    }
  }

  /// The multiplier applied on top of the OS-level text scale factor.
  double get multiplier {
    switch (this) {
      case AppTextScale.standard:
        return 1.0;
      case AppTextScale.large:
        return 1.15;
      case AppTextScale.extraLarge:
        return 1.3;
    }
  }
}

/// Persists and broadcasts the user's accessibility preferences:
/// text size, high-contrast mode, reduced motion, and larger touch
/// targets.
///
/// Backed by [SharedPreferences], the same as [ThemeModeService], so
/// every choice survives app restarts. A [ChangeNotifier] so the
/// whole app rebuilds the instant a preference changes — most
/// visibly through [main.dart], which reads [textScale] and
/// [reduceMotion] to override [MediaQuery] for every screen below it.
class AccessibilityService extends ChangeNotifier {
  AccessibilityService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _textScaleKey = 'a11y_text_scale';
  static const String _highContrastKey = 'a11y_high_contrast';
  static const String _reduceMotionKey = 'a11y_reduce_motion';
  static const String _largeTouchTargetsKey = 'a11y_large_touch_targets';

  static const AppTextScale defaultTextScale = AppTextScale.standard;

  final SharedPreferencesAsync _preferences;

  AppTextScale _textScale = defaultTextScale;
  bool _highContrast = false;
  bool _reduceMotion = false;
  bool _largeTouchTargets = false;
  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// The user's chosen text-size step, applied on top of the OS text
  /// scale. Reports [defaultTextScale] until [load] resolves.
  AppTextScale get textScale => _textScale;

  /// Whether high-contrast styling is enabled — stronger borders,
  /// higher-contrast text and surface colors.
  bool get highContrast => _highContrast;

  /// Whether the user has explicitly asked the app to minimize
  /// animation, independent of the OS-level "reduce motion" setting.
  /// [main.dart] combines this with the platform setting, so either
  /// one being on is enough to simplify transitions app-wide.
  bool get reduceMotion => _reduceMotion;

  /// Whether interactive elements should use enlarged tap targets
  /// (at least 48x48) beyond Material's normal minimum.
  ///
  /// Applied via `MinTapTarget`/`kLargeTouchTargetSize`
  /// (`lib/widgets/shared/min_tap_target.dart`) for widgets with no
  /// sizing property of their own to adjust directly, and directly
  /// through each widget's own sizing mechanism otherwise — see that
  /// file's doc comment for which is which and why. Read broadly by
  /// `PrimaryButton`, `SettingsNavTile`, `AppBottomNavigationBar`, the
  /// exercise-options menu, all three filter-chip widgets, and the
  /// favorite/bookmark buttons — if a new interactive widget doesn't
  /// respect this, that's a gap to close there, not evidence this
  /// getter needs a narrower promise.
  bool get largeTouchTargets => _largeTouchTargets;

  /// Loads every persisted preference from disk. Safe to call more
  /// than once; subsequent calls just re-sync from storage.
  Future<void> load() async {
    final storedScale = await _preferences.getString(_textScaleKey);
    _textScale = _decodeScale(storedScale);
    _highContrast = await _preferences.getBool(_highContrastKey) ?? false;
    _reduceMotion = await _preferences.getBool(_reduceMotionKey) ?? false;
    _largeTouchTargets =
        await _preferences.getBool(_largeTouchTargetsKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  static AppTextScale _decodeScale(String? raw) {
    if (raw == null) return defaultTextScale;
    try {
      return AppTextScale.values.byName(raw);
    } on ArgumentError {
      return defaultTextScale;
    }
  }

  /// Updates the text-size step and persists the change.
  Future<void> setTextScale(AppTextScale scale) async {
    if (scale == _textScale) return;
    _textScale = scale;
    notifyListeners();
    await _preferences.setString(_textScaleKey, scale.name);
  }

  /// Toggles high-contrast styling and persists the change.
  Future<void> setHighContrast(bool value) async {
    if (value == _highContrast) return;
    _highContrast = value;
    notifyListeners();
    await _preferences.setBool(_highContrastKey, value);
  }

  /// Toggles the app-level reduce-motion override and persists the
  /// change.
  Future<void> setReduceMotion(bool value) async {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    notifyListeners();
    await _preferences.setBool(_reduceMotionKey, value);
  }

  /// Toggles enlarged touch targets and persists the change.
  Future<void> setLargeTouchTargets(bool value) async {
    if (value == _largeTouchTargets) return;
    _largeTouchTargets = value;
    notifyListeners();
    await _preferences.setBool(_largeTouchTargetsKey, value);
  }
}
