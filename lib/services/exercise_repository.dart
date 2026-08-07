import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/exercise.dart';

/// Thrown when the exercise catalog can't be loaded or parsed.
///
/// Wraps whatever underlying error occurred (a missing asset, invalid
/// JSON, a malformed entry, ...) behind one exception type with a
/// human-readable [message], so callers — typically a loading screen —
/// have a single, simple type to catch and a message they can show
/// directly to the user.
class ExerciseLoadException implements Exception {
  const ExerciseLoadException(this.message, [this.cause]);

  /// A short, user-facing description of what went wrong.
  final String message;

  /// The lower-level error that triggered this exception, if any
  /// (e.g. a [FormatException] from `jsonDecode`). Useful for logging;
  /// not intended to be shown to the user.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'ExerciseLoadException: $message'
      : 'ExerciseLoadException: $message (cause: $cause)';
}

/// Loads the app's exercise catalog from the bundled
/// `assets/exercises.json` asset.
///
/// This is the only source of exercise data in the app — there is no
/// backend yet, so "loading" just means reading and parsing a local
/// asset, but it's kept behind this repository so a real API-backed
/// implementation could be swapped in later without touching any
/// screen.
class ExerciseRepository {
  const ExerciseRepository({AssetBundle? bundle}) : _bundle = bundle;

  /// Overridable for tests; defaults to [rootBundle] otherwise.
  final AssetBundle? _bundle;

  static const String _assetPath = 'assets/exercises.json';

  /// Reads and parses the exercise catalog.
  ///
  /// Throws an [ExerciseLoadException] if the asset is missing, isn't
  /// valid JSON, isn't a JSON array, or contains an entry [Exercise
  /// .fromJson] can't parse — callers should catch this specifically
  /// (rather than a bare `catch (e)`) so a genuine programming error
  /// elsewhere doesn't get silently treated as a "couldn't load data"
  /// state.
  Future<List<Exercise>> loadExercises() async {
    final String raw;
    try {
      raw = await (_bundle ?? rootBundle).loadString(_assetPath);
    } catch (error) {
      throw ExerciseLoadException(
        'Could not find the exercise catalog file.',
        error,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw ExerciseLoadException(
        'The exercise catalog file is not valid JSON.',
        error,
      );
    }

    if (decoded is! List) {
      throw ExerciseLoadException(
        'The exercise catalog file should contain a JSON array, but '
        'found a ${decoded.runtimeType}.',
      );
    }

    final exercises = <Exercise>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) {
        throw ExerciseLoadException(
          'Each exercise entry should be a JSON object, but found a '
          '${entry.runtimeType}.',
        );
      }
      try {
        exercises.add(Exercise.fromJson(entry));
      } catch (error) {
        final id = entry['id'];
        throw ExerciseLoadException(
          'Could not parse exercise'
          '${id is String ? ' "$id"' : ''} from the catalog file.',
          error,
        );
      }
    }

    return List.unmodifiable(exercises);
  }
}
