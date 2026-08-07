import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/exercise_icons.dart';

/// How challenging an [Exercise] is to perform.
enum ExerciseDifficulty {
  /// Suitable for first-time users; a gentle range of motion.
  beginner,

  /// Moderate effort; assumes some comfort with the basics.
  intermediate,

  /// Higher effort, resistance, or hold time.
  advanced,
}

/// The region of the body an [Exercise] primarily targets.
enum ExerciseBodyPart {
  /// Forehead and eyebrows.
  forehead,

  /// Eyes and the surrounding muscles.
  eyes,

  /// Cheeks and smile muscles.
  cheeks,

  /// Jawline and chin.
  jawline,

  /// Lips and mouth.
  lips,

  /// Neck and throat area.
  neck,

  /// Shoulders and upper back.
  shoulders,

  /// Works several facial areas at once rather than one specific region.
  fullFace,

  /// A systemic practice, such as breathing, with no single localized
  /// target.
  wholeBody,
}

/// The kind of wellness practice an [Exercise] represents.
///
/// Used to group and filter the catalog, e.g. into tabs or filter chips.
enum ExerciseCategory {
  /// Gentle release work for the jaw and chewing muscles.
  jawRelaxation,

  /// Range-of-motion and posture drills for the neck.
  neckMobility,

  /// Posture-focused strengthening and mobility for the shoulders.
  shoulderPosture,

  /// Hands-on massage techniques for the face.
  facialMassage,

  /// Guided breathing patterns for relaxation and stress relief.
  breathing,

  /// Static and flowing stretches that complement the categories above.
  stretching,
}

/// A single guided facial-fitness exercise.
///
/// Immutable: every field is `final`, there are no setters, and the
/// `final` class modifier keeps code in other files from extending or
/// implementing it, so nothing can quietly reintroduce mutable state.
/// To change a value — for example flipping [completed] once the user
/// finishes — call [copyWith] to derive a new instance rather than
/// mutating this one.
///
/// The constructor is `const`, so a fixed exercise catalog can be
/// declared as compile-time constants. That does mean [instructions]
/// and [precautions] are stored as-is rather than defensively copied,
/// so pass list literals (ideally `const` ones) rather than a mutable
/// list you intend to keep changing elsewhere.
@immutable
final class Exercise {
  const Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.difficulty,
    required this.bodyPart,
    required this.category,
    required this.icon,
    required this.instructions,
    this.precautions = const [],
    this.completed = false,
    this.videoAsset,
  });

  /// Stable unique identifier, e.g. `'cheek-lifter'`.
  final String id;

  /// Short display name, e.g. `'Cheek Lifter'`.
  final String title;

  /// One or two sentence summary shown in lists and cards.
  final String description;

  /// How long a single round of this exercise takes.
  final Duration duration;

  /// How challenging this exercise is.
  final ExerciseDifficulty difficulty;

  /// The primary area this exercise targets.
  final ExerciseBodyPart bodyPart;

  /// The wellness category this exercise belongs to, e.g. for grouping
  /// into tabs or filter chips.
  final ExerciseCategory category;

  /// Icon representing the exercise, e.g. in cards and list tiles.
  final IconData icon;

  /// Ordered, step-by-step guidance for performing the exercise.
  final List<String> instructions;

  /// Safety notes or contraindications to surface before starting.
  /// Empty when there's nothing special to call out.
  final List<String> precautions;

  /// Whether the user has marked this exercise as done, e.g. as part
  /// of today's routine or their overall progress.
  final bool completed;

  /// Bundled asset path for this exercise's short, silent, looping
  /// demonstration clip, e.g. `'assets/videos/jaw-release-drop.mp4'`
  /// — `null` for the exercises that don't have one yet. Shown by
  /// [ExerciseVideoPreview] on [ExerciseDetailsScreen]. Deliberately
  /// separate from [ExerciseDemonstrationView]'s abstract animated
  /// shape (`lib/data/exercise_demonstrations.dart`), which remains
  /// [GuidedSessionScreen]'s in-session visual and isn't affected by
  /// this field at all.
  final String? videoAsset;

  /// A single representative still frame from [videoAsset], pre-cropped
  /// to a square, for the circular icon badge on [ExerciseCard] and
  /// [ExerciseDetailsScreen] — `null` wherever [videoAsset] is.
  ///
  /// Computed rather than stored: both files are generated together
  /// (see the video-import tooling notes in the repo), always live
  /// under the same id, and only differ by folder and extension, so
  /// storing a second, independently-editable path in
  /// `assets/exercises.json` would just be another way for the two to
  /// silently drift apart. Deriving it here instead means there's
  /// exactly one place — this getter — that encodes the
  /// `assets/videos/<id>.mp4` → `assets/thumbnails/<id>.jpg`
  /// convention, and every caller automatically stays correct if that
  /// convention is ever revisited.
  String? get thumbnailAsset {
    final video = videoAsset;
    if (video == null) return null;
    return video
        .replaceFirst('assets/videos/', 'assets/thumbnails/')
        .replaceFirst(RegExp(r'\.mp4$'), '.jpg');
  }

  /// Builds an [Exercise] from a decoded JSON object, as read from
  /// `assets/exercises.json`.
  ///
  /// Expects `durationSeconds` as an integer, `difficulty`/`bodyPart`/
  /// `category` as the corresponding enum's [Object.toString]-free name
  /// (e.g. `'beginner'`, `'jawline'`, `'jawRelaxation'`), and `icon` as
  /// one of the names registered in [exerciseIconForName]. Throws a
  /// [FormatException] if a required field is missing or malformed, or
  /// an [UnknownExerciseIconException] if `icon` isn't recognized, so
  /// callers can surface a clear loading error rather than crash with
  /// a confusing type-cast failure deep in the UI.
  factory Exercise.fromJson(Map<String, dynamic> json) {
    T require<T>(String key) {
      final value = json[key];
      if (value == null) {
        throw FormatException('Missing required field "$key"', json);
      }
      if (value is! T) {
        throw FormatException(
          'Field "$key" should be a $T but was ${value.runtimeType}',
          json,
        );
      }
      return value;
    }

    final durationSeconds = require<int>('durationSeconds');
    final difficultyName = require<String>('difficulty');
    final bodyPartName = require<String>('bodyPart');
    final categoryName = require<String>('category');
    final iconName = require<String>('icon');

    ExerciseDifficulty difficulty;
    try {
      difficulty = ExerciseDifficulty.values.byName(difficultyName);
    } on ArgumentError {
      throw FormatException('Unknown difficulty "$difficultyName"', json);
    }

    ExerciseBodyPart bodyPart;
    try {
      bodyPart = ExerciseBodyPart.values.byName(bodyPartName);
    } on ArgumentError {
      throw FormatException('Unknown bodyPart "$bodyPartName"', json);
    }

    ExerciseCategory category;
    try {
      category = ExerciseCategory.values.byName(categoryName);
    } on ArgumentError {
      throw FormatException('Unknown category "$categoryName"', json);
    }

    final instructionsRaw = json['instructions'];
    if (instructionsRaw is! List) {
      throw FormatException(
        'Field "instructions" should be a list but was '
        '${instructionsRaw.runtimeType}',
        json,
      );
    }

    final precautionsRaw = json['precautions'];
    if (precautionsRaw != null && precautionsRaw is! List) {
      throw FormatException(
        'Field "precautions" should be a list but was '
        '${precautionsRaw.runtimeType}',
        json,
      );
    }

    final videoAssetRaw = json['videoAsset'];
    if (videoAssetRaw != null && videoAssetRaw is! String) {
      throw FormatException(
        'Field "videoAsset" should be a String but was '
        '${videoAssetRaw.runtimeType}',
        json,
      );
    }

    return Exercise(
      id: require<String>('id'),
      title: require<String>('title'),
      description: require<String>('description'),
      duration: Duration(seconds: durationSeconds),
      difficulty: difficulty,
      bodyPart: bodyPart,
      category: category,
      icon: exerciseIconForName(iconName),
      instructions: List<String>.from(instructionsRaw),
      precautions: precautionsRaw == null
          ? const []
          : List<String>.from(precautionsRaw),
      completed: json['completed'] as bool? ?? false,
      videoAsset: videoAssetRaw as String?,
    );
  }

  /// Serializes this exercise back to the JSON shape [Exercise.fromJson]
  /// expects. Not currently used by the app (the catalog is read-only),
  /// but kept alongside [fromJson] so the two stay in sync.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'durationSeconds': duration.inSeconds,
      'difficulty': difficulty.name,
      'bodyPart': bodyPart.name,
      'category': category.name,
      'instructions': instructions,
      'precautions': precautions,
      'completed': completed,
      if (videoAsset != null) 'videoAsset': videoAsset,
    };
  }

  /// Returns a copy of this exercise with the given fields replaced.
  ///
  /// Like every other field here, [videoAsset] follows the standard
  /// `param ?? this.field` pattern — so, unlike the rest, there's no
  /// way to pass `videoAsset: null` to explicitly *clear* an existing
  /// value (it just falls through to the current one instead). Not
  /// worth the extra complexity of a sentinel-based "explicit null"
  /// pattern for this: the catalog is read-only after being parsed
  /// from JSON, so nothing in the app actually needs to un-set a
  /// video at runtime.
  Exercise copyWith({
    String? id,
    String? title,
    String? description,
    Duration? duration,
    ExerciseDifficulty? difficulty,
    ExerciseBodyPart? bodyPart,
    ExerciseCategory? category,
    IconData? icon,
    List<String>? instructions,
    List<String>? precautions,
    bool? completed,
    String? videoAsset,
  }) {
    return Exercise(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      difficulty: difficulty ?? this.difficulty,
      bodyPart: bodyPart ?? this.bodyPart,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      instructions: instructions ?? this.instructions,
      precautions: precautions ?? this.precautions,
      completed: completed ?? this.completed,
      videoAsset: videoAsset ?? this.videoAsset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exercise &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.duration == duration &&
        other.difficulty == difficulty &&
        other.bodyPart == bodyPart &&
        other.category == category &&
        other.icon == icon &&
        listEquals(other.instructions, instructions) &&
        listEquals(other.precautions, precautions) &&
        other.completed == completed &&
        other.videoAsset == videoAsset;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        duration,
        difficulty,
        bodyPart,
        category,
        icon,
        Object.hashAll(instructions),
        Object.hashAll(precautions),
        completed,
        videoAsset,
      );

  @override
  String toString() {
    return 'Exercise(id: $id, title: $title, difficulty: $difficulty, '
        'bodyPart: $bodyPart, category: $category, duration: $duration, '
        'completed: $completed)';
  }
}
