import 'package:flutter/material.dart';

import '../../models/exercise.dart';

/// The content painted inside an exercise's circular icon badge: a
/// cropped still from [Exercise.thumbnailAsset] when one exists, or
/// [Exercise.icon] as a fallback for the exercises that don't have a
/// video yet.
///
/// Used inside [ExerciseCard]'s badge widgets and
/// [ExerciseDetailsScreen]'s header badge — both ends of the
/// [Hero] flight between the two screens — so the thumbnail-or-icon
/// decision lives in exactly one place rather than three. Doesn't
/// draw the surrounding circle itself (background color, size,
/// completed-state border): each call site keeps owning that, since
/// the two screens' badges differ in size and only the card's
/// animates a completed ring — this widget only ever decides what
/// goes *inside* whatever circle it's handed.
class ExerciseBadgeContent extends StatelessWidget {
  const ExerciseBadgeContent({
    super.key,
    required this.exercise,
    required this.size,
    required this.iconSize,
    required this.color,
  });

  final Exercise exercise;

  /// Side length of the circular area this content fills — needed
  /// so the thumbnail image can be sized to exactly match rather
  /// than relying on its intrinsic (source-file) dimensions.
  final double size;

  /// Icon size used for the fallback [Exercise.icon], independent of
  /// [size] since an icon glyph and a photo fill their circle
  /// differently — matches each call site's previous icon size.
  final double iconSize;

  final Color color;

  @override
  Widget build(BuildContext context) {
    final thumbnail = exercise.thumbnailAsset;
    if (thumbnail == null) {
      return Icon(exercise.icon, color: color, size: iconSize);
    }
    return ClipOval(
      child: Image.asset(
        thumbnail,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A missing or corrupt thumbnail shouldn't take the badge
        // down with it — fall back to the icon, same as if there'd
        // been no thumbnail listed at all.
        errorBuilder: (context, error, stackTrace) =>
            Icon(exercise.icon, color: color, size: iconSize),
      ),
    );
  }
}
