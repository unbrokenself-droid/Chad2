import 'package:flutter/foundation.dart';

/// A single section within a [LegalDocument] — a heading paired with
/// prose, a bullet list, or both (prose first, then bullets).
@immutable
class LegalDocumentSection {
  const LegalDocumentSection({
    required this.heading,
    this.body,
    this.bullets = const [],
  });

  final String heading;

  /// Paragraph text for this section. Optional — a section can be
  /// bullets-only (see [bullets]), body-only, or both.
  final String? body;

  /// Bullet list items shown after [body], if any.
  final List<String> bullets;
}

/// A full legal document (Privacy Policy, Terms of Service) bundled
/// with the app and rendered by `LegalDocumentScreen`.
///
/// Deliberately bundled as plain Dart data — like
/// `WellnessLibraryContent` — rather than fetched, so it's available
/// offline and doesn't depend on an external URL staying up. That
/// said, having it *only* in-app isn't the whole compliance picture:
/// Google Play's own listing requires a Privacy Policy URL as a
/// separate, publicly-hosted page, independent of what's shown inside
/// the app. See `LegalDocumentConfig`'s doc comment.
@immutable
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  final String title;

  /// Display string for the "Last updated" line, e.g. `'July 26,
  /// 2026'`. Update this every time the document's content changes —
  /// Play policy requires the policy to stay current, and a stale
  /// date is a visible sign it wasn't.
  final String lastUpdated;

  /// Short paragraph shown before the first section.
  final String intro;

  final List<LegalDocumentSection> sections;
}
