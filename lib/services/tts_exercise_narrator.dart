import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../models/exercise.dart';
import 'exercise_narrator.dart';
import 'narration_settings_service.dart';

/// Reads an exercise's title and instructions aloud using on-device
/// text-to-speech, via the `flutter_tts` package.
///
/// **Segments, not one long utterance.** [Exercise.title] is segment
/// `0`, and each [Exercise.instructions] entry is its own following
/// segment, spoken one [FlutterTts.speak] call at a time rather than
/// as a single joined block of text. This is what [skipForward] jumps
/// between, and it's also how [pause]/[resume] are implemented: this
/// class does not rely on `flutter_tts`'s own pause/resume support,
/// which is inconsistent across platforms (notably, Android's system
/// TTS engine has no true pause — only stop). Instead, [pause] simply
/// stops the underlying engine mid-segment and remembers which
/// segment [currentSegmentIndex] was on; [resume] re-speaks that same
/// segment from *its own* beginning. That's a small UX compromise
/// (resuming mid-sentence isn't possible), traded for behavior that's
/// actually consistent across iOS and Android, rather than a "resume"
/// button that silently doesn't work on half of a user's devices.
///
/// **How "was that a natural finish, or an interruption?" is
/// resolved.** [FlutterTts.awaitSpeakCompletion] is enabled once,
/// lazily, before the first [FlutterTts.speak] call, which makes
/// `speak()`'s returned `Future` resolve only once that utterance
/// actually finishes (naturally *or* via `stop()`) rather than the
/// instant it starts. [_speakCurrentSegment] awaits that future, then
/// checks whether [status] and [currentSegmentIndex] are still what
/// they were right before the `await` — if either changed underneath
/// it (because [pause]/[stop]/[skipForward]/[loadExercise] ran while
/// speech was in flight), something else already took care of
/// updating state and this call quietly stops here; otherwise, the
/// segment finished on its own and playback automatically continues
/// to the next one. Every mutating method here also updates [status]
/// and [currentSegmentIndex] to their *final* value **before**
/// awaiting the corresponding `flutter_tts` call, specifically so that
/// resolution order between two overlapping calls (e.g. a pending
/// `_speakCurrentSegment` and a `stop()` that just interrupted it)
/// can never leave state briefly wrong no matter which finishes first.
///
/// **Settings are only re-applied when they've changed.**
/// [_speakCurrentSegment] runs once per segment (title, then each
/// instruction line) — speech rate/pitch/volume don't change between
/// those, so re-issuing all three `flutter_tts` platform-channel calls
/// before every single segment was pure overhead, and specifically the
/// kind of overhead that mattered: it was extra native platform-
/// channel work landing in the same moment a new exercise's video was
/// also trying to initialize, one contributor to the contention
/// [ExerciseVideoPreview]'s own doc comment describes.
class TtsExerciseNarrator extends ExerciseNarrator {
  TtsExerciseNarrator({required NarrationSettingsService settings, FlutterTts? tts})
      : _settings = settings,
        _tts = tts ?? FlutterTts() {
    _tts.setErrorHandler((message) {
      _status = NarrationStatus.stopped;
      _currentSegmentIndex = 0;
      notifyListeners();
    });
  }

  final NarrationSettingsService _settings;
  final FlutterTts _tts;
  bool _configured = false;
  bool _disposed = false;

  List<String> _segments = const [];
  NarrationStatus _status = NarrationStatus.stopped;
  int _currentSegmentIndex = 0;

  /// The speech rate/pitch/volume actually applied to [_tts] as of the
  /// last [_speakCurrentSegment] call — `null` before the first one.
  /// Compared against [_settings]' current values each time so a
  /// segment only re-applies whichever of the three actually changed,
  /// rather than issuing all three platform-channel calls before
  /// every single segment regardless of whether anything's different
  /// from the last one. Those calls were previously the biggest
  /// contributor to how much native platform-channel work landed in
  /// the same moment a new exercise's video was also trying to
  /// initialize — see [ExerciseVideoPreview]'s own doc comment for the
  /// contention that was showing up as.
  double? _appliedSpeechRate;
  double? _appliedPitch;
  double? _appliedVolume;

  @override
  NarrationStatus get status => _status;

  @override
  int get currentSegmentIndex => _currentSegmentIndex;

  @override
  int get segmentCount => _segments.length;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    _configured = true;
    // See class doc comment: this is what lets _speakCurrentSegment
    // use a plain `await` as its "this segment is done" signal
    // instead of juggling completion/cancel callbacks by hand.
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<void> loadExercise(Exercise exercise) async {
    await stop();
    _segments = [exercise.title, ...exercise.instructions];
    _currentSegmentIndex = 0;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    if (_segments.isEmpty || _status != NarrationStatus.stopped) return;
    await _speakCurrentSegment();
  }

  @override
  Future<void> pause() async {
    if (_status != NarrationStatus.playing) return;
    _status = NarrationStatus.paused;
    notifyListeners();
    await _tts.stop();
  }

  @override
  Future<void> resume() async {
    if (_status != NarrationStatus.paused) return;
    await _speakCurrentSegment();
  }

  @override
  Future<void> stop() async {
    if (_status == NarrationStatus.stopped) return;
    _status = NarrationStatus.stopped;
    _currentSegmentIndex = 0;
    notifyListeners();
    await _tts.stop();
  }

  @override
  Future<void> skipForward() async {
    if (_segments.isEmpty) return;
    if (_currentSegmentIndex >= _segments.length - 1) return;
    if (_status == NarrationStatus.stopped) return;

    final wasPlaying = _status == NarrationStatus.playing;
    _currentSegmentIndex++;
    notifyListeners();
    if (wasPlaying) {
      await _tts.stop();
      await _speakCurrentSegment();
    }
    // If paused, only the pointer moves — the next resume() picks up
    // the new segment from its own beginning.
  }

  @override
  Future<void> replay() async {
    if (_segments.isEmpty) return;
    await _tts.stop();
    _currentSegmentIndex = 0;
    await _speakCurrentSegment();
  }

  Future<void> _speakCurrentSegment() async {
    await _ensureConfigured();
    if (_settings.speechRate != _appliedSpeechRate) {
      await _tts.setSpeechRate(_settings.speechRate);
      _appliedSpeechRate = _settings.speechRate;
    }
    if (_settings.pitch != _appliedPitch) {
      await _tts.setPitch(_settings.pitch);
      _appliedPitch = _settings.pitch;
    }
    if (_settings.volume != _appliedVolume) {
      await _tts.setVolume(_settings.volume);
      _appliedVolume = _settings.volume;
    }
    if (_disposed) return;

    _status = NarrationStatus.playing;
    notifyListeners();

    final segmentWhenStarted = _currentSegmentIndex;
    await _tts.speak(_segments[segmentWhenStarted]);
    if (_disposed) return;

    // Nothing else changed state while the line above was in flight —
    // this segment ran to completion on its own, so advance
    // automatically. If status or the index differ, pause/stop/
    // skipForward/loadExercise already took care of things and this
    // call has nothing left to do.
    final finishedNaturally =
        _status == NarrationStatus.playing &&
        _currentSegmentIndex == segmentWhenStarted;
    if (!finishedNaturally) return;

    if (_currentSegmentIndex >= _segments.length - 1) {
      _status = NarrationStatus.stopped;
      _currentSegmentIndex = 0;
      notifyListeners();
      return;
    }
    _currentSegmentIndex++;
    await _speakCurrentSegment();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_tts.stop());
    super.dispose();
  }
}
