import 'package:flutter_test/flutter_test.dart';

import 'package:chadmate/services/exercise_completion_service.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ExerciseCompletionService service;

  setUp(() async {
    resetSharedPreferences();
    service = ExerciseCompletionService();
    await service.load();
  });

  group('completion tracking', () {
    test('starts empty', () {
      expect(service.completedTodayIds, isEmpty);
      expect(service.totalCompletedCount, 0);
      expect(service.isCompletedToday('jaw-release-drop'), isFalse);
    });

    test('markCompleted adds to today by default', () async {
      await service.markCompleted('jaw-release-drop');

      expect(service.isCompletedToday('jaw-release-drop'), isTrue);
      expect(service.completedTodayIds, {'jaw-release-drop'});
    });

    test('markCompleted twice is a no-op, not a duplicate', () async {
      await service.markCompleted('jaw-release-drop');
      await service.markCompleted('jaw-release-drop');

      expect(service.countCompletedOn(), 1);
    });

    test('markIncomplete removes it', () async {
      await service.markCompleted('jaw-release-drop');
      await service.markIncomplete('jaw-release-drop');

      expect(service.isCompletedToday('jaw-release-drop'), isFalse);
      expect(service.completedTodayIds, isEmpty);
    });

    test('markIncomplete on something never completed is a safe no-op', () async {
      await service.markIncomplete('never-completed');

      expect(service.completedTodayIds, isEmpty);
    });

    test('toggleCompleted flips state and reports the new value', () async {
      final firstToggle = await service.toggleCompleted('chin-tucks');
      expect(firstToggle, isTrue);
      expect(service.isCompletedToday('chin-tucks'), isTrue);

      final secondToggle = await service.toggleCompleted('chin-tucks');
      expect(secondToggle, isFalse);
      expect(service.isCompletedToday('chin-tucks'), isFalse);
    });

    test('multiple exercises the same day all count', () async {
      await service.markCompleted('jaw-release-drop');
      await service.markCompleted('chin-tucks');
      await service.markCompleted('slow-neck-circles');

      expect(service.countCompletedOn(), 3);
      expect(service.totalCompletedCount, 3);
    });

    test(
      'the same exercise completed on different days counts once per day '
      'toward totalCompletedCount',
      () async {
        final today = DateTime(2026, 3, 10);
        final yesterday = DateTime(2026, 3, 9);
        await service.markCompleted('jaw-release-drop', yesterday);
        await service.markCompleted('jaw-release-drop', today);

        expect(service.totalCompletedCount, 2);
        expect(service.countCompletedOn(yesterday), 1);
        expect(service.countCompletedOn(today), 1);
      },
    );
  });

  group('date-key normalization', () {
    test('two different times on the same calendar day are the same day', () async {
      final morning = DateTime(2026, 3, 10, 7, 15);
      final night = DateTime(2026, 3, 10, 22, 45);
      await service.markCompleted('jaw-release-drop', morning);

      expect(service.isCompletedOn('jaw-release-drop', night), isTrue);
    });

    test('a day with nothing logged reports empty, not an error', () {
      expect(service.idsCompletedOn(DateTime(2020, 1, 1)), isEmpty);
      expect(service.hasActivityOn(DateTime(2020, 1, 1)), isFalse);
    });
  });

  group('currentStreak — "yesterday still counts" rule', () {
    // A fixed reference date rather than DateTime.now(), so every
    // assertion below is exact and reproducible regardless of what
    // day this actually runs on.
    final today = DateTime(2026, 3, 10);
    DateTime daysAgo(int n) => today.subtract(Duration(days: n));

    test('zero when nothing has ever been completed', () {
      expect(service.currentStreak(asOf: today), 0);
    });

    test('counts consecutive days ending today when today is done', () async {
      await service.markCompleted('a', today);
      await service.markCompleted('a', daysAgo(1));
      await service.markCompleted('a', daysAgo(2));

      expect(service.currentStreak(asOf: today), 3);
    });

    test(
      'today not done yet does not break the streak — it counts from '
      'yesterday instead',
      () async {
        await service.markCompleted('a', daysAgo(1));
        await service.markCompleted('a', daysAgo(2));
        // Nothing completed on `today` itself.

        expect(service.currentStreak(asOf: today), 2);
      },
    );

    test(
      'today AND yesterday both missing breaks the streak to zero, even '
      'with older activity further back',
      () async {
        await service.markCompleted('a', daysAgo(2));
        await service.markCompleted('a', daysAgo(3));
        // Gap: nothing on today or yesterday.

        expect(service.currentStreak(asOf: today), 0);
      },
    );

    test('a gap in the middle stops the count at the gap, ignoring older '
        'activity on the far side of it', () async {
      await service.markCompleted('a', today);
      await service.markCompleted('a', daysAgo(1));
      // Gap at daysAgo(2).
      await service.markCompleted('a', daysAgo(3));
      await service.markCompleted('a', daysAgo(4));

      expect(service.currentStreak(asOf: today), 2);
    });

    test('exactly one day active (today only) is a streak of 1', () async {
      await service.markCompleted('a', today);

      expect(service.currentStreak(asOf: today), 1);
    });

    test('exactly one day active (yesterday only, today not done) is '
        'still a streak of 1 via the yesterday rule', () async {
      await service.markCompleted('a', daysAgo(1));

      expect(service.currentStreak(asOf: today), 1);
    });
  });

  group('longestStreak', () {
    final today = DateTime(2026, 3, 10);
    DateTime daysAgo(int n) => today.subtract(Duration(days: n));

    test('zero when nothing has ever been completed', () {
      expect(service.longestStreak(), 0);
    });

    test('finds a longer run earlier in history than the current streak', () async {
      // A 4-day run long ago...
      await service.markCompleted('a', daysAgo(20));
      await service.markCompleted('a', daysAgo(19));
      await service.markCompleted('a', daysAgo(18));
      await service.markCompleted('a', daysAgo(17));
      // ...and only a 1-day current streak.
      await service.markCompleted('a', today);

      expect(service.longestStreak(), 4);
    });

    test('the current streak counts if it is in fact the longest', () async {
      await service.markCompleted('a', today);
      await service.markCompleted('a', daysAgo(1));
      await service.markCompleted('a', daysAgo(2));

      expect(service.longestStreak(), 3);
    });

    test('earliestActivityDay finds the true earliest day across gaps', () async {
      await service.markCompleted('a', daysAgo(20));
      await service.markCompleted('a', today);

      expect(service.earliestActivityDay, daysAgo(20));
    });
  });
}
