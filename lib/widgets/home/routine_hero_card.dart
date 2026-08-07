import 'package:flutter/material.dart';

import '../../services/daily_routine_service.dart';

/// The large hero call-to-action for today's routine — the primary
/// thing [HomeScreen] wants the user to do, styled and sized to match
/// that role rather than reading as one dashboard tile among several.
///
/// Branches internally between three states, in priority order:
/// [isRestDay] first (nothing to start today regardless of anything
/// else), then [sessionSummary] non-null (today's routine already
/// finished — see [DailyRoutineService.todaySessionSummary]), and
/// otherwise the default "here's what's coming up, start it" state.
/// [onAction] is the one callback for all three — [HomeScreen] passes
/// the exact same "switch to the Routine tab" navigation this card
/// used before its visual redesign; this widget doesn't add any new
/// destination or behavior, only new presentation around the same
/// action.
class RoutineHeroCard extends StatelessWidget {
  const RoutineHeroCard({
    super.key,
    required this.isRestDay,
    required this.sessionSummary,
    required this.totalExercises,
    required this.completedToday,
    required this.totalDuration,
    required this.difficultyLabel,
    required this.onAction,
  });

  final bool isRestDay;
  final RoutineSessionSummary? sessionSummary;
  final int totalExercises;
  final int completedToday;
  final Duration totalDuration;
  final String difficultyLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    if (isRestDay) return _RestDayCard(onAction: onAction);
    final summary = sessionSummary;
    if (summary != null) {
      return _CompletedCard(summary: summary, onAction: onAction);
    }
    return _ActiveCard(
      totalExercises: totalExercises,
      completedToday: completedToday,
      totalDuration: totalDuration,
      difficultyLabel: difficultyLabel,
      onAction: onAction,
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({
    required this.totalExercises,
    required this.completedToday,
    required this.totalDuration,
    required this.difficultyLabel,
    required this.onAction,
  });

  final int totalExercises;
  final int completedToday;
  final Duration totalDuration;
  final String difficultyLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final minutes = totalDuration.inMinutes;
    final finishBy = _formatTime(DateTime.now().add(totalDuration));
    final hasStarted = completedToday > 0 && completedToday < totalExercises;

    return _HeroCardShell(
      gradientColors: [
        colorScheme.primary,
        Color.lerp(colorScheme.primary, Colors.black, 0.35)!,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasStarted ? 'IN PROGRESS' : "TODAY'S ROUTINE",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              _DifficultyBadge(label: difficultyLabel),
            ],
          ),
          const SizedBox(height: 14),
          Icon(
            Icons.self_improvement_rounded,
            size: 46,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 14),
          Text(
            hasStarted ? 'Keep going' : 'Ready when you are',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasStarted
                ? '$completedToday of $totalExercises exercises done'
                : 'A complete session for jaw, neck, posture & breath.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _StatPill(icon: Icons.fitness_center, label: '$totalExercises exercises'),
              _StatPill(icon: Icons.schedule, label: '$minutes min'),
              _StatPill(icon: Icons.flag_outlined, label: 'Done by $finishBy'),
            ],
          ),
          const SizedBox(height: 20),
          _PulsingStartButton(
            label: hasStarted ? 'Continue Session' : 'Start Session',
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.summary, required this.onAction});

  final RoutineSessionSummary summary;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _GlowingShell(
      glowColor: const Color(0xFF2E7D32),
      child: _HeroCardShell(
        gradientColors: const [Color(0xFF2E7D32), Color(0xFF1B4D1F)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Today's Session Complete",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Text('🎉', style: TextStyle(fontSize: 22)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _StatPill(
                  icon: Icons.access_time_rounded,
                  label: 'Completed ${_formatTime(summary.completedAt)}',
                ),
                _StatPill(
                  icon: Icons.favorite_rounded,
                  label: '+${summary.wellnessScore} wellness score',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.summarize_outlined, size: 18),
                label: const Text('View Summary'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _HeroCardShell(
      gradientColors: [
        colorScheme.tertiary,
        Color.lerp(colorScheme.tertiary, Colors.black, 0.35)!,
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.self_improvement_rounded,
            size: 46,
            color: Colors.white,
          ),
          const SizedBox(height: 14),
          Text(
            'Rest Day',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your streak is paused, not broken. Hydration and skincare '
            'still count as usual.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('View Schedule'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared gradient/shadow/padding shell for every hero-card state
/// above, so the three only differ in content, not in what makes them
/// all read as "the hero card."
class _HeroCardShell extends StatelessWidget {
  const _HeroCardShell({required this.gradientColors, required this.child});

  final List<Color> gradientColors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A soft, slowly-pulsing glow behind [child] — the "completed cards
/// gently glow" treatment, used only for [_CompletedCard].
class _GlowingShell extends StatefulWidget {
  const _GlowingShell({required this.glowColor, required this.child});

  final Color glowColor;
  final Widget child;

  @override
  State<_GlowingShell> createState() => _GlowingShellState();
}

class _GlowingShellState extends State<_GlowingShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // See AmbientBackground's identical didChangeDependencies for why
    // this lives here rather than the field initializer above: it's
    // what makes disableAnimations actually stop this controller's
    // ticker, not just skip rendering its effect while it keeps
    // running unseen.
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
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final intensity = 0.18 + (_controller.value * 0.14);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: intensity),
                blurRadius: 32,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// The primary CTA button — pulses gently on a loop when today's
/// session hasn't been completed yet, as a quiet nudge rather than
/// anything demanding attention.
class _PulsingStartButton extends StatefulWidget {
  const _PulsingStartButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PulsingStartButton> createState() => _PulsingStartButtonState();
}

class _PulsingStartButtonState extends State<_PulsingStartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // See AmbientBackground's identical didChangeDependencies for why
    // this lives here rather than the field initializer above.
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
    final button = SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(widget.label),
      ),
    );

    if (MediaQuery.of(context).disableAnimations) return button;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.02);
        return Transform.scale(scale: scale, child: child);
      },
      child: button,
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.signal_cellular_alt_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}
