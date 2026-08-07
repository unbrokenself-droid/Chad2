import 'package:flutter/foundation.dart';

/// A user-created, named collection of exercises.
///
/// Unlike [DailyRoutineService]'s automatically generated daily plan,
/// a [CustomRoutine] is entirely user-authored: the user picks its
/// name and its exercises, in whatever order they like, and it
/// persists indefinitely (not just for the current calendar day)
/// until they delete it.
///
/// Only exercise ids are stored, not full [Exercise] objects — the
/// catalog itself is the source of truth for everything else about an
/// exercise, so a routine just remembers *which* exercises and in
/// *what order*. Resolving ids back to [Exercise]s happens in the UI
/// layer, the same way [DailyRoutineService] does it.
@immutable
final class CustomRoutine {
  const CustomRoutine({
    required this.id,
    required this.name,
    required this.exerciseIds,
    required this.createdAt,
  });

  /// Stable unique identifier, generated once when the routine is
  /// created and never reused.
  final String id;

  /// User-chosen display name, e.g. "Morning Routine". Never empty —
  /// callers are expected to validate/trim before constructing this.
  final String name;

  /// Ordered exercise ids making up this routine. May contain
  /// duplicates if the user deliberately adds the same exercise
  /// twice (e.g. for two rounds); nothing in this model prevents
  /// that.
  final List<String> exerciseIds;

  /// When this routine was first created. Not shown prominently in
  /// the UI today, but kept so routines have a stable, meaningful
  /// default sort order (oldest first) if one is ever needed.
  final DateTime createdAt;

  /// Builds a [CustomRoutine] from a decoded JSON object, as read
  /// from local storage. Throws a [FormatException] if a required
  /// field is missing or malformed.
  factory CustomRoutine.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final exerciseIdsRaw = json['exerciseIds'];
    final createdAtRaw = json['createdAt'];

    if (id is! String || id.isEmpty) {
      throw FormatException('Missing or invalid "id" field', json);
    }
    if (name is! String) {
      throw FormatException('Missing or invalid "name" field', json);
    }
    if (exerciseIdsRaw is! List) {
      throw FormatException('Missing or invalid "exerciseIds" field', json);
    }
    if (createdAtRaw is! String) {
      throw FormatException('Missing or invalid "createdAt" field', json);
    }

    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw FormatException('Invalid "createdAt" timestamp', json);
    }

    return CustomRoutine(
      id: id,
      name: name,
      exerciseIds: List<String>.from(exerciseIdsRaw),
      createdAt: createdAt,
    );
  }

  /// Serializes this routine back to the JSON shape
  /// [CustomRoutine.fromJson] expects.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'exerciseIds': exerciseIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Returns a copy of this routine with the given fields replaced.
  CustomRoutine copyWith({
    String? id,
    String? name,
    List<String>? exerciseIds,
    DateTime? createdAt,
  }) {
    return CustomRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      exerciseIds: exerciseIds ?? this.exerciseIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomRoutine &&
        other.id == id &&
        other.name == name &&
        listEquals(other.exerciseIds, exerciseIds) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(exerciseIds), createdAt);

  @override
  String toString() {
    return 'CustomRoutine(id: $id, name: $name, '
        'exerciseIds: $exerciseIds, createdAt: $createdAt)';
  }
}
