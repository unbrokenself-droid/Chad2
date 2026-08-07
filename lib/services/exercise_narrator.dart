import 'package:flutter/foundation.dart';

import '../models/exercise.dart';

/// Where an [ExerciseNarrator] currently stands.
enum NarrationStatus {
  /// Nothing is being read. Either nothing has played yet, playback
  /// finished the last segment naturally, or [ExerciseNarrator.stop]
  /// was called.
  stopped,

  /// Actively reading [ExerciseNarrator.currentSegmentIndex].
  playing,

  /// Reading was interrupted mid-way and can be continued from
  /// exactly where it left off via [ExerciseNarrator.resume].
  paused,
}

/// Reads an [Exercise]'s title and step-by-step instructions aloud,
/// one segment at a time — segment `0` is the title, and each
/// instruction step is its own following segment — with transport
/// controls on top: play, pause, resume, stop, skip forward, and
/// replay from the start.
///
/// This is an interface, not an implementation, and that split is
/// deliberate: [TtsExerciseNarrator] is the only implementation today
/// (on-device text-to-speech via `flutter_tts`), but the eventual plan
/// is bundled, professionally-recorded premium audio replacing TTS for
/// at least some exercises. Every screen and widget that narrates an
/// exercise — [ExerciseNarrationControls] included — depends on this
/// abstract type and [ExerciseNarratorScope], never on
/// [TtsExerciseNarrator] directly. Introducing that future
/// audio-file-backed implementation is then a matter of writing a new
/// class against this same contract and changing which one gets
/// constructed in `main.dart`; nothing in the UI layer would need to
/// change at all. (Rate/pitch/volume are deliberately *not* part of
/// this interface for the same reason: they're meaningful for
/// synthesized speech, but a fixed pre-recorded clip can't honor a
/// live pitch or rate change — see [NarrationSettingsService].)
abstract class ExerciseNarrator extends ChangeNotifier {
  /// Where playback currently stands.
  NarrationStatus get status;

  /// Index into the loaded exercise's segments — `0` is the title,
  /// `1` is the first instruction, and so on. Meaningless (but always
  /// `0`) before the first [loadExercise] call.
  int get currentSegmentIndex;

  /// Total segments for the currently loaded exercise: the title plus
  /// one per instruction step. `0` before the first [loadExercise]
  /// call.
  int get segmentCount;

  /// Loads [exercise]'s title and instructions as the segments future
  /// [play]/[replay] calls will read, replacing whatever exercise (if
  /// any) was loaded before.
  ///
  /// Always stops any in-progress narration first — including for a
  /// *different* exercise than the one already loaded — which is what
  /// gives the app its "starting another exercise's narration stops
  /// the previous one" behavior for free: every screen that narrates
  /// an exercise calls this on entry, so there's never a moment where
  /// two exercises' narration could overlap.
  Future<void> loadExercise(Exercise exercise);

  /// Starts reading from the very first segment (the title). No-op
  /// unless currently [NarrationStatus.stopped] — in particular, this
  /// deliberately does *not* restart a paused reading from the
  /// beginning; use [resume] to continue it or [replay] to restart it.
  Future<void> play();

  /// Stops speaking but remembers [currentSegmentIndex], so [resume]
  /// continues from the same segment rather than the beginning.
  /// No-op unless currently [NarrationStatus.playing].
  Future<void> pause();

  /// Continues from [currentSegmentIndex] — the segment that was
  /// playing when [pause] was called, restarted from its own
  /// beginning rather than the exact word [pause] interrupted it at.
  /// No-op unless currently [NarrationStatus.paused].
  Future<void> resume();

  /// Stops speaking entirely and resets [currentSegmentIndex] back to
  /// `0`, so a later [play] starts over from the title rather than
  /// continuing. No-op if already [NarrationStatus.stopped].
  Future<void> stop();

  /// Jumps to the next segment — e.g. from the title to the first
  /// instruction, or from one instruction to the next. If narration
  /// is currently playing, the new segment starts reading immediately;
  /// if paused, only [currentSegmentIndex] moves, and the next
  /// [resume] picks up from there. No-op if already on the last
  /// segment, or if nothing is loaded.
  Future<void> skipForward();

  /// Restarts from the very first segment (the title), regardless of
  /// [status] beforehand — including from [NarrationStatus.stopped],
  /// unlike [play] this doesn't require nothing to be currently
  /// playing.
  Future<void> replay();
}
