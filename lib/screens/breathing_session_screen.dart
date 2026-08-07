import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/breathing_pattern.dart';
import '../services/breathing_settings_scope.dart';
import '../utils/app_haptics.dart';
import '../widgets/breathing/breathing_orb.dart';
import '../widgets/shared/primary_button.dart';

/// The stage of a guided breathing session, in order.
enum _BreathingStage {
  /// Showing the pattern's description and guidance before starting.
  instructions,

  /// A brief "get ready" countdown before the breathing cycle starts.
  countdown,

  /// The breathing cycle is actively running (may be paused).
  running,

  /// The session ended, either by running out the clock or by the
  /// user ending it early.
  finished,
}

/// Full-screen guided breathing session for a single [BreathingPattern]
/// at a chosen [totalDuration].
///
/// Mirrors the shape of [GuidedSessionScreen] — instructions, a
/// countdown, a running stage with pause/end, and a finish screen —
/// but the running stage is entirely different: rather than a flat
/// countdown, it cycles through the pattern's phases
/// (inhale/hold/exhale/hold), driving a soft expanding-and-contracting
/// [BreathingOrb], an on-screen phase label, a cycle counter, and — if
/// enabled in [BreathingSettingsScope] — a short haptic pulse each
/// time the phase changes.
class BreathingSessionScreen extends StatefulWidget {
  const BreathingSessionScreen({
    super.key,
    required this.pattern,
    required this.totalDuration,
  });

  /// The breathing pattern being guided through.
  final BreathingPattern pattern;

  /// How long the overall session should run before automatically
  /// finishing. The pattern's phase cycle repeats for as many full
  /// and partial cycles as fit in this duration.
  final Duration totalDuration;

  @override
  State<BreathingSessionScreen> createState() =>
      _BreathingSessionScreenState();
}

class _BreathingSessionScreenState extends State<BreathingSessionScreen>
    with SingleTickerProviderStateMixin {
  static const _countdownSeconds = 3;

  _BreathingStage _stage = _BreathingStage.instructions;
  bool _paused = false;
  bool _endedEarly = false;

  int _countdownRemaining = _countdownSeconds;
  late Duration _remaining;

  int _phaseIndex = 0;
  int _completedCycles = 0;

  Timer? _ticker;

  /// Drives the orb's scale smoothly across the *current* phase's
  /// full duration, rather than snapping once per second — this is
  /// what makes the animation read as a continuous breath rather than
  /// a stepped countdown.
  late final AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _remaining = widget.totalDuration;
    _orbController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _orbController.dispose();
    super.dispose();
  }

  BreathingPhase get _currentPhase => widget.pattern.phases[_phaseIndex];

  double get _startScaleForCurrentPhase {
    final previousIndex =
        (_phaseIndex - 1 + widget.pattern.phases.length) %
            widget.pattern.phases.length;
    return widget.pattern.phases[previousIndex].type.targetScale;
  }

  // ---- Stage transitions ---------------------------------------------

  void _beginCountdown() {
    AppHaptics.medium();
    setState(() {
      _stage = _BreathingStage.countdown;
      _countdownRemaining = _countdownSeconds;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _countdownRemaining--);
      if (_countdownRemaining <= 0) {
        timer.cancel();
        _beginRunning();
      } else {
        AppHaptics.light();
      }
    });
  }

  void _beginRunning() {
    setState(() {
      _stage = _BreathingStage.running;
      _paused = false;
      _phaseIndex = 0;
      _completedCycles = 0;
    });
    _playPhaseHaptic(_currentPhase.type);
    _runPhaseAnimation();
    _startCountdownTicker();
  }

  /// Drives [_orbController] from the previous phase's resting scale
  /// to this phase's target scale over exactly this phase's duration
  /// (or holds it still, for the hold phases), so the orb's motion
  /// always stays perfectly in sync with the phase timer regardless
  /// of how long each phase lasts.
  void _runPhaseAnimation() {
    final phase = _currentPhase;
    _orbController.stop();
    _orbController.duration = Duration(seconds: phase.seconds);
    if (!phase.type.isMoving) {
      // Hold phases: snap to (and stay at) the target scale, no
      // animation needed.
      _orbController.value = 1.0;
      return;
    }
    _orbController.value = 0.0;
    _orbController.forward();
  }

  void _startCountdownTicker() {
    _ticker?.cancel();
    var phaseSecondsRemaining = _currentPhase.seconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_paused) return;
      final nextTotal = _remaining - const Duration(seconds: 1);
      phaseSecondsRemaining--;

      if (nextTotal <= Duration.zero) {
        timer.cancel();
        setState(() => _remaining = Duration.zero);
        _finish(endedEarly: false);
        return;
      }

      if (phaseSecondsRemaining <= 0) {
        final nextIndex = _phaseIndex + 1;
        final wrapped = nextIndex >= widget.pattern.phases.length;
        setState(() {
          _remaining = nextTotal;
          _phaseIndex = wrapped ? 0 : nextIndex;
          if (wrapped) _completedCycles++;
        });
        phaseSecondsRemaining = _currentPhase.seconds;
        _playPhaseHaptic(_currentPhase.type);
        _runPhaseAnimation();
      } else {
        setState(() => _remaining = nextTotal);
      }
    });
  }

  void _playPhaseHaptic(BreathingPhaseType type) {
    if (!BreathingSettingsScope.of(context).vibrationEnabled) return;
    switch (type) {
      case BreathingPhaseType.inhale:
        HapticFeedback.lightImpact();
      case BreathingPhaseType.exhale:
        HapticFeedback.mediumImpact();
      case BreathingPhaseType.holdFull:
      case BreathingPhaseType.holdEmpty:
        HapticFeedback.selectionClick();
    }
  }

  void _togglePause() {
    AppHaptics.selection();
    setState(() => _paused = !_paused);
    if (_paused) {
      _orbController.stop();
    } else {
      // Resume the orb animation from wherever it left off, over
      // however much of the current phase remains — avoids a jump
      // cut in the middle of an inhale/exhale.
      final remainingInPhase = _secondsRemainingInCurrentPhase();
      if (_currentPhase.type.isMoving && remainingInPhase > 0) {
        _orbController.duration = Duration(seconds: remainingInPhase);
        _orbController.forward(from: _orbController.value);
      }
    }
  }

  int _secondsRemainingInCurrentPhase() {
    final elapsedInPhase =
        (_orbController.value * _currentPhase.seconds).round();
    return (_currentPhase.seconds - elapsedInPhase).clamp(
      0,
      _currentPhase.seconds,
    );
  }

  void _endEarly() {
    AppHaptics.medium();
    _ticker?.cancel();
    _finish(endedEarly: true);
  }

  void _finish({required bool endedEarly}) {
    _ticker?.cancel();
    _orbController.stop();
    AppHaptics.heavy();
    setState(() {
      _stage = _BreathingStage.finished;
      _endedEarly = endedEarly;
    });
  }

  // ---- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage == _BreathingStage.instructions ||
          _stage == _BreathingStage.finished,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.pattern.title),
          leading:
              _stage == _BreathingStage.running ||
                  _stage == _BreathingStage.countdown
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'End session',
                  onPressed: () => _confirmExit(context),
                )
              : null,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.03),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_stage),
              child: switch (_stage) {
                _BreathingStage.instructions => _InstructionsView(
                    key: const ValueKey('instructions'),
                    pattern: widget.pattern,
                    totalDuration: widget.totalDuration,
                    onStart: _beginCountdown,
                  ),
                _BreathingStage.countdown => _CountdownView(
                    key: const ValueKey('countdown'),
                    remaining: _countdownRemaining,
                    color: widget.pattern.color,
                  ),
                _BreathingStage.running => _RunningView(
                    key: const ValueKey('running'),
                    pattern: widget.pattern,
                    remaining: _remaining,
                    paused: _paused,
                    phase: _currentPhase,
                    completedCycles: _completedCycles,
                    orbController: _orbController,
                    startScale: _startScaleForCurrentPhase,
                    onTogglePause: _togglePause,
                    onEnd: _endEarly,
                  ),
                _BreathingStage.finished => _FinishedView(
                    key: const ValueKey('finished'),
                    pattern: widget.pattern,
                    endedEarly: _endedEarly,
                    completedCycles: _completedCycles,
                    onDone: () => Navigator.of(context).pop(),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final wasPaused = _paused;
    setState(() => _paused = true);
    _orbController.stop();
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
          "You'll still see how many cycles you completed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End session'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (shouldExit == true) {
      _endEarly();
    } else {
      setState(() => _paused = wasPaused);
      if (!wasPaused) {
        final remainingInPhase = _secondsRemainingInCurrentPhase();
        if (_currentPhase.type.isMoving && remainingInPhase > 0) {
          _orbController.duration = Duration(seconds: remainingInPhase);
          _orbController.forward(from: _orbController.value);
        }
      }
    }
  }
}

// ---- Instructions stage -----------------------------------------------

class _InstructionsView extends StatelessWidget {
  const _InstructionsView({
    super.key,
    required this.pattern,
    required this.totalDuration,
    required this.onStart,
  });

  final BreathingPattern pattern;
  final Duration totalDuration;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final minutes = totalDuration.inMinutes;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: pattern.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(pattern.icon, size: 46, color: pattern.color),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              pattern.tagline,
              style: theme.textTheme.titleMedium?.copyWith(
                color: pattern.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pattern.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                '$minutes minute${minutes == 1 ? '' : 's'} session',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (pattern.guidance.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Before you start',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final tip in pattern.guidance)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Begin',
            icon: Icons.play_arrow_rounded,
            backgroundColor: pattern.color,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

// ---- Countdown stage ----------------------------------------------------

class _CountdownView extends StatelessWidget {
  const _CountdownView({super.key, required this.remaining, required this.color});

  final int remaining;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Get ready',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            key: ValueKey(remaining),
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Text(
              remaining > 0 ? '$remaining' : '',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Running stage --------------------------------------------------------

class _RunningView extends StatelessWidget {
  const _RunningView({
    super.key,
    required this.pattern,
    required this.remaining,
    required this.paused,
    required this.phase,
    required this.completedCycles,
    required this.orbController,
    required this.startScale,
    required this.onTogglePause,
    required this.onEnd,
  });

  final BreathingPattern pattern;
  final Duration remaining;
  final bool paused;
  final BreathingPhase phase;
  final int completedCycles;
  final AnimationController orbController;
  final double startScale;
  final VoidCallback onTogglePause;
  final VoidCallback onEnd;

  String _formatClock(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cycle ${completedCycles + 1}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Semantics(
                label:
                    '${remaining.inMinutes} minutes ${remaining.inSeconds % 60} seconds remaining',
                excludeSemantics: true,
                child: Text(
                  _formatClock(remaining),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: RepaintBoundary(
              child: BreathingOrb(
                controller: orbController,
                startScale: startScale,
                endScale: phase.type.targetScale,
                paused: paused,
                color: pattern.color,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    paused ? 'Paused' : phase.type.label,
                    key: ValueKey('${phase.type}-$paused'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEnd,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('End'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: PrimaryButton(
                    label: paused ? 'Resume' : 'Pause',
                    icon: paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    backgroundColor: pattern.color,
                    onPressed: onTogglePause,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---- Finished stage -------------------------------------------------------

class _FinishedView extends StatelessWidget {
  const _FinishedView({
    super.key,
    required this.pattern,
    required this.endedEarly,
    required this.completedCycles,
    required this.onDone,
  });

  final BreathingPattern pattern;
  final bool endedEarly;
  final int completedCycles;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: pattern.color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 52,
                      color: pattern.color,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  endedEarly ? 'Session ended' : 'Well breathed',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  completedCycles == 0
                      ? 'You completed part of a breathing cycle.'
                      : 'You completed $completedCycles breathing '
                            '${completedCycles == 1 ? 'cycle' : 'cycles'} of '
                            '${pattern.title}.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: 'Done',
              icon: Icons.arrow_forward_rounded,
              backgroundColor: pattern.color,
              onPressed: onDone,
            ),
          ),
        ),
      ],
    );
  }
}
