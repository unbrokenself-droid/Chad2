import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which featured [WorkoutCollection]s a non-Premium user has
/// unlocked by watching a rewarded ad — see [AdsManager.showRewardedAd]
/// and [WorkoutUnlockSheet], which together are the only place
/// [unlock] gets called.
///
/// Deliberately separate from [PremiumService]: Premium unlocks
/// *everything*, permanently, the instant it's active — that's
/// [PremiumService.isPremium], checked directly wherever a lock would
/// otherwise show (see [WorkoutCollectionCard]/
/// [WorkoutCollectionDetailsScreen]) — while this service only ever
/// grants one specific collection at a time, and stays relevant even
/// for someone who's unlocked several individual workouts this way
/// but never gone Premium. A collection ID showing up here doesn't
/// mean anything once Premium is active; callers check Premium first
/// and only fall back to this for the non-Premium case.
class WorkoutUnlockService extends ChangeNotifier {
  WorkoutUnlockService({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _storageKey = 'workout_unlocked_collection_ids';

  final SharedPreferencesAsync _preferences;

  Set<String> _unlockedIds = const {};
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Loads every previously-unlocked collection ID from disk. Safe to
  /// call more than once.
  Future<void> load() async {
    final stored = await _preferences.getString(_storageKey);
    _unlockedIds = _decode(stored);
    _loaded = true;
    notifyListeners();
  }

  static Set<String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw) as List;
      return Set<String>.from(decoded);
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as if nothing were stored.
      return const {};
    }
  }

  /// Whether [collectionId] has been unlocked via a completed
  /// rewarded ad. Callers should check [PremiumService.isPremium]
  /// *first* — a Premium user has never needed to call [unlock] at
  /// all, and this returning `false` for them doesn't mean anything
  /// is actually locked.
  bool isUnlocked(String collectionId) => _unlockedIds.contains(collectionId);

  /// Permanently unlocks [collectionId] for this device — called only
  /// after [AdsManager.showRewardedAd] resolves to
  /// [RewardedAdResult.rewarded], never speculatively before the
  /// reward is confirmed.
  Future<void> unlock(String collectionId) async {
    if (_unlockedIds.contains(collectionId)) return;
    _unlockedIds = {..._unlockedIds, collectionId};
    notifyListeners();
    await _preferences.setString(_storageKey, jsonEncode(_unlockedIds.toList()));
  }
}
