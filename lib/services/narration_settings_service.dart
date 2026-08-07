import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts the user's text-to-speech preferences:
/// whether spoken instructions are on at all, plus speech rate,
/// pitch, and volume for when they are.
///
/// Backed by [SharedPreferences], the same as [AccessibilityService].
/// A [ChangeNotifier] so [NarrationSettingsSheet]'s toggle/sliders and
/// [TtsExerciseNarrator] both stay in sync the instant a value
/// changes from either one — in particular, [TtsExerciseNarrator]
/// reads [speechRate]/[pitch]/[volume] fresh at the start of every
/// segment (see its class doc comment), so a change made mid-reading
/// takes effect from the *next* segment onward rather than needing
/// narration to be stopped and restarted first. [narrationEnabled] is
/// read once per session instead, by [WorkoutSessionScreen] when it
/// constructs [WorkoutSessionManager] — see that manager's own doc
/// comment for why toggling it belongs to the screen layer rather
/// than this service or the manager reaching for each other directly.
///
/// The three speech values use `flutter_tts`'s own normalized ranges
/// directly ([speechRate]/[volume] `0.0`–`1.0`, [pitch] `0.5`–`2.0`)
/// rather than inventing app-specific ones, so nothing needs
/// translating at the point they're actually applied.
class NarrationSettingsService extends ChangeNotifier {
  NarrationSettingsService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _enabledKey = 'narration_enabled';
  static const String _speechRateKey = 'narration_speech_rate';
  static const String _pitchKey = 'narration_pitch';
  static const String _volumeKey = 'narration_volume';

  /// A moderate, unhurried default — `flutter_tts`'s own default of
  /// `0.5` reads as noticeably fast for step-by-step spoken
  /// instructions someone is meant to actually follow along with.
  static const double defaultSpeechRate = 0.42;

  /// Neutral pitch — the midpoint of `flutter_tts`'s 0.5–2.0 range.
  static const double defaultPitch = 1.0;

  /// Full volume, matching every other audio the app produces
  /// (reminders, etc.) having no separate app-level volume control of
  /// its own.
  static const double defaultVolume = 1.0;

  final SharedPreferencesAsync _preferences;

  bool _enabled = true;
  double _speechRate = defaultSpeechRate;
  double _pitch = defaultPitch;
  double _volume = defaultVolume;
  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// Whether spoken instructions should play during a workout session
  /// at all — the "Voice Guide" toggle in [MusicVoiceSheet] and
  /// [NarrationSettingsSheet]. Defaults to `true`: narration was the
  /// original behavior before this toggle existed, so a fresh install
  /// (and every install that predates this field) keeps working
  /// exactly as it already did rather than going silent by default.
  bool get narrationEnabled => _enabled;

  /// Speech rate, `0.0` (slowest) to `1.0` (fastest). Reports
  /// [defaultSpeechRate] until [load] resolves.
  double get speechRate => _speechRate;

  /// Voice pitch, `0.5` (lowest) to `2.0` (highest), `1.0` neutral.
  /// Reports [defaultPitch] until [load] resolves.
  double get pitch => _pitch;

  /// Playback volume, `0.0` (silent) to `1.0` (full). Reports
  /// [defaultVolume] until [load] resolves.
  double get volume => _volume;

  /// Loads every persisted preference from disk. Safe to call more
  /// than once; subsequent calls just re-sync from storage.
  Future<void> load() async {
    _enabled = await _preferences.getBool(_enabledKey) ?? true;
    _speechRate =
        await _preferences.getDouble(_speechRateKey) ?? defaultSpeechRate;
    _pitch = await _preferences.getDouble(_pitchKey) ?? defaultPitch;
    _volume = await _preferences.getDouble(_volumeKey) ?? defaultVolume;
    _loaded = true;
    notifyListeners();
  }

  /// Enables or disables spoken instructions during a workout session
  /// and persists the change. Doesn't stop narration already in
  /// progress — [narrationEnabled] is only read once per session, at
  /// the start (see this class's doc comment), so a change here takes
  /// effect on the *next* session rather than interrupting one
  /// already running.
  Future<void> setNarrationEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    await _preferences.setBool(_enabledKey, value);
  }

  /// Updates the speech rate and persists the change. Clamped to
  /// `flutter_tts`'s valid `0.0`–`1.0` range so a slider rounding
  /// error or a future caller can't send it an out-of-range value.
  Future<void> setSpeechRate(double value) async {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (clamped == _speechRate) return;
    _speechRate = clamped;
    notifyListeners();
    await _preferences.setDouble(_speechRateKey, clamped);
  }

  /// Updates the pitch and persists the change. Clamped to
  /// `flutter_tts`'s valid `0.5`–`2.0` range.
  Future<void> setPitch(double value) async {
    final clamped = value.clamp(0.5, 2.0).toDouble();
    if (clamped == _pitch) return;
    _pitch = clamped;
    notifyListeners();
    await _preferences.setDouble(_pitchKey, clamped);
  }

  /// Updates the volume and persists the change. Clamped to
  /// `flutter_tts`'s valid `0.0`–`1.0` range.
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (clamped == _volume) return;
    _volume = clamped;
    notifyListeners();
    await _preferences.setDouble(_volumeKey, clamped);
  }

  /// Resets every value to its default and persists the change —
  /// offered in [NarrationSettingsSheet] since sliders with no visible
  /// numeric readout are easy to nudge without meaning to.
  Future<void> resetToDefaults() async {
    _enabled = true;
    _speechRate = defaultSpeechRate;
    _pitch = defaultPitch;
    _volume = defaultVolume;
    notifyListeners();
    await _preferences.setBool(_enabledKey, true);
    await _preferences.setDouble(_speechRateKey, defaultSpeechRate);
    await _preferences.setDouble(_pitchKey, defaultPitch);
    await _preferences.setDouble(_volumeKey, defaultVolume);
  }
}
