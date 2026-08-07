import 'dart:async';

import 'package:flutter/material.dart';

import '../models/exercise.dart';
import '../widgets/coach/coach_avatar.dart';

/// Full-screen "the coach is working on this" takeover, shown for
/// [_minimumDuration] while [generate] actually builds a routine in
/// the background — used identically by [OnboardingFlowScreen] (after
/// the questionnaire, before the first routine ever exists) and
/// [RoutineScreen] (whenever the difficulty picker confirms a new
/// level), so the "the coach is rebuilding your workout" feeling is
/// the same moment both times, not two different implementations
/// that happen to look similar.
///
/// **Real work, not a fake wait.** [generate] is the actual
/// [DailyRoutineService.ensureTodayRoutine]/
/// [DailyRoutineService.setDifficulty] call — this screen doesn't
/// simulate anything. What it *does* add on top is a floor: if
/// [generate] finishes faster than [_minimumDuration] (likely, since
/// it's all local computation), this waits out the rest of that floor
/// before dismissing, so the experience doesn't flash by in a
/// fraction of a second. The rotating subtitles and progress bar
/// below are deliberately not tied to how much of that floor has
/// elapsed — there's no fake percentage to compute, just an
/// indeterminate [LinearProgressIndicator] (no `value` set) and a
/// message that changes on its own timer.
///
/// Pops itself automatically once both are done, returning
/// [generate]'s result as the pop value — `canPop` is `false` the
/// entire time, since this is a brief, self-dismissing transition,
/// not a screen the user is meant to back out of early.
class CoachGenerationScreen extends StatefulWidget {
  const CoachGenerationScreen({
    super.key,
    required this.generate,
    this.title = "Coach is designing your routine",
    this.imageAsset,
  });

  /// The real routine-building work this screen waits on — typically
  /// a closure around [DailyRoutineService.ensureTodayRoutine] or
  /// [DailyRoutineService.setDifficulty].
  final Future<List<Exercise>> Function() generate;

  final String title;

  /// Passed straight through to [CoachAvatar.imageAsset] — see that
  /// field's doc comment. [OnboardingFlowScreen] and [RoutineScreen]'s
  /// difficulty change each pass their own.
  final String? imageAsset;

  @override
  State<CoachGenerationScreen> createState() => _CoachGenerationScreenState();
}

class _CoachGenerationScreenState extends State<CoachGenerationScreen> {
  static const List<String> _messages = [
    'Analyzing your goals...',
    'Understanding your habits...',
    'Selecting the best exercises...',
    "Building today's routine...",
    'Personalizing your wellness journey...',
    'Optimizing recovery...',
    'Almost ready...',
  ];

  /// How long this screen stays up at minimum, regardless of how
  /// quickly [CoachGenerationScreen.generate] actually finishes — see
  /// the class doc comment's "Real work, not a fake wait" section.
  static const Duration _minimumDuration = Duration(milliseconds: 3600);

  static const Duration _messageInterval = Duration(milliseconds: 900);

  int _messageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _messageTimer = Timer.periodic(_messageInterval, (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
    unawaited(_run());
  }

  Future<void> _run() async {
    final stopwatch = Stopwatch()..start();
    final generated = await widget.generate();
    final remaining = _minimumDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;
    Navigator.of(context).pop(generated);
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      // This screen dismisses itself the moment its work is done;
      // there's nothing sensible for a manual back gesture to do in
      // the meantime, so it's simply not allowed rather than leaving
      // generate() running against a screen that's already gone.
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Stack(
          alignment: Alignment.center,
          children: [
            _AmbientGlow(color: colorScheme.primary),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CoachAvatar(size: 120, pulse: true, imageAsset: widget.imageAsset),
                      const SizedBox(height: 32),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 44,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _messages[_messageIndex],
                            key: ValueKey(_messageIndex),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          width: 160,
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              colorScheme.primary,
                            ),
                            // No `value` set, deliberately: an
                            // indeterminate, looping bar rather than a
                            // fake percentage — see this class's doc
                            // comment.
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A large, softly blurred circle behind [CoachAvatar] that slowly
/// brightens and dims — the "soft ambient background" /
/// "breathing animation" behind the coach while it works, distinct
/// from [CoachAvatar]'s own faster pulse (the two run on different
/// periods so they read as layered rather than perfectly in sync).
class _AmbientGlow extends StatefulWidget {
  const _AmbientGlow({required this.color});

  final Color color;

  @override
  State<_AmbientGlow> createState() => _AmbientGlowState();
}

class _AmbientGlowState extends State<_AmbientGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // See AmbientBackground's identical didChangeDependencies (Home
    // screen) for why this lives here rather than the field
    // initializer above — the same fix, for the same latent bug,
    // applied here too even though this specific screen isn't what
    // widget_test.dart's failure traced back to (CoachGenerationScreen
    // is only ever reached by explicit navigation, not the bottom
    // tabs that test exercises) — leaving an identical unconditional
    // `..repeat()` in place here would just be the same landmine
    // waiting for the next test that does reach this screen.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return _buildGlow(0.6);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _buildGlow(0.4 + _controller.value * 0.3),
    );
  }

  Widget _buildGlow(double intensity) {
    return IgnorePointer(
      child: Container(
        width: 360,
        height: 360,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.color.withValues(alpha: intensity * 0.22),
              widget.color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
