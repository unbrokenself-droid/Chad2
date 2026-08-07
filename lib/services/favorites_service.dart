import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts which exercises the user has favorited.
///
/// Backed by [SharedPreferences] under a single string-list key, so
/// favorites survive app restarts without needing a database. State is
/// also cached in memory once loaded, so [isFavorite] can be read
/// synchronously (e.g. from a build method) after [load] completes.
///
/// A [ChangeNotifier] rather than a single-widget [State] field so
/// every [ExerciseCard]/details screen showing the same exercise stays
/// in sync the instant one of them is toggled, without needing to pass
/// callbacks up and down the widget tree.
class FavoritesService extends ChangeNotifier {
  FavoritesService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _storageKey = 'favorite_exercise_ids';

  final SharedPreferencesAsync _preferences;

  Set<String> _favoriteIds = <String>{};
  bool _loaded = false;

  /// Whether [load] has completed at least once. Callers that need to
  /// read favorites before the app's first frame (rare) can await
  /// [load] directly instead of checking this.
  bool get isLoaded => _loaded;

  /// Loads persisted favorites from disk. Safe to call more than once
  /// (e.g. defensively from multiple screens); subsequent calls just
  /// re-sync from storage. Callers should await this once near app
  /// startup — until it resolves, [isFavorite] reports `false` for
  /// everything rather than throwing.
  Future<void> load() async {
    final stored = await _preferences.getStringList(_storageKey);
    _favoriteIds = stored?.toSet() ?? <String>{};
    _loaded = true;
    notifyListeners();
  }

  /// Whether [exerciseId] is currently favorited. Synchronous, reading
  /// from the in-memory cache — reports `false` for everything until
  /// [load] has completed once.
  bool isFavorite(String exerciseId) => _favoriteIds.contains(exerciseId);

  /// All currently favorited exercise ids, e.g. to filter a catalog
  /// list down to just favorites.
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);

  /// Flips the favorited state of [exerciseId] and persists the
  /// change. Returns the new state (`true` if now favorited).
  Future<bool> toggle(String exerciseId) async {
    final nowFavorite = !_favoriteIds.contains(exerciseId);
    if (nowFavorite) {
      _favoriteIds.add(exerciseId);
    } else {
      _favoriteIds.remove(exerciseId);
    }
    // Update in-memory state and notify listeners immediately so the
    // heart animates right away; persistence happens right after but
    // doesn't block the UI update.
    notifyListeners();
    await _preferences.setStringList(_storageKey, _favoriteIds.toList());
    return nowFavorite;
  }
}
