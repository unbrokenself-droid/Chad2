import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/custom_routine.dart';

/// Manages the user's custom, hand-built routines: creating, renaming,
/// and deleting whole routines, plus adding, removing, and reordering
/// the exercises within one.
///
/// Persisted via [SharedPreferences] as a single JSON-encoded list, the
/// same lightweight local-storage approach [DailyRoutineService] and
/// [FavoritesService] use — there's no backend, so "saving" just means
/// writing to disk on this device. State is also cached in memory once
/// loaded, so [routines] can be read synchronously (e.g. from a build
/// method) after [load] completes.
///
/// A [ChangeNotifier] so every screen showing custom routines (a list
/// screen, a routine's detail screen, any future "add to routine"
/// picker) stays in sync the instant one of them changes something.
class CustomRoutinesService extends ChangeNotifier {
  CustomRoutinesService({SharedPreferencesAsync? preferences, Random? random})
      : _preferences = preferences ?? SharedPreferencesAsync(),
        _random = random ?? Random();

  static const String _storageKey = 'custom_routines';

  final SharedPreferencesAsync _preferences;
  final Random _random;

  List<CustomRoutine> _routines = const [];
  bool _loaded = false;

  /// Whether [load] has completed at least once. Screens can use this
  /// to distinguish "nothing created yet because we're still starting
  /// up" from "genuinely no routines".
  bool get isLoaded => _loaded;

  /// Every custom routine, in creation order (oldest first). Empty
  /// until [load] completes or before anything has been created.
  List<CustomRoutine> get routines => List.unmodifiable(_routines);

  /// Loads persisted routines from disk. Safe to call more than once
  /// (e.g. defensively from multiple screens); subsequent calls just
  /// re-sync from storage.
  Future<void> load() async {
    final stored = await _preferences.getString(_storageKey);
    _routines = _decode(stored);
    _loaded = true;
    notifyListeners();
  }

  static List<CustomRoutine> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final routines = <CustomRoutine>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          routines.add(CustomRoutine.fromJson(entry));
        } catch (_) {
          // Skip a single corrupt entry rather than discarding every
          // other routine because of it.
        }
      }
      return routines;
    } catch (_) {
      // Corrupt or unexpected stored data shouldn't crash the app;
      // treat it as if nothing were stored.
      return const [];
    }
  }

  Future<void> _persist() async {
    final encoded = jsonEncode([for (final r in _routines) r.toJson()]);
    await _preferences.setString(_storageKey, encoded);
  }

  /// Looks up a single routine by [id], or `null` if no routine with
  /// that id exists (e.g. it was deleted from another screen).
  CustomRoutine? routineById(String id) {
    for (final routine in _routines) {
      if (routine.id == id) return routine;
    }
    return null;
  }

  String _generateId() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(1 << 32);
    return 'routine-$stamp-$salt';
  }

  /// Creates a new, empty routine named [name] and persists it.
  /// [name] is trimmed; if trimming leaves it empty, falls back to
  /// "New Routine" rather than allowing a blank name. Returns the
  /// created routine so the caller can navigate straight to it.
  Future<CustomRoutine> createRoutine(String name) async {
    final trimmed = name.trim();
    final routine = CustomRoutine(
      id: _generateId(),
      name: trimmed.isEmpty ? 'New Routine' : trimmed,
      exerciseIds: const [],
      createdAt: DateTime.now(),
    );
    _routines = List.unmodifiable([..._routines, routine]);
    notifyListeners();
    await _persist();
    return routine;
  }

  /// Renames [routineId] to [newName] and persists the change.
  /// [newName] is trimmed; a blank result is ignored (the routine
  /// keeps its previous name) rather than allowing an empty title.
  /// No-op if no routine with [routineId] exists.
  Future<void> renameRoutine(String routineId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final index = _routines.indexWhere((r) => r.id == routineId);
    if (index == -1) return;
    final updated = List<CustomRoutine>.of(_routines);
    updated[index] = updated[index].copyWith(name: trimmed);
    _routines = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
  }

  /// Permanently deletes [routineId] and persists the change. No-op
  /// if no routine with [routineId] exists.
  Future<void> deleteRoutine(String routineId) async {
    final index = _routines.indexWhere((r) => r.id == routineId);
    if (index == -1) return;
    final updated = List<CustomRoutine>.of(_routines)..removeAt(index);
    _routines = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
  }

  /// Appends [exerciseId] to the end of [routineId]'s exercise list
  /// and persists the change. Duplicates are allowed (the same
  /// exercise can appear more than once, e.g. for two rounds), so
  /// this doesn't check for an existing entry. No-op if no routine
  /// with [routineId] exists.
  Future<void> addExercise(String routineId, String exerciseId) async {
    final index = _routines.indexWhere((r) => r.id == routineId);
    if (index == -1) return;
    final routine = _routines[index];
    final updatedIds = List<String>.of(routine.exerciseIds)..add(exerciseId);
    final updated = List<CustomRoutine>.of(_routines);
    updated[index] = routine.copyWith(exerciseIds: updatedIds);
    _routines = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
  }

  /// Removes the exercise at [exerciseIndex] from [routineId]'s
  /// exercise list and persists the change. Uses a position rather
  /// than an id so removing one occurrence of a duplicated exercise
  /// doesn't remove all of them. No-op if [routineId] doesn't exist
  /// or [exerciseIndex] is out of range.
  Future<void> removeExerciseAt(String routineId, int exerciseIndex) async {
    final index = _routines.indexWhere((r) => r.id == routineId);
    if (index == -1) return;
    final routine = _routines[index];
    if (exerciseIndex < 0 || exerciseIndex >= routine.exerciseIds.length) {
      return;
    }
    final updatedIds = List<String>.of(routine.exerciseIds)
      ..removeAt(exerciseIndex);
    final updated = List<CustomRoutine>.of(_routines);
    updated[index] = routine.copyWith(exerciseIds: updatedIds);
    _routines = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
  }

  /// Moves the exercise at [oldIndex] in [routineId]'s exercise list
  /// to [newIndex] and persists the change. Mirrors the semantics
  /// [ReorderableListView.onReorder] expects: [newIndex] is the
  /// target index *before* the moved item is removed from its old
  /// position, so callers can pass the callback's arguments straight
  /// through. No-op if [routineId] doesn't exist or either index is
  /// out of range.
  Future<void> reorderExercise(
    String routineId,
    int oldIndex,
    int newIndex,
  ) async {
    final index = _routines.indexWhere((r) => r.id == routineId);
    if (index == -1) return;
    final routine = _routines[index];
    final ids = routine.exerciseIds;
    if (oldIndex < 0 ||
        oldIndex >= ids.length ||
        newIndex < 0 ||
        newIndex > ids.length) {
      return;
    }
    final updatedIds = List<String>.of(ids);
    final moved = updatedIds.removeAt(oldIndex);
    var insertAt = newIndex;
    if (oldIndex < newIndex) {
      // Removing the item above the target shifts everything after
      // it up by one, so the target index needs the same adjustment.
      insertAt -= 1;
    }
    updatedIds.insert(insertAt.clamp(0, updatedIds.length), moved);
    final updated = List<CustomRoutine>.of(_routines);
    updated[index] = routine.copyWith(exerciseIds: updatedIds);
    _routines = List.unmodifiable(updated);
    notifyListeners();
    await _persist();
  }
}
