import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts which Wellness Library articles the user
/// has bookmarked.
///
/// Backed by [SharedPreferences] under a single string-list key, so
/// bookmarks survive app restarts without needing a database. State
/// is also cached in memory once loaded, so [isBookmarked] can be
/// read synchronously (e.g. from a build method) after [load]
/// completes.
///
/// A [ChangeNotifier] rather than a single-widget [State] field so
/// every [WellnessArticleCard] showing the same article stays in sync
/// the instant one of them is toggled, without needing to pass
/// callbacks up and down the widget tree. Deliberately mirrors
/// [FavoritesService]'s shape, since it solves the same problem for a
/// different collection of ids.
class LibraryBookmarksService extends ChangeNotifier {
  LibraryBookmarksService({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _storageKey = 'wellness_library_bookmarked_ids';

  final SharedPreferencesAsync _preferences;

  Set<String> _bookmarkedIds = <String>{};
  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// Loads persisted bookmarks from disk. Safe to call more than once;
  /// subsequent calls just re-sync from storage. Until this resolves,
  /// [isBookmarked] reports `false` for everything rather than
  /// throwing.
  Future<void> load() async {
    final stored = await _preferences.getStringList(_storageKey);
    _bookmarkedIds = stored?.toSet() ?? <String>{};
    _loaded = true;
    notifyListeners();
  }

  /// Whether [articleId] is currently bookmarked. Synchronous, reading
  /// from the in-memory cache.
  bool isBookmarked(String articleId) => _bookmarkedIds.contains(articleId);

  /// All currently bookmarked article ids, e.g. to filter the library
  /// down to just bookmarks.
  Set<String> get bookmarkedIds => Set.unmodifiable(_bookmarkedIds);

  /// Flips the bookmarked state of [articleId] and persists the
  /// change. Returns the new state (`true` if now bookmarked).
  Future<bool> toggle(String articleId) async {
    final nowBookmarked = !_bookmarkedIds.contains(articleId);
    if (nowBookmarked) {
      _bookmarkedIds.add(articleId);
    } else {
      _bookmarkedIds.remove(articleId);
    }
    // Update in-memory state and notify listeners immediately so the
    // bookmark icon animates right away; persistence happens right
    // after but doesn't block the UI update.
    notifyListeners();
    await _preferences.setStringList(_storageKey, _bookmarkedIds.toList());
    return nowBookmarked;
  }
}
