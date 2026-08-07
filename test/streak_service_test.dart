import 'package:flutter_test/flutter_test.dart';

import 'package:chadmate/services/exercise_completion_service.dart';
import 'package:chadmate/services/hydration_service.dart';
import 'package:chadmate/services/rest_day_service.dart';
import 'package:chadmate/services/skincare_service.dart';
import 'package:chadmate/services/streak_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseCompletionService completion;
  late HydrationService hydration;
  late SkincareService skincare;
  late RestDayService restDays;
  late StreakService streaks;

  final today = DateTime(2026, 3, 10);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  setUp(() async {
    resetSharedPreferences();
    completion = ExerciseCompletionService();
    hydration = HydrationService();
    skincare = SkincareService();
    restDays = RestDayService();
    await completion.load();
    await hydration.load();
    await skincare.load();
    await restDays.load();
    await hydration.setGoal(500);
    streaks = StreakService(
      completion: completion,
      hydration: hydration,
      skincare: skincare,
      restDays: restDays,
    );
  });

  tearDown(() {
    streaks.dispose();
  });

  /// Marks [kind]'s underlying habit as done on [date] — the shared
  /// setup every streak test builds on. Workout completes an
  /// exercise; hydration hits the goal; skincare completes every
  /// enabled step in both routines.
  Future<void> completeOn(StreakKind kind, DateTime date) async {
    switch (kind) {
      case StreakKind.workout:
        await completion.markCompleted('any-exercise', date);
      case StreakKind.hydration:
        await hydration.addIntake(500, date);
      case StreakKind.skincare:
        for (final step in SkincareService.allSteps) {
          for (final routine in step.routines) {
            await skincare.setStepCompleted(step, routine, true, date);
          }
        }
      case StreakKind.overall:
        await completeOn(StreakKind.workout, date);
        await completeOn(StreakKind.hydration, date);
        await completeOn(StreakKind.skincare, date);
    }
  }

  group('currentStreak — "yesterday still counts" rule, per kind', () {
    for (final kind in [
      StreakKind.workout,
      StreakKind.hydration,
      StreakKind.skincare,
    ]) {
      group(kind.name, () {
        test('zero with no activity at all', () {
          expect(streaks.currentStreak(kind, asOf: today), 0);
        });

        test('counts consecutive days ending today when today is active', () async {
          await completeOn(kind, today);
          await completeOn(kind, daysAgo(1));
          await completeOn(kind, daysAgo(2));

          expect(streaks.currentStreak(kind, asOf: today), 3);
        });

        test(
          'today not active yet does not break the streak — counts from '
          'yesterday instead',
          () async {
            await completeOn(kind, daysAgo(1));
            await completeOn(kind, daysAgo(2));

            expect(streaks.currentStreak(kind, asOf: today), 2);
          },
        );

        test('today and yesterday both inactive breaks the streak to zero', () async {
          await completeOn(kind, daysAgo(2));
          await completeOn(kind, daysAgo(3));

          expect(streaks.currentStreak(kind, asOf: today), 0);
        });

        test('a gap stops the count rather than bridging across it', () async {
          await completeOn(kind, today);
          // Gap at daysAgo(1).
          await completeOn(kind, daysAgo(2));

          expect(streaks.currentStreak(kind, asOf: today), 1);
        });
      });
    }
  });

  group('hydration streak specifically requires the full daily goal', () {
    test('a partial amount below goal does not count as an active day', () async {
      await hydration.addIntake(200, today); // goal is 500
      expect(streaks.currentStreak(StreakKind.hydration, asOf: today), 0);
    });
  });

  group('rest-day interaction', () {
    test(
      'a scheduled rest day keeps the workout streak alive with zero '
      'completed exercises',
      () async {
        await completeOn(StreakKind.workout, daysAgo(2));
        await restDays.scheduleDate(daysAgo(1)); // rest day, no exercise
        await completeOn(StreakKind.workout, today);

        expect(streaks.currentStreak(StreakKind.workout, asOf: today), 3);
      },
    );

    test(
      'without RestDayService, the same gap breaks the streak — '
      'confirms the rest day is what bridges it, not some other effect',
      () async {
        final noRestDayStreaks = StreakService(
          completion: completion,
          hydration: hydration,
          skincare: skincare,
          // No restDays provided.
        );
        addTearDown(noRestDayStreaks.dispose);

        await completeOn(StreakKind.workout, daysAgo(2));
        // daysAgo(1) intentionally left with no exercise and no rest day.
        await completeOn(StreakKind.workout, today);

        expect(
          noRestDayStreaks.currentStreak(StreakKind.workout, asOf: today),
          1,
        );
      },
    );

    test(
      'a rest day does NOT substitute for hydration or skincare — only '
      'the workout half of "overall" is forgiven',
      () async {
        await restDays.scheduleDate(today);
        // Hydration and skincare not done today.

        expect(
          streaks.infoFor(StreakKind.workout, asOf: today).activeToday,
          isTrue,
          reason: 'workout is forgiven by the rest day',
        );
        expect(
          streaks.infoFor(StreakKind.overall, asOf: today).activeToday,
          isFalse,
          reason:
              'overall still needs hydration and skincare, which were not '
              'done — a rest day is not a free pass for those',
        );
      },
    );

    test('isRestDayToday is only ever true for workout and overall, never '
        'hydration or skincare', () async {
      await restDays.scheduleDate(today);
      await completeOn(StreakKind.hydration, today);
      await completeOn(StreakKind.skincare, today);

      expect(
        streaks.infoFor(StreakKind.workout, asOf: today).isRestDayToday,
        isTrue,
      );
      expect(
        streaks.infoFor(StreakKind.overall, asOf: today).isRestDayToday,
        isTrue,
      );
      expect(
        streaks.infoFor(StreakKind.hydration, asOf: today).isRestDayToday,
        isFalse,
      );
      expect(
        streaks.infoFor(StreakKind.skincare, asOf: today).isRestDayToday,
        isFalse,
      );
    });

    test('a recurring weekday rest day works the same as a specific date', () async {
      // today (2026-03-10) is a Tuesday; make Tuesdays a recurring rest day.
      expect(today.weekday, DateTime.tuesday);
      await restDays.addRecurringWeekday(DateTime.tuesday);

      expect(
        streaks.infoFor(StreakKind.workout, asOf: today).activeToday,
        isTrue,
      );
    });
  });

  group('overall streak requires all three underlying habits', () {
    test('active only when workout, hydration, and skincare are all done', () async {
      await completeOn(StreakKind.workout, today);
      await completeOn(StreakKind.hydration, today);
      // Skincare not done.

      expect(
        streaks.infoFor(StreakKind.overall, asOf: today).activeToday,
        isFalse,
      );

      await completeOn(StreakKind.skincare, today);

      expect(
        streaks.infoFor(StreakKind.overall, asOf: today).activeToday,
        isTrue,
      );
    });

    test('a 3-day overall streak requires all three every single day', () async {
      for (final day in [today, daysAgo(1), daysAgo(2)]) {
        await completeOn(StreakKind.overall, day);
      }

      expect(streaks.currentStreak(StreakKind.overall, asOf: today), 3);
    });

    test(
      'missing just skincare on one day breaks the overall streak even '
      'though workout and hydration were both done that day',
      () async {
        await completeOn(StreakKind.overall, today);
        await completeOn(StreakKind.workout, daysAgo(1));
        await completeOn(StreakKind.hydration, daysAgo(1));
        // Skincare specifically missing on daysAgo(1).

        expect(streaks.currentStreak(StreakKind.overall, asOf: today), 1);
      },
    );
  });

  group('longestStreak', () {
    test('finds the longest run across all recorded history for a kind', () async {
      // A 3-day run long ago, then a gap, then today only.
      await completeOn(StreakKind.workout, daysAgo(10));
      await completeOn(StreakKind.workout, daysAgo(9));
      await completeOn(StreakKind.workout, daysAgo(8));
      await completeOn(StreakKind.workout, today);

      expect(streaks.longestStreak(StreakKind.workout, asOf: today), 3);
    });

    test('zero when nothing has ever been recorded for any service', () {
      expect(streaks.longestStreak(StreakKind.overall, asOf: today), 0);
    });
  });

  group('reactivity', () {
    test('StreakService notifies listeners when a source service changes', () async {
      var notified = false;
      streaks.addListener(() => notified = true);

      await completion.markCompleted('jaw-release-drop');

      expect(notified, isTrue);
    });
  });
}
