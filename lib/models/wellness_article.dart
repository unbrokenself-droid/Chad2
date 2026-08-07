import 'package:flutter/material.dart';

/// The topic an [WellnessArticle] belongs to, used for filtering and
/// grouping the Wellness Library.
///
/// Deliberately mirrors the app's existing exercise-facing language
/// (jaw, neck, posture) so the library reads as part of the same
/// system as the Exercises tab, while also covering topics that have
/// no corresponding exercise category (hydration, skincare, recovery).
enum WellnessTopic {
  /// Releasing tension held in the jaw and chewing muscles.
  jawRelaxation,

  /// Range of motion and gentle mobility work for the neck.
  neckMobility,

  /// Everyday posture habits for sitting, standing, and screen use.
  healthyPosture,

  /// Water intake and general hydration habits.
  hydration,

  /// Simple, non-prescriptive skincare fundamentals.
  basicSkincare,

  /// Rest, sleep, and recovery between sessions.
  recovery,
}

/// Human-readable labels and icons for [WellnessTopic].
extension WellnessTopicLabel on WellnessTopic {
  String get label {
    switch (this) {
      case WellnessTopic.jawRelaxation:
        return 'Jaw Relaxation';
      case WellnessTopic.neckMobility:
        return 'Neck Mobility';
      case WellnessTopic.healthyPosture:
        return 'Healthy Posture';
      case WellnessTopic.hydration:
        return 'Hydration';
      case WellnessTopic.basicSkincare:
        return 'Basic Skincare';
      case WellnessTopic.recovery:
        return 'Recovery';
    }
  }

  /// Short label for compact filter chips.
  String get chipLabel {
    switch (this) {
      case WellnessTopic.jawRelaxation:
        return 'Jaw';
      case WellnessTopic.neckMobility:
        return 'Neck';
      case WellnessTopic.healthyPosture:
        return 'Posture';
      case WellnessTopic.hydration:
        return 'Hydration';
      case WellnessTopic.basicSkincare:
        return 'Skincare';
      case WellnessTopic.recovery:
        return 'Recovery';
    }
  }

  IconData get icon {
    switch (this) {
      case WellnessTopic.jawRelaxation:
        return Icons.face_retouching_natural;
      case WellnessTopic.neckMobility:
        return Icons.accessibility_new;
      case WellnessTopic.healthyPosture:
        return Icons.airline_seat_recline_normal;
      case WellnessTopic.hydration:
        return Icons.water_drop;
      case WellnessTopic.basicSkincare:
        return Icons.spa;
      case WellnessTopic.recovery:
        return Icons.bedtime;
    }
  }
}

/// A single section within an [WellnessArticle]'s body — a short
/// heading paired with a few sentences of body text.
///
/// Kept deliberately small (a heading and a paragraph) rather than a
/// single long block of text, so an expanded card reads as a few
/// scannable chunks instead of a wall of text on a small screen.
@immutable
class ArticleSection {
  const ArticleSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

/// A single educational article in the Wellness Library.
///
/// All content is bundled with the app (see [WellnessLibraryContent])
/// rather than fetched from a server, so the library works fully
/// offline. Deliberately general and habit-focused — no diagnostic,
/// prescriptive, or outcome-guaranteeing language — since this is
/// educational content, not medical or cosmetic advice.
@immutable
class WellnessArticle {
  const WellnessArticle({
    required this.id,
    required this.topic,
    required this.title,
    required this.summary,
    required this.readMinutes,
    required this.sections,
    this.tags = const [],
  });

  /// Stable identifier, used as the bookmark key. Never shown in the
  /// UI and never reused between articles.
  final String id;

  final WellnessTopic topic;

  /// The article's title, shown on its collapsed card.
  final String title;

  /// A one- to two-sentence teaser shown on the collapsed card.
  final String summary;

  /// Approximate reading time, shown as "X min read".
  final int readMinutes;

  /// The article's body, broken into short headed sections, revealed
  /// when the card is expanded.
  final List<ArticleSection> sections;

  /// Extra freeform keywords that broaden search matching beyond the
  /// title and summary (e.g. "TMJ", "screen time", "SPF").
  final List<String> tags;

  /// Whether [query] matches this article's title, summary, tags, or
  /// topic label. Case-insensitive; blank queries match everything.
  bool matches(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return true;
    return title.toLowerCase().contains(trimmed) ||
        summary.toLowerCase().contains(trimmed) ||
        topic.label.toLowerCase().contains(trimmed) ||
        tags.any((tag) => tag.toLowerCase().contains(trimmed));
  }
}
