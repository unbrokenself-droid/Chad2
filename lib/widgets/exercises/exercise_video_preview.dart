import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A looping, muted preview of an [Exercise]'s filmed demonstration
/// clip, shown on [ExerciseDetailsScreen] for exercises that have a
/// [Exercise.videoAsset], and reused (with [paused] wired to the
/// session's own pause state) as the exercise view's video during a
/// [WorkoutSessionManager]-driven routine session.
///
/// This is deliberately unrelated to [ExerciseDemonstrationView] —
/// that widget's abstract animated shape stays exactly as-is for
/// [GuidedSessionScreen]'s in-session pacing visual; this widget
/// started out scoped only to the pre-session details screen, giving
/// a richer "watch how it's done" preview there without touching the
/// more delicate, ticker-driven single-exercise session screen at
/// all — [paused] is the one addition needed to reuse it for a
/// routine session's own exercise view instead of duplicating a
/// second video-playing widget for it.
///
/// Every bundled clip is a few seconds long, has no audio track, and
/// is meant to loop continuously like a GIF rather than be watched
/// once with transport controls — so this plays automatically, loops
/// forever, and deliberately has no play/pause/scrub UI of its own
/// beyond [paused]. [MediaQuery.disableAnimations] (reduce motion)
/// freezes on the first frame instead of looping, the same
/// accommodation [ExerciseDemonstrationView] makes for the same
/// setting; being paused (either way) takes priority over that, since
/// a still frame is the correct state either way.
class ExerciseVideoPreview extends StatefulWidget {
  const ExerciseVideoPreview({
    super.key,
    required this.assetPath,
    this.paused = false,
  });

  /// Bundled asset path, e.g. `'assets/videos/jaw-release-drop.mp4'`
  /// — see [Exercise.videoAsset].
  final String assetPath;

  /// Freezes playback on the current frame when `true`. Defaults to
  /// `false` for [ExerciseDetailsScreen]'s always-looping preview;
  /// [WorkoutExerciseView] passes the session's own pause state
  /// through here so the video visibly pauses alongside the timer and
  /// narration rather than continuing to loop underneath a paused
  /// session.
  final bool paused;

  @override
  State<ExerciseVideoPreview> createState() => _ExerciseVideoPreviewState();
}

class _ExerciseVideoPreviewState extends State<ExerciseVideoPreview> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath);
    _initialization = _controller.initialize().then((_) async {
      if (!mounted) return;
      // None of the bundled clips have an audio track, but muting
      // explicitly rather than relying on that keeps this correct
      // even if a future clip does have one — these are meant to
      // read as a looping visual, not something that competes with
      // whatever audio (music, a screen reader) the user has going.
      await _controller.setVolume(0);
      await _applyRunningState();
      if (!mounted) return;
      // The first frame — and the clip's real aspect ratio — only
      // become available once initialized; rebuild so the
      // AspectRatio below picks it up instead of the placeholder.
      setState(() {});
    });
  }

  /// Applies whatever the desired running state actually is *right
  /// now* — always reads [widget.paused]/[MediaQuery] fresh rather
  /// than anything captured earlier, and is safe to call before
  /// [_controller] has finished initializing (a no-op in that case).
  /// That makes it safe to call unconditionally from
  /// [didChangeDependencies]/[didUpdateWidget] without either of them
  /// needing their own `isInitialized` guard — see this method's own
  /// guard below instead, which is now the single place that decides
  /// whether there's anything to actually do yet.
  ///
  /// Also verifies playback actually started after calling `play()`
  /// and retries once, after a brief delay, if it didn't — a
  /// defensive measure against the native player silently failing to
  /// advance past its first frame despite `play()` having been
  /// called. In practice this has shown up specifically when TTS
  /// narration starts at the same moment as a new exercise's video —
  /// both compete for native platform-channel/audio-video resources
  /// right as this widget is constructed, and on some devices/timing
  /// the video decoder seemingly loses that race silently rather than
  /// erroring. This retry doesn't depend on knowing that's the exact
  /// cause to still fix the symptom: `play()` was called, playback
  /// didn't actually start, so call it again.
  Future<void> _applyRunningState() async {
    if (!_controller.value.isInitialized) return;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    await _controller.setLooping(!reduceMotion);
    if (widget.paused || reduceMotion) {
      await _controller.pause();
      // Only reduce-motion should freeze back to the very first
      // frame; an explicit pause should hold on whatever frame was
      // already showing, the same way a paused video normally would.
      if (reduceMotion && !widget.paused) await _controller.seekTo(Duration.zero);
      return;
    }
    await _controller.play();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // Re-check both mounted state and the *current* desired state —
    // widget.paused may have already changed again during that delay,
    // in which case this retry would fight whatever handled that
    // change instead of reinforcing it.
    if (!mounted || widget.paused) return;
    if (!_controller.value.isPlaying) {
      await _controller.play();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery (reduce motion) can change while this is already
    // mounted; re-evaluate rather than only checking once in
    // initState.
    unawaited(_applyRunningState());
  }

  @override
  void didUpdateWidget(covariant ExerciseVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Note: a changing assetPath is deliberately *not* handled here —
    // every call site gives this widget a key derived from the
    // exercise id, so a different exercise means a whole new element
    // (fresh initState) rather than an update to this one. Only
    // paused toggling needs handling on an already-mounted instance.
    if (widget.paused != oldWidget.paused) {
      unawaited(_applyRunningState());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        // Falls back to a plausible default before initialize()
        // resolves and reports the clip's real aspect ratio — every
        // bundled clip is close enough to 3:2 that this doesn't
        // produce a visible resize once the real value comes in.
        aspectRatio: _controller.value.isInitialized
            ? _controller.value.aspectRatio
            : 3 / 2,
        child: ColoredBox(
          color: colorScheme.surfaceContainerHighest,
          child: FutureBuilder<void>(
            future: _initialization,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // A missing or corrupt asset shouldn't take the whole
                // details screen down with it — just quietly show
                // nothing where the preview would have been rather
                // than a broken player.
                return const SizedBox.shrink();
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              }
              return ExcludeSemantics(
                // Purely decorative and silent — the same instructions
                // are already available as accessible text below, so
                // a screen reader gains nothing from this beyond noise.
                child: VideoPlayer(_controller),
              );
            },
          ),
        ),
      ),
    );
  }
}
