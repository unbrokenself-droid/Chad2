import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chadmate/models/badge_definition.dart';
import 'package:chadmate/services/badge_service.dart';
import 'package:chadmate/services/exercise_completion_service.dart';
import 'package:chadmate/services/hydration_service.dart';
import 'package:chadmate/services/reminder_settings_service.dart';
import 'package:chadmate/services/skincare_service.dart';
import 'package:chadmate/services/streak_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseCompletionService completion;
  late HydrationService hydration;
  late SkincareService skincare;
  late StreakService streaks;
  late ReminderSettingsService reminders;
  late BadgeService badges;

  final today = DateTime(2026, 3, 10);
  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  setUp(() async {
    resetSharedPreferences();
    completion = ExerciseCompletionService();
    hydration = HydrationService();
    skincare = SkincareService();
    // ReminderSettingsService defaults to the real AppNotifications
    // singleton (it can't be substituted — its constructor is
    // private). That's fine here: every test below only calls
    // acknowledgePostureCheck(), which is pure history bookkeeping and
    // never touches the plugin — enable()/disable(), which do, are
    // never called anywhere in this file.
    reminders = ReminderSettingsService();
    await completion.load();
    await hydration.load();
    await skincare.load();
    await reminders.load();
    await hydration.setGoal(500);
    streaks = StreakService(
      completion: completion,
      hydration: hydration,
      skincare: skincare,
    );
    badges = BadgeService(
      exercise: completion,
      hydration: hydration,
      skincare: skincare,
      streak: streaks,
      reminders: reminders,
    );
    await badges.load();
  });

  tearDown(() {
    badges.dispose();
    streaks.dispose();
  });

  BadgeProgress progressFor(BadgeId id) =>
      badges.allProgress().firstWhere((p) => p.definition.id == id);

  Future<void> completeExercises(int count) async {
    for (var i = 0; i < count; i++) {
      await completion.markCompleted('exercise-$i', today);
    }
  }

  /// Builds a run of [days] consecutive completed days for [kind],
  /// ending at [today] — the shared setup every streak-based badge
  /// test needs (sevenDayStreak, hydrationHero, consistentSkincare).
  Future<void> buildStreak(StreakKind kind, int days) async {
    for (var i = 0; i < days; i++) {
      final date = daysAgo(i);
      switch (kind) {
        case StreakKind.workout:
          await completion.markCompleted('streak-exercise', date);
        case StreakKind.hydration:
          await hydration.addIntake(500, date);
        case StreakKind.skincare:
          for (final step in SkincareService.allSteps) {
            for (final routine in step.routines) {
              await skincare.setStepCompleted(step, routine, true, date);
            }
          }
        case StreakKind.overall:
          throw UnsupportedError('use the individual kinds');
      }
    }
  }

  group('firstWorkout — goal 1', () {
    test('locked with zero completions', () {
      final progress = progressFor(BadgeId.firstWorkout);
      expect(progress.unlocked, isFalse);
      expect(progress.current, 0);
    });

    test('unlocks on the very first completion', () async {
      await completeExercises(1);
      await badges.checkForNewUnlocks();

      expect(progressFor(BadgeId.firstWorkout).unlocked, isTrue);
    });
  });

  group('hundredExercises — goal 100', () {
    test('locked one short of the goal', () async {
      await completeExercises(99);
      await badges.checkForNewUnlocks();

      final progress = progressFor(BadgeId.hundredExercises);
      expect(progress.current, 99);
      expect(progress.unlocked, isFalse);
    });

    test('unlocks exactly at 100', () async {
      await completeExercises(100);
      await badges.checkForNewUnlocks();

      expect(progressFor(BadgeId.hundredExercises).unlocked, isTrue);
    });

    test(
      'progress display clamps at the goal even if the underlying stat '
      'keeps climbing after unlock',
      () async {
        await completeExercises(120);
        await badges.checkForNewUnlocks();

        expect(progressFor(BadgeId.hundredExercises).current, 100);
      },
    );
  });

  group('sevenDayStreak — goal 7, tracks overall longestStreak', () {
    test('locked with a 6-day streak on each individual habit', () async {
      await buildStreak(StreakKind.workout, 6);
      await buildStreak(StreakKind.hydration, 6);
      await buildStreak(StreakKind.skincare, 6);
      await badges.checkForNewUnlocks();

      final progress = progressFor(BadgeId.sevenDayStreak);
      expect(progress.current, 6);
      expect(progress.unlocked, isFalse);
    });

    test('unlocks once all three habits share a 7-day run', () async {
      await buildStreak(StreakKind.workout, 7);
      await buildStreak(StreakKind.hydration, 7);
      await buildStreak(StreakKind.skincare, 7);
      await badges.checkForNewUnlocks();

      expect(progressFor(BadgeId.sevenDayStreak).unlocked, isTrue);
    });

    test(
      'a 7-day workout streak alone does not unlock it — overall needs '
      'all three',
      () async {
        await buildStreak(StreakKind.workout, 7);
        // Hydration and skincare not built up.
        await badges.checkForNewUnlocks();

        expect(progressFor(BadgeId.sevenDayStreak).unlocked, isFalse);
      },
    );
  });

  group('hydrationHero — goal 7, tracks hydration longestStreak only', () {
    test('unlocks from hydration alone, independent of the other habits', () async {
      await buildStreak(StreakKind.hydration, 7);
      // Workout and skincare untouched.
      await badges.checkForNewUnlocks();

      expect(progressFor(BadgeId.hydrationHero).unlocked, isTrue);
      // Confirms it really is reading the hydration-specific streak,
      // not accidentally the overall one (which would still be 0 here).
      expect(progressFor(BadgeId.sevenDayStreak).unlocked, isFalse);
    });

    test('locked at a 5-day hydration streak', () async {
      await buildStreak(StreakKind.hydration, 5);
      await badges.checkForNewUnlocks();

      expect(progressFor(BadgeId.hydrationHero).current, 5);
      expect(progressFor(BadgeId.hydrationHero).unlocked, isFalse);
    });
  });

  group('consistentSkincare — goal 7, tracks skincare longestStreak only', () {
    test('unlocks from skincare alone, independent of the other habits', () async {
      await buildStreak(StreakKind.skincare, 7);
      await badges.checkForNewUnlocks();

      expect(progressFor(BadgeId.consistentSkincare).unlocked, isTrue);
      expect(progressFor(BadgeId.sevenDayStreak).unlocked, isFalse);
    });
  });

  group('postureChampion — goal 50, tracks total posture acknowledgements', () {
    test('locked with 49 acknowledgements', () async {
      for (var i = 0; i < 49; i++) {
        await reminders.acknowledgePostureCheck();
      }
      await badges.checkForNewUnlocks();

      final progress = progressFor(BadgeId.postureChampion);
      expect(progress.current, 49);
      expect(progress.unlocked, isFalse);
    });

    test('unlocks at exactly 50', () async {
      for (var i = 0; i < 50; i++) {
        await reminders.acknowledgePostureCheck();
      }
      await badges.checkForNewUnlocks();

      expect(progressFor(BadgeId.postureChampion).unlocked, isTrue);
    });
  });

  group('newlyUnlocked / acknowledgeNewlyUnlocked', () {
    test('crossing a threshold adds it to newlyUnlocked', () async {
      await completeExercises(1);
      await badges.checkForNewUnlocks();

      expect(badges.newlyUnlocked, contains(BadgeId.firstWorkout));
    });

    test('acknowledging clears the list without un-earning the badge', () async {
      await completeExercises(1);
      await badges.checkForNewUnlocks();

      badges.acknowledgeNewlyUnlocked();

      expect(badges.newlyUnlocked, isEmpty);
      expect(progressFor(BadgeId.firstWorkout).unlocked, isTrue);
    });

    test('an already-unlocked badge does not re-appear in newlyUnlocked '
        'on a later check', () async {
      await completeExercises(1);
      await badges.checkForNewUnlocks();
      badges.acknowledgeNewlyUnlocked();

      // Some unrelated progress, but firstWorkout was already earned.
      await completeExercises(2);
      await badges.checkForNewUnlocks();

      expect(badges.newlyUnlocked, isNot(contains(BadgeId.firstWorkout)));
    });

    test('unlock state survives a reload from persisted storage', () async {
      await completeExercises(1);
      await badges.checkForNewUnlocks();

      final reloaded = BadgeService(
        exercise: completion,
        hydration: hydration,
        skincare: skincare,
        streak: streaks,
        reminders: reminders,
      );
      addTearDown(reloaded.dispose);
      await reloaded.load();

      expect(
        reloaded.allProgress().firstWhere(
          (p) => p.definition.id == BadgeId.firstWorkout,
        ).unlocked,
        isTrue,
      );
      // load() itself shouldn't re-announce a badge from a previous
      // session as newly unlocked.
      expect(reloaded.newlyUnlocked, isEmpty);
    });
  });

  group('unlockedCount', () {
    test('reports (0, 6) with nothing unlocked', () {
      final (unlocked, total) = badges.unlockedCount();
      expect(unlocked, 0);
      expect(total, 6);
    });

    test('reports the running total as badges unlock', () async {
      await completeExercises(1); // unlocks firstWorkout
      await badges.checkForNewUnlocks();

      final (unlocked, total) = badges.unlockedCount();
      expect(unlocked, 1);
      expect(total, 6);
    });
  });

  group('legacy format migration', () {
    // BadgeService's unlock storage keys are private, so the pre- and
    // post-migration key names are duplicated here rather than
    // imported — same tradeoff test/widget_test.dart already makes
    // for OnboardingService's keys. If either name ever changes, this
    // needs updating too.
    const legacyKey = 'unlocked_badges_v1';
    const jsonKey = 'unlocked_badges_v2';

    /// Builds a complete fresh set of source services plus a
    /// BadgeService loaded against whatever SharedPreferences state
    /// the test's own resetSharedPreferences call last set up —
    /// deliberately not reusing the outer setUp()'s `completion` /
    /// `hydration` / etc., since those were already constructed and
    /// loaded against the empty store setUp() seeds by default,
    /// before a migration test gets a chance to seed its own data.
    ///
    /// Every source service starts with zero progress on every stat,
    /// so a badge only reads as unlocked here if the persisted unlock
    /// map itself says so — never because live progress happens to
    /// separately qualify it, which is what makes these tests able to
    /// tell a real migration apart from a coincidental fresh unlock.
    Future<BadgeService> buildFreshBadges() async {
      final freshCompletion = ExerciseCompletionService();
      final freshHydration = HydrationService();
      final freshSkincare = SkincareService();
      final freshReminders = ReminderSettingsService();
      await freshCompletion.load();
      await freshHydration.load();
      await freshSkincare.load();
      await freshReminders.load();
      final freshStreaks = StreakService(
        completion: freshCompletion,
        hydration: freshHydration,
        skincare: freshSkincare,
      );
      final freshBadges = BadgeService(
        exercise: freshCompletion,
        hydration: freshHydration,
        skincare: freshSkincare,
        streak: freshStreaks,
        reminders: freshReminders,
      );
      addTearDown(freshStreaks.dispose);
      addTearDown(freshBadges.dispose);
      await freshBadges.load();
      return freshBadges;
    }

    BadgeProgress firstWorkoutProgress(BadgeService service) =>
        service.allProgress().firstWhere(
          (p) => p.definition.id == BadgeId.firstWorkout,
        );

    test(
      'a legacy delimiter-encoded unlock is decoded and adopted on load',
      () async {
        final unlockedAt = DateTime(2026, 2, 15, 9, 30);
        resetSharedPreferences(
          seed: {legacyKey: 'firstWorkout:${unlockedAt.toIso8601String()}'},
        );

        final migrated = await buildFreshBadges();
        final progress = firstWorkoutProgress(migrated);

        expect(progress.unlocked, isTrue);
        expect(progress.unlockedAt, unlockedAt);
      },
    );

    test('a migrated unlock is written back out as JSON under the new key', () async {
      final unlockedAt = DateTime(2026, 2, 15, 9, 30);
      resetSharedPreferences(
        seed: {legacyKey: 'firstWorkout:${unlockedAt.toIso8601String()}'},
      );

      await buildFreshBadges();

      final prefs = SharedPreferencesAsync();
      final storedJson = await prefs.getString(jsonKey);
      expect(storedJson, isNotNull);
      expect(jsonDecode(storedJson!), {
        'firstWorkout': unlockedAt.toIso8601String(),
      });
    });

    test(
      'once migrated, the unlock survives even if the legacy key is '
      'cleared afterward — it no longer depends on it',
      () async {
        final unlockedAt = DateTime(2026, 2, 15, 9, 30);
        resetSharedPreferences(
          seed: {legacyKey: 'firstWorkout:${unlockedAt.toIso8601String()}'},
        );
        await buildFreshBadges();

        final prefs = SharedPreferencesAsync();
        await prefs.remove(legacyKey);

        final second = await buildFreshBadges();
        expect(firstWorkoutProgress(second).unlocked, isTrue);
      },
    );

    test(
      'an existing JSON value takes priority over a stale legacy value '
      '— migration never overwrites already-migrated data',
      () async {
        final legacyTime = DateTime(2026, 1, 1);
        final jsonTime = DateTime(2026, 2, 15, 9, 30);
        resetSharedPreferences(
          seed: {
            legacyKey: 'firstWorkout:${legacyTime.toIso8601String()}',
            jsonKey: jsonEncode({
              'firstWorkout': jsonTime.toIso8601String(),
            }),
          },
        );

        final service = await buildFreshBadges();

        expect(firstWorkoutProgress(service).unlockedAt, jsonTime);
      },
    );

    test(
      'a fresh install with neither key set starts with nothing unlocked',
      () async {
        resetSharedPreferences();

        final freshBadges = await buildFreshBadges();
        final (unlocked, _) = freshBadges.unlockedCount();
        expect(unlocked, 0);

        // Nothing to migrate, so no JSON value should have been
        // written for a user who never had any legacy data.
        final prefs = SharedPreferencesAsync();
        expect(await prefs.getString(jsonKey), isNull);
      },
    );
  });
}
