import 'package:flutter_test/flutter_test.dart';

import 'package:chadmate/services/exercise_completion_service.dart';
import 'package:chadmate/services/hydration_service.dart';
import 'package:chadmate/services/reminder_settings_service.dart';
import 'package:chadmate/services/skincare_service.dart';
import 'package:chadmate/services/wellness_score_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseCompletionService completion;
  late HydrationService hydration;
  late SkincareService skincare;
  late ReminderSettingsService reminders;

  final today = DateTime(2026, 3, 10);

  setUp(() async {
    resetSharedPreferences();
    completion = ExerciseCompletionService();
    hydration = HydrationService();
    skincare = SkincareService();
    reminders = ReminderSettingsService();
    await completion.load();
    await hydration.load();
    await skincare.load();
    await reminders.load();
    await hydration.setGoal(1000);
  });

  WellnessScoreService buildScore({
    int postureDailyTarget = 6,
    Map<WellnessComponent, double>? componentWeights,
  }) {
    final service = WellnessScoreService(
      exercise: completion,
      hydration: hydration,
      skincare: skincare,
      reminders: reminders,
      postureDailyTarget: postureDailyTarget,
      componentWeights: componentWeights,
    );
    addTearDown(service.dispose);
    return service;
  }

  WellnessComponentBreakdown breakdownFor(
    WellnessScoreSnapshot snapshot,
    WellnessComponent component,
  ) => snapshot.breakdown.firstWhere((b) => b.component == component);

  group('a completely empty day', () {
    test('scores zero across every component', () {
      final score = buildScore();
      final snapshot = score.snapshotFor(today);

      expect(snapshot.score, 0);
      for (final component in WellnessComponent.values) {
        expect(breakdownFor(snapshot, component).progress, 0.0);
        expect(breakdownFor(snapshot, component).points, 0.0);
      }
    });
  });

  group('default weighting — equal 25% per component', () {
    test('every component is weighted exactly 0.25', () {
      final score = buildScore();
      final snapshot = score.snapshotFor(today);

      for (final component in WellnessComponent.values) {
        expect(breakdownFor(snapshot, component).weight, 0.25);
      }
    });

    test('fully completing exactly one component yields 25 points total', () async {
      // Exercise target is 12 completions for full credit (see
      // WellnessScoreService._exerciseTargetCount).
      for (var i = 0; i < 12; i++) {
        await completion.markCompleted('exercise-$i', today);
      }
      final score = buildScore();

      final snapshot = score.snapshotFor(today);
      expect(snapshot.score, 25);
      expect(breakdownFor(snapshot, WellnessComponent.exercise).progress, 1.0);
      expect(breakdownFor(snapshot, WellnessComponent.hydration).progress, 0.0);
    });

    test('fully completing all four components yields 100', () async {
      // Posture specifically must use DateTime.now() on both sides:
      // acknowledgePostureCheck() records against the real clock
      // internally (it has no injectable date, unlike the other three
      // services), so querying snapshotFor(today) here — a fixed,
      // arbitrary constant — would make these acknowledgements
      // invisible on any date that isn't literally today's real date.
      final now = DateTime.now();
      for (var i = 0; i < 12; i++) {
        await completion.markCompleted('exercise-$i', now);
      }
      await hydration.addIntake(1000, now);
      for (final step in SkincareService.allSteps) {
        for (final routine in step.routines) {
          await skincare.setStepCompleted(step, routine, true, now);
        }
      }
      for (var i = 0; i < 6; i++) {
        await reminders.acknowledgePostureCheck();
      }
      final score = buildScore();

      expect(score.snapshotFor(now).score, 100);
    });

    test('two of four components halfway done each contribute half their '
        'points share', () async {
      // 6 of 12 exercises = 50% exercise progress.
      for (var i = 0; i < 6; i++) {
        await completion.markCompleted('exercise-$i', today);
      }
      // 500 of 1000ml = 50% hydration progress.
      await hydration.addIntake(500, today);
      final score = buildScore();

      final snapshot = score.snapshotFor(today);
      expect(breakdownFor(snapshot, WellnessComponent.exercise).points, 12.5);
      expect(breakdownFor(snapshot, WellnessComponent.hydration).points, 12.5);
      // 12.5 + 12.5 = 25, rounded.
      expect(snapshot.score, 25);
    });
  });

  group('custom weighting — a caller can rebalance the four components', () {
    test('an uneven split is honored exactly, not silently normalized', () async {
      // Exercise fully done, everything else empty.
      for (var i = 0; i < 12; i++) {
        await completion.markCompleted('exercise-$i', today);
      }
      final score = buildScore(
        componentWeights: {
          WellnessComponent.exercise: 0.7,
          WellnessComponent.hydration: 0.1,
          WellnessComponent.skincare: 0.1,
          WellnessComponent.posture: 0.1,
        },
      );

      final snapshot = score.snapshotFor(today);
      expect(breakdownFor(snapshot, WellnessComponent.exercise).weight, 0.7);
      // Full exercise progress (1.0) at 70% weight = 70 points, and
      // everything else is at 0 progress, so the total is exactly 70.
      expect(snapshot.score, 70);
    });

    test('a component weighted to zero never contributes regardless of '
        'its own progress', () async {
      await hydration.addIntake(1000, today); // fully done
      final score = buildScore(
        componentWeights: {
          WellnessComponent.exercise: 0.5,
          WellnessComponent.hydration: 0.0,
          WellnessComponent.skincare: 0.25,
          WellnessComponent.posture: 0.25,
        },
      );

      final snapshot = score.snapshotFor(today);
      expect(breakdownFor(snapshot, WellnessComponent.hydration).progress, 1.0);
      expect(breakdownFor(snapshot, WellnessComponent.hydration).points, 0.0);
      expect(snapshot.score, 0);
    });
  });

  group('individual component progress calculations', () {
    test('exercise progress scales linearly from 0 to the 12-completion '
        'target, then clamps', () async {
      final score = buildScore();

      await completion.markCompleted('e0', today);
      expect(
        breakdownFor(score.snapshotFor(today), WellnessComponent.exercise)
            .progress,
        closeTo(1 / 12, 0.0001),
      );

      for (var i = 1; i < 12; i++) {
        await completion.markCompleted('e$i', today);
      }
      expect(
        breakdownFor(score.snapshotFor(today), WellnessComponent.exercise)
            .progress,
        1.0,
      );

      // A 13th completion doesn't push progress past full credit.
      await completion.markCompleted('e12', today);
      expect(
        breakdownFor(score.snapshotFor(today), WellnessComponent.exercise)
            .progress,
        1.0,
      );
    });

    test('hydration progress is intake over the goal, clamped at 1.0', () async {
      final score = buildScore();

      await hydration.addIntake(250, today);
      expect(
        breakdownFor(score.snapshotFor(today), WellnessComponent.hydration)
            .progress,
        closeTo(0.25, 0.0001),
      );

      await hydration.addIntake(1000, today); // now well over the 1000 goal
      expect(
        breakdownFor(score.snapshotFor(today), WellnessComponent.hydration)
            .progress,
        1.0,
      );
    });

    test('skincare progress is completed steps over total enabled steps '
        'across both routines', () async {
      final score = buildScore();
      // Default enabled: 3 morning + 2 night = 5 total.
      final cleanser = SkincareService.allSteps.firstWhere(
        (s) => s.id == 'cleanser',
      );
      await skincare.setStepCompleted(
        cleanser,
        SkincareRoutine.morning,
        true,
        today,
      );

      expect(
        breakdownFor(score.snapshotFor(today), WellnessComponent.skincare)
            .progress,
        closeTo(1 / 5, 0.0001),
      );
    });

    test(
      'posture progress is acknowledgements over postureDailyTarget, '
      'clamped at 1.0',
      () async {
        final score = buildScore(postureDailyTarget: 4);

        await reminders.acknowledgePostureCheck();
        await reminders.acknowledgePostureCheck();
        expect(
          breakdownFor(
            score.snapshotFor(DateTime.now()),
            WellnessComponent.posture,
          ).progress,
          closeTo(0.5, 0.0001),
        );

        await reminders.acknowledgePostureCheck();
        await reminders.acknowledgePostureCheck();
        await reminders.acknowledgePostureCheck(); // 5th, past the target
        expect(
          breakdownFor(
            score.snapshotFor(DateTime.now()),
            WellnessComponent.posture,
          ).progress,
          1.0,
        );
      },
    );
  });

  group('reactivity', () {
    test('notifies listeners when any source service changes', () async {
      final score = buildScore();
      var notified = false;
      score.addListener(() => notified = true);

      await hydration.addIntake(100);

      expect(notified, isTrue);
    });
  });
}
