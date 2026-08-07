import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The five wellness goals a user can pick during onboarding.
///
/// Purely descriptive/local — nothing here changes which exercises
/// are shown elsewhere yet, but the stored selection is available for
/// future personalization (e.g. highlighting matching exercises).
enum OnboardingGoal {
  jawRelaxation('Jaw relaxation', '😌'),
  betterPosture('Better posture', '🧍'),
  neckMobility('Neck mobility', '🦢'),
  skincareConsistency('Skincare consistency', '✨'),
  hydration('Hydration', '💧');

  const OnboardingGoal(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Self-reported experience level, collected during onboarding.
///
/// Like [OnboardingGoal], this is stored for future use (e.g. scaling
/// suggested routine length or default rep counts) without changing
/// existing screens yet.
enum ExperienceLevel {
  beginner('Beginner', 'New to facial fitness'),
  intermediate('Intermediate', 'Some experience with routines'),
  advanced('Advanced', 'Very familiar, ready for more');

  const ExperienceLevel(this.label, this.description);

  final String label;
  final String description;
}

/// Immutable snapshot of everything collected during onboarding.
@immutable
class OnboardingProfile {
  const OnboardingProfile({
    this.name,
    this.goals = const <OnboardingGoal>{},
    this.experienceLevel,
    this.remindersOptedIn = const <String>{},
  });

  /// User's display name. Optional — null/empty means skipped.
  final String? name;

  /// Selected wellness goals. May be empty if the user skips this step.
  final Set<OnboardingGoal> goals;

  /// Self-reported experience level. Null until chosen.
  final ExperienceLevel? experienceLevel;

  /// Names (`ReminderKind.name`) of reminder kinds the user opted
  /// into during onboarding. Stored as raw strings here (rather than
  /// importing `ReminderKind` from the notifications service) to keep
  /// this model free of a dependency on that service.
  final Set<String> remindersOptedIn;

  OnboardingProfile copyWith({
    String? name,
    Set<OnboardingGoal>? goals,
    ExperienceLevel? experienceLevel,
    Set<String>? remindersOptedIn,
  }) {
    return OnboardingProfile(
      name: name ?? this.name,
      goals: goals ?? this.goals,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      remindersOptedIn: remindersOptedIn ?? this.remindersOptedIn,
    );
  }

  Map<String, dynamic> _toJson() => {
    'name': name,
    'goals': goals.map((g) => g.name).toList(),
    'experienceLevel': experienceLevel?.name,
    'remindersOptedIn': remindersOptedIn.toList(),
  };

  static OnboardingProfile _fromJson(Map<String, dynamic> json) {
    final rawGoals = json['goals'];
    final goals = <OnboardingGoal>{};
    if (rawGoals is List) {
      for (final value in rawGoals) {
        for (final goal in OnboardingGoal.values) {
          if (goal.name == value) goals.add(goal);
        }
      }
    }

    ExperienceLevel? level;
    final rawLevel = json['experienceLevel'];
    if (rawLevel is String) {
      for (final candidate in ExperienceLevel.values) {
        if (candidate.name == rawLevel) level = candidate;
      }
    }

    final rawReminders = json['remindersOptedIn'];
    final reminders = <String>{
      if (rawReminders is List) ...rawReminders.whereType<String>(),
    };

    return OnboardingProfile(
      name: json['name'] as String?,
      goals: goals,
      experienceLevel: level,
      remindersOptedIn: reminders,
    );
  }
}

/// Persists the user's onboarding answers and whether onboarding has
/// been completed, so the flow is shown once and then skipped
/// automatically on every subsequent launch.
///
/// Follows the same `ChangeNotifier` + `SharedPreferencesAsync`
/// pattern as the app's other services (see
/// `ReminderSettingsService`), so it wires into `main.dart` the same
/// way via an `InheritedNotifier` scope.
class OnboardingService extends ChangeNotifier {
  OnboardingService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _completedKey = 'onboarding_completed';
  static const _profileKey = 'onboarding_profile';

  final SharedPreferencesAsync _preferences;

  bool _loaded = false;
  bool _completed = false;
  OnboardingProfile _profile = const OnboardingProfile();

  /// Whether [load] has completed at least once. Screens gating on
  /// [hasCompletedOnboarding] should wait for this to avoid briefly
  /// flashing the onboarding flow before persisted state arrives.
  bool get isLoaded => _loaded;

  /// Whether the user has finished (or skipped through) onboarding.
  bool get hasCompletedOnboarding => _completed;

  /// The most recently saved onboarding answers.
  OnboardingProfile get profile => _profile;

  /// Loads persisted onboarding state from disk. Safe to call more
  /// than once; callers should await this once near app startup.
  Future<void> load() async {
    final storedCompleted = await _preferences.getBool(_completedKey);
    final storedProfile = await _preferences.getString(_profileKey);

    _completed = storedCompleted ?? false;
    if (storedProfile != null && storedProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedProfile) as Map<String, dynamic>;
        _profile = OnboardingProfile._fromJson(decoded);
      } catch (_) {
        // Corrupt stored data shouldn't crash the app; fall back to
        // an empty profile rather than propagating.
        _profile = const OnboardingProfile();
      }
    }

    _loaded = true;
    notifyListeners();
  }

  /// Saves [profile] as the current in-progress or final answers,
  /// without marking onboarding complete. Useful for persisting
  /// partial progress as the user steps through the flow.
  Future<void> saveProfile(OnboardingProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _preferences.setString(_profileKey, jsonEncode(profile._toJson()));
  }

  /// Saves [profile] and marks onboarding as complete, so the flow is
  /// skipped on every future launch. Call this from the final step.
  Future<void> completeOnboarding(OnboardingProfile profile) async {
    _profile = profile;
    _completed = true;
    notifyListeners();
    await _preferences.setString(_profileKey, jsonEncode(profile._toJson()));
    await _preferences.setBool(_completedKey, true);
  }

  /// Resets onboarding so the flow is shown again on next launch,
  /// clearing saved answers too. Exposed for a "Redo onboarding" or
  /// "Reset app" control in Settings; not required for normal use.
  Future<void> resetOnboarding() async {
    _completed = false;
    _profile = const OnboardingProfile();
    notifyListeners();
    await _preferences.setBool(_completedKey, false);
    await _preferences.remove(_profileKey);
  }
}
