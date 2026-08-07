import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/music_track.dart';

/// Plays a looping background-music track during a workout session —
/// see [WorkoutSessionManager], which starts/pauses/resumes/stops
/// this alongside the session's timer and [TtsExerciseNarrator]
/// speech, the same way it already coordinates those two.
///
/// Persists whether background music is enabled at all, the volume,
/// and which track is selected — all via [SharedPreferences] — so a
/// choice made once carries over to the next workout instead of
/// needing to be re-picked every time.
///
/// One [AudioPlayer] instance for the app's lifetime (constructed
/// once in `main.dart`, like the app's other services), not one per
/// session — a workout session just calls [play]/[pause]/[resume]/
/// [stop] on this same shared instance, unlike
/// [WorkoutSessionManager] itself, which *is* recreated per session.
///
/// A separate platform audio session from [TtsExerciseNarrator]'s
/// (`audioplayers` vs. `flutter_tts`), so the two mix together rather
/// than one interrupting the other — spoken instructions play over
/// the music, not instead of it.
class BackgroundMusicService extends ChangeNotifier {
  BackgroundMusicService({
    SharedPreferencesAsync? preferences,
    AudioPlayer? player,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _player = player ?? AudioPlayer() {
    // Set once, up front: every bundled track is under a minute and
    // meant to loop for as long as a session runs, not play once and
    // stop partway through a workout.
    unawaited(_player.setReleaseMode(ReleaseMode.loop));
  }

  static const String _enabledKey = 'background_music_enabled';
  static const String _volumeKey = 'background_music_volume';
  static const String _trackIdKey = 'background_music_track_id';

  /// A moderate default — present, but well under the spoken
  /// instructions in the mix.
  static const double defaultVolume = 0.5;

  final SharedPreferencesAsync _preferences;
  final AudioPlayer _player;

  bool _enabled = true;
  double _volume = defaultVolume;
  MusicTrack _currentTrack = bundledMusicTracks.first;
  bool _isPlaying = false;
  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// Whether background music should play during a session at all —
  /// the "Background Music" toggle in [MusicVoiceSheet].
  bool get enabled => _enabled;

  /// Playback volume, `0.0`–`1.0`.
  double get volume => _volume;

  /// The track that plays (or would play, if [enabled] and a session
  /// is active) next.
  MusicTrack get currentTrack => _currentTrack;

  /// Whether audio is actually sounding right now.
  bool get isPlaying => _isPlaying;

  /// Loads every persisted preference from disk. Safe to call more
  /// than once; subsequent calls just re-sync from storage.
  Future<void> load() async {
    final storedEnabled = await _preferences.getBool(_enabledKey);
    final storedVolume = await _preferences.getDouble(_volumeKey);
    final storedTrackId = await _preferences.getString(_trackIdKey);

    _enabled = storedEnabled ?? true;
    _volume = (storedVolume ?? defaultVolume).clamp(0.0, 1.0).toDouble();
    _currentTrack = bundledMusicTracks.firstWhere(
      (track) => track.id == storedTrackId,
      orElse: () => bundledMusicTracks.first,
    );

    await _player.setVolume(_volume);
    _loaded = true;
    notifyListeners();
  }

  /// Enables or disables background music and persists the change.
  /// Disabling while playing pauses immediately, so unchecking the
  /// toggle mid-session takes effect right away rather than only on
  /// the next session.
  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    await _preferences.setBool(_enabledKey, value);
    if (!value) await pause();
  }

  /// Updates the volume and persists the change. Clamped to `0.0`–
  /// `1.0` so a slider rounding error can't send it out of range.
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (clamped == _volume) return;
    _volume = clamped;
    notifyListeners();
    await _preferences.setDouble(_volumeKey, clamped);
    await _player.setVolume(clamped);
  }

  /// Switches [currentTrack] to [track] and persists the choice. If
  /// music is currently playing, the new track starts immediately in
  /// the old one's place; if paused or stopped, the switch is silent
  /// and [play] picks up [track] whenever it's next called.
  Future<void> selectTrack(MusicTrack track) async {
    if (track.id == _currentTrack.id) return;
    _currentTrack = track;
    notifyListeners();
    await _preferences.setString(_trackIdKey, track.id);
    if (_isPlaying) await play();
  }

  /// Switches to the track after [currentTrack] in [bundledMusicTracks],
  /// wrapping back to the first after the last.
  Future<void> skipNext() async {
    final index = bundledMusicTracks.indexWhere(
      (track) => track.id == _currentTrack.id,
    );
    final nextIndex = (index + 1) % bundledMusicTracks.length;
    await selectTrack(bundledMusicTracks[nextIndex]);
  }

  /// Switches to the track before [currentTrack] in
  /// [bundledMusicTracks], wrapping back to the last after the first.
  Future<void> skipPrevious() async {
    final index = bundledMusicTracks.indexWhere(
      (track) => track.id == _currentTrack.id,
    );
    // Dart's % can return a negative result when the left operand is
    // negative (index 0 - 1 = -1, and -1 % length is still negative,
    // unlike in some other languages) — the second % normalizes that
    // back into 0..length-1.
    final previousIndex =
        (index - 1 + bundledMusicTracks.length) % bundledMusicTracks.length;
    await selectTrack(bundledMusicTracks[previousIndex]);
  }

  /// Starts (or restarts) [currentTrack] from the beginning, looping
  /// continuously until [pause] or [stop]. No-op if [enabled] is
  /// `false` — callers don't need their own enabled check before
  /// calling this; [WorkoutSessionManager] calls it unconditionally
  /// every time a session starts, the same way it does for
  /// [TtsExerciseNarrator.play].
  ///
  /// Failures (a missing/corrupt asset, no audio output device, the
  /// platform player rejecting the source) are caught rather than
  /// left to propagate — [isPlaying] simply stays `false`, the same
  /// outward result as [enabled] being off, rather than an exception
  /// surfacing from deep inside `audioplayers` into
  /// [WorkoutSessionManager]'s `unawaited` call and becoming an
  /// unhandled async error there. Music not sounding is a real but
  /// minor degradation of a session; it should never be able to take
  /// the timer, video, or narration down with it.
  Future<void> play() async {
    if (!_enabled) return;
    // Set before the await, not after — a concurrent pause() call
    // needs to see _isPlaying as true immediately, not only once this
    // method's own platform-channel call happens to resolve. Setting
    // it afterward (even correctly, on success) would open exactly
    // the pause-during-an-async-start race this class is deliberately
    // safe from, unlike TtsExerciseNarrator's equivalent — see
    // WorkoutSessionManager's own _loadAndPlayNarration for the
    // narrator-side version of this same race and why it needed a
    // different fix.
    _isPlaying = true;
    notifyListeners();
    try {
      await _player.play(AssetSource(_assetSourcePath(_currentTrack)));
    } catch (_) {
      // Only walk _isPlaying back if nothing else already has —
      // a concurrent pause() may have already set it false for a
      // real reason, which this failure shouldn't overwrite back to
      // some other value.
      if (_isPlaying) {
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  /// Pauses playback in place. No-op if not currently playing.
  Future<void> pause() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
    try {
      await _player.pause();
    } catch (_) {
      // Already reflected as not-playing above regardless of outcome.
    }
  }

  /// Resumes exactly where [pause] left off. No-op if [enabled] is
  /// `false` or already playing.
  Future<void> resume() async {
    if (!_enabled || _isPlaying) return;
    // Same reasoning as play(): set before the await, not after.
    _isPlaying = true;
    notifyListeners();
    try {
      await _player.resume();
    } catch (_) {
      if (_isPlaying) {
        _isPlaying = false;
        notifyListeners();
      }
    }
  }

  /// Stops playback entirely. Safe to call from any state (already
  /// stopped, paused, or playing) — always leaves the underlying
  /// player fully stopped rather than merely paused, which is what
  /// lets [WorkoutSessionManager] call this unconditionally on exit
  /// without needing to know what state playback was already in.
  Future<void> stop() async {
    _isPlaying = false;
    notifyListeners();
    try {
      await _player.stop();
    } catch (_) {
      // isPlaying is already false either way — nothing further this
      // service can do if the platform player itself is in a bad
      // state, and nothing a session's other systems should have to
      // know or care about.
    }
  }

  /// `audioplayers`' [AssetSource] expects a path relative to the
  /// `assets/` folder itself, unlike every other asset-referencing
  /// API this app uses ([Exercise.videoAsset],
  /// [ExerciseVideoPreview]'s `VideoPlayerController.asset`,
  /// `Image.asset`) — all of which take the full pubspec-declared
  /// path including the `assets/` prefix. [MusicTrack.assetPath]
  /// stays in that same full-path convention for consistency with
  /// the rest of the app; this is the one place that strips the
  /// prefix back off, for the one API that needs it stripped.
  static String _assetSourcePath(MusicTrack track) {
    return track.assetPath.replaceFirst('assets/', '');
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
