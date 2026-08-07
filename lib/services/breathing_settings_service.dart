import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the user's guided-breathing preferences:
/// whether haptic vibration cues play at each phase change, and the
/// pattern/duration last used, so the breathing hub can default to
/// them next time.
///
/// Backed by [SharedPreferencesAsync], the same as
/// [AccessibilityService]. A [ChangeNotifier] so [BreathingHubScreen]
/// and [BreathingSessionScreen] pick up a change (e.g. vibration
/// toggled off mid-session from Settings on another device restore)
/// immediately.
class BreathingSettingsService extends ChangeNotifier {
  BreathingSettingsService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _vibrationEnabledKey = 'breathing_vibration_enabled';
  static const String _lastPatternIdKey = 'breathing_last_pattern_id';
  static const String _lastDurationMinutesKey =
      'breathing_last_duration_minutes';

  static const bool defaultVibrationEnabled = true;
  static const int defaultDurationMinutes = 3;

  final SharedPreferencesAsync _preferences;

  bool _vibrationEnabled = defaultVibrationEnabled;
  String? _lastPatternId;
  int _lastDurationMinutes = defaultDurationMinutes;
  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// Whether a short haptic pulse should fire whenever a session
  /// moves to a new breathing phase (inhale, hold, exhale). Purely a
  /// vibration preference — it never silences the visual animation
  /// or on-screen phase label.
  bool get vibrationEnabled => _vibrationEnabled;

  /// The id of the last pattern the user started a session with, if
  /// any — used to pre-select a sensible default on the breathing
  /// hub.
  String? get lastPatternId => _lastPatternId;

  /// The last session length, in minutes, the user chose.
  int get lastDurationMinutes => _lastDurationMinutes;

  /// Loads every persisted preference from disk. Safe to call more
  /// than once.
  Future<void> load() async {
    _vibrationEnabled =
        await _preferences.getBool(_vibrationEnabledKey) ??
            defaultVibrationEnabled;
    _lastPatternId = await _preferences.getString(_lastPatternIdKey);
    _lastDurationMinutes =
        await _preferences.getInt(_lastDurationMinutesKey) ??
            defaultDurationMinutes;
    _loaded = true;
    notifyListeners();
  }

  /// Toggles haptic vibration cues and persists the change.
  Future<void> setVibrationEnabled(bool value) async {
    if (value == _vibrationEnabled) return;
    _vibrationEnabled = value;
    notifyListeners();
    await _preferences.setBool(_vibrationEnabledKey, value);
  }

  /// Records the pattern and duration a session was just started
  /// with, so the hub can default to the same choice next time.
  Future<void> recordLastSession({
    required String patternId,
    required int durationMinutes,
  }) async {
    _lastPatternId = patternId;
    _lastDurationMinutes = durationMinutes;
    notifyListeners();
    await _preferences.setString(_lastPatternIdKey, patternId);
    await _preferences.setInt(_lastDurationMinutesKey, durationMinutes);
  }
}
