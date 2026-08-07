import 'package:flutter/material.dart';

/// Thrown when an exercise's `icon` field in the JSON catalog doesn't
/// match any icon known to [exerciseIconForName].
class UnknownExerciseIconException implements Exception {
  const UnknownExerciseIconException(this.name);

  /// The unrecognized icon name from the JSON data.
  final String name;

  @override
  String toString() =>
      'UnknownExerciseIconException: no icon registered for "$name"';
}

/// Maps the plain-text icon names used in `assets/exercises.json`
/// (e.g. `"spa"`, `"self_improvement"`) to their [IconData] constant.
///
/// JSON can't carry a [IconData] value directly, so the catalog stores
/// a stable string key per exercise instead, and this map is the single
/// place that translates those keys back into real icons. Every
/// [Icons] value referenced here is a compile-time constant used
/// directly in source, so this keeps working correctly with Flutter's
/// icon tree-shaking in release builds.
///
/// Add an entry here whenever a new icon name is introduced in the
/// JSON catalog.
const Map<String, IconData> _exerciseIconsByName = {
  'expand_more': Icons.expand_more,
  'pan_tool': Icons.pan_tool,
  'psychology': Icons.psychology,
  'air': Icons.air,
  'sync': Icons.sync,
  'straighten': Icons.straighten,
  'height': Icons.height,
  'rotate_right': Icons.rotate_right,
  'accessibility_new': Icons.accessibility_new,
  'loop': Icons.loop,
  'open_in_full': Icons.open_in_full,
  'fitness_center': Icons.fitness_center,
  'waves': Icons.waves,
  'spa': Icons.spa,
  'favorite_border': Icons.favorite_border,
  'touch_app': Icons.touch_app,
  'swipe': Icons.swipe,
  'self_improvement': Icons.self_improvement,
  'crop_square': Icons.crop_square,
  'nightlight_round': Icons.nightlight_round,
  'graphic_eq': Icons.graphic_eq,
  'unfold_more': Icons.unfold_more,
  'swap_horiz': Icons.swap_horiz,
  'pets': Icons.pets,
  'accessibility': Icons.accessibility,
};

/// Looks up the [IconData] registered for [name].
///
/// Throws [UnknownExerciseIconException] if [name] isn't a recognized
/// key, so a typo or new icon in the JSON catalog fails loudly at
/// parse time rather than silently falling back to the wrong icon.
IconData exerciseIconForName(String name) {
  final icon = _exerciseIconsByName[name];
  if (icon == null) {
    throw UnknownExerciseIconException(name);
  }
  return icon;
}
