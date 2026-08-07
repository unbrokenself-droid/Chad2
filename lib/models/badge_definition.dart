import 'package:flutter/material.dart';

/// Stable identifier for each achievement badge. Never renumbered or
/// renamed once shipped — it's also the [SharedPreferences] storage
/// key for that badge's unlocked state, so existing users' unlocked
/// badges keep matching up after app updates.
enum BadgeId {
  firstWorkout,
  sevenDayStreak,
  hydrationHero,
  consistentSkincare,
  postureChampion,
  hundredExercises,
}

/// Static metadata for one achievement badge: its display copy, icon,
/// and the numeric goal its progress is measured against.
///
/// This is intentionally just data — [BadgeService] is the one place
/// that knows how to turn each badge's [BadgeId] into a live progress
/// value from the app's tracking services, keeping that mapping in
/// one spot rather than scattered across the UI.
@immutable
class BadgeDefinition {
  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.goal,
    required this.unit,
  });

  final BadgeId id;

  /// Short display name, e.g. `'7-Day Streak'`.
  final String title;

  /// One-line explanation of how to earn it, e.g. `'Complete a full
  /// week without missing a day'`.
  final String description;

  /// Icon shown on the badge tile, both locked and unlocked.
  final IconData icon;

  /// The target value this badge's progress counts up to before it
  /// unlocks, e.g. `7` for a 7-day streak or `100` for 100 exercises.
  final int goal;

  /// Short unit label for [goal], used to render progress as
  /// `'3 of 7 days'` etc.
  final String unit;

  /// The fixed catalog of every achievement badge offered by the
  /// app, in display order.
  static const List<BadgeDefinition> all = [
    BadgeDefinition(
      id: BadgeId.firstWorkout,
      title: 'First Workout',
      description: 'Complete your very first exercise',
      icon: Icons.emoji_events,
      goal: 1,
      unit: 'exercise',
    ),
    BadgeDefinition(
      id: BadgeId.sevenDayStreak,
      title: '7-Day Streak',
      description: 'Keep your overall wellness streak alive for a week',
      icon: Icons.local_fire_department,
      goal: 7,
      unit: 'days',
    ),
    BadgeDefinition(
      id: BadgeId.hydrationHero,
      title: 'Hydration Hero',
      description: 'Reach your water goal 7 days in a row',
      icon: Icons.water_drop,
      goal: 7,
      unit: 'days',
    ),
    BadgeDefinition(
      id: BadgeId.consistentSkincare,
      title: 'Consistent Skincare',
      description: 'Complete both routines 7 days in a row',
      icon: Icons.spa,
      goal: 7,
      unit: 'days',
    ),
    BadgeDefinition(
      id: BadgeId.postureChampion,
      title: 'Posture Champion',
      description: 'Acknowledge 50 posture reminders in total',
      icon: Icons.accessibility_new,
      goal: 50,
      unit: 'reminders',
    ),
    BadgeDefinition(
      id: BadgeId.hundredExercises,
      title: '100 Exercises Completed',
      description: 'Complete 100 exercises in total',
      icon: Icons.military_tech,
      goal: 100,
      unit: 'exercises',
    ),
  ];

  static BadgeDefinition forId(BadgeId id) {
    return all.firstWhere((definition) => definition.id == id);
  }
}
