import 'package:flutter/foundation.dart';

import 'app_notifications.dart';
import 'exercise_completion_service.dart';
import 'hydration_service.dart';
import 'reminder_settings_service.dart';
import 'skincare_service.dart';

/// One component that feeds into the overall [WellnessScoreService]
/// score.
enum WellnessComponent { exercise, hydration, skincare, posture }

/// A single component's contribution to today's wellness score: its
/// own 0.0–1.0 progress, the weight it was given, and how many of
/// the overall 100 points it ended up contributing.
class WellnessComponentBreakdown {
  const WellnessComponentBreakdown({
    required this.component,
    required this.progress,
    required this.weight,
    required this.points,
  });

  final WellnessComponent component;

  /// This component's own completion ratio, clamped 0.0–1.0.
  final double progress;

  /// This component's share of the overall score (weights across all
  /// components sum to 1.0).
  final double weight;

  /// Points (out of 100) this component contributed to the total.
  final double points;

  /// Display label for this component, e.g. `'Exercise'`.
  String get label {
    switch (component) {
      case WellnessComponent.exercise:
        return 'Exercise';
      case WellnessComponent.hydration:
        return 'Hydration';
      case WellnessComponent.skincare:
        return 'Skincare';
      case WellnessComponent.posture:
        return 'Posture';
    }
  }
}

/// A full snapshot of today's wellness score: the overall 0–100
/// total plus the per-component breakdown it was built from.
class WellnessScoreSnapshot {
  const WellnessScoreSnapshot({
    required this.score,
    required this.breakdown,
  });

  /// Overall score, 0–100.
  final int score;

  /// One entry per [WellnessComponent], in the same order as
  /// [WellnessComponent.values].
  final List<WellnessComponentBreakdown> breakdown;

  /// Today's progress as a 0.0–1.0 fraction, for feeding directly
  /// into a circular progress indicator.
  double get progress => score / 100;

  /// A short, human-readable line summarizing today's score, calling
  /// out whichever component is lagging furthest behind (if any) so
  /// the explanation stays actionable rather than generic.
  String get explanation {
    if (score >= 90) {
      return "Excellent! You're on top of every part of your routine today.";
    }

    final lagging = [...breakdown]
      ..sort((a, b) => a.progress.compareTo(b.progress));
    final weakest = lagging.first;

    if (score >= 70) {
      return 'Good progress today — a bit more ${weakest.label.toLowerCase()} '
          'would round things out.';
    }
    if (score >= 40) {
      return "You're making progress. Try focusing on "
          '${weakest.label.toLowerCase()} to boost your score.';
    }
    return 'Your day is just getting started — log some '
        '${weakest.label.toLowerCase()} to get your score moving.';
  }
}

/// Derives a single daily "Wellness Score" (0–100) from the four
/// habit-tracking services the app already persists per-day data
/// for: completed exercises, hydration progress, skincare checklist
/// completion, and posture reminders acknowledged.
///
/// Like [StreakService], this is intentionally a pure read-through
/// layer rather than its own persisted store — every input is
/// already recorded elsewhere, so recomputing the score on every
/// call means there's nothing new to keep in sync, and the score
/// updates automatically the instant any underlying habit changes or
/// a new day begins.
///
/// Each component contributes an equal 25% weight by default (see
/// [componentWeights]), matching the four trackers this score is
/// built from. Posture doesn't have a "goal" in the same sense as
/// the others (there's no fixed step count to check off), so it's
/// scored against [postureDailyTarget] reminder acknowledgements —
/// tunable by the caller if a different daily cadence makes more
/// sense for a given user.
class WellnessScoreService extends ChangeNotifier {
  WellnessScoreService({
    required ExerciseCompletionService exercise,
    required HydrationService hydration,
    required SkincareService skincare,
    required ReminderSettingsService reminders,
    this.postureDailyTarget = 6,
    Map<WellnessComponent, double>? componentWeights,
  })  : _exercise = exercise,
        _hydration = hydration,
        _skincare = skincare,
        _reminders = reminders,
        componentWeights = componentWeights ?? _defaultWeights {
    _exercise.addListener(notifyListeners);
    _hydration.addListener(notifyListeners);
    _skincare.addListener(notifyListeners);
    _reminders.addListener(notifyListeners);
  }

  static const Map<WellnessComponent, double> _defaultWeights = {
    WellnessComponent.exercise: 0.25,
    WellnessComponent.hydration: 0.25,
    WellnessComponent.skincare: 0.25,
    WellnessComponent.posture: 0.25,
  };

  final ExerciseCompletionService _exercise;
  final HydrationService _hydration;
  final SkincareService _skincare;
  final ReminderSettingsService _reminders;

  /// How many posture-reminder acknowledgements count as a "full"
  /// posture day. Sitting at a desk for a typical day with reminders
  /// every 30–60 minutes lands around this range, so hitting it
  /// reflects genuinely staying on top of posture checks rather than
  /// a single tap.
  final int postureDailyTarget;

  /// Each component's share of the overall 100-point score. Weights
  /// should sum to 1.0; [todaySnapshot] doesn't enforce this, so a
  /// caller providing custom weights is responsible for keeping them
  /// normalized.
  final Map<WellnessComponent, double> componentWeights;

  /// Exercise-completion progress (0.0–1.0) on [date]: the fraction
  /// of exercises completed that day, out of [_exerciseTargetCount].
  /// Uses the simplest available signal — whether at least one
  /// exercise was completed counts as some progress, scaling up to
  /// full credit at [_exerciseTargetCount] completions — since
  /// [ExerciseCompletionService] itself has no notion of a daily
  /// target exercise count independent of whatever routine a screen
  /// built.
  double _exerciseProgressOn(DateTime date) {
    final completed = _exercise.countCompletedOn(date);
    if (completed <= 0) return 0.0;
    return (completed / _exerciseTargetCount).clamp(0.0, 1.0).toDouble();
  }

  /// A reasonable default daily exercise target — matches
  /// [RoutineDifficulty.beginner]'s total (2 exercises across each of
  /// the six [ExerciseCategory] values,
  /// [RoutineDifficulty.exercisesPerCategory] × [ExerciseCategory.values]
  /// length) in [DailyRoutineService], since that's the routine size
  /// someone gets by default before ever touching the difficulty
  /// picker. Someone on Intermediate or Advanced reaching full credit
  /// a bit before finishing every last exercise is a reasonable
  /// trade-off against the alternative — this component would need a
  /// live dependency on that day's actual generated routine length to
  /// track it exactly, which is more coupling than this rough,
  /// same-order-of-magnitude estimate is worth.
  static const int _exerciseTargetCount = 12;

  double _hydrationProgressOn(DateTime date) {
    final goalMl = _hydration.goalMl;
    if (goalMl <= 0) return 0.0;
    return (_hydration.intakeOn(date) / goalMl).clamp(0.0, 1.0).toDouble();
  }

  double _skincareProgressOn(DateTime date) {
    final totalSteps = _skincare.totalCountFor(SkincareRoutine.morning) +
        _skincare.totalCountFor(SkincareRoutine.night);
    if (totalSteps == 0) return 0.0;
    final completedSteps =
        _skincare.completedCountFor(SkincareRoutine.morning, date) +
            _skincare.completedCountFor(SkincareRoutine.night, date);
    return (completedSteps / totalSteps).clamp(0.0, 1.0).toDouble();
  }

  /// Posture progress (0.0–1.0) on [date]: how many posture reminders
  /// were acknowledged that day, out of [postureDailyTarget].
  double _postureProgressOn(DateTime date) {
    final acknowledged = _reminders.historyFor(ReminderKind.posture, date).length;
    if (postureDailyTarget <= 0) return 0.0;
    return (acknowledged / postureDailyTarget).clamp(0.0, 1.0).toDouble();
  }

  double _progressForOn(WellnessComponent component, DateTime date) {
    switch (component) {
      case WellnessComponent.exercise:
        return _exerciseProgressOn(date);
      case WellnessComponent.hydration:
        return _hydrationProgressOn(date);
      case WellnessComponent.skincare:
        return _skincareProgressOn(date);
      case WellnessComponent.posture:
        return _postureProgressOn(date);
    }
  }

  /// Computes the full wellness score snapshot for [date]: the
  /// overall 0–100 total plus the per-component breakdown behind it.
  ///
  /// Reads exactly the same underlying signals [todaySnapshot] uses
  /// for today, just evaluated as of [date] instead — so a calendar
  /// or history view calling this for a past day gets a genuine,
  /// fully-accurate reconstruction rather than an approximation.
  WellnessScoreSnapshot snapshotFor(DateTime date) {
    final breakdown = <WellnessComponentBreakdown>[];
    var totalPoints = 0.0;

    for (final component in WellnessComponent.values) {
      final progress = _progressForOn(component, date);
      final weight = componentWeights[component] ?? 0.0;
      final points = progress * weight * 100;
      totalPoints += points;
      breakdown.add(
        WellnessComponentBreakdown(
          component: component,
          progress: progress,
          weight: weight,
          points: points,
        ),
      );
    }

    return WellnessScoreSnapshot(
      score: totalPoints.round().clamp(0, 100),
      breakdown: breakdown,
    );
  }

  /// Computes today's full wellness score snapshot. Shorthand for
  /// `snapshotFor(DateTime.now())`.
  WellnessScoreSnapshot todaySnapshot() => snapshotFor(DateTime.now());

  @override
  void dispose() {
    _exercise.removeListener(notifyListeners);
    _hydration.removeListener(notifyListeners);
    _skincare.removeListener(notifyListeners);
    _reminders.removeListener(notifyListeners);
    super.dispose();
  }
}
