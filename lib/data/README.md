# data

Static, non-networked content and helpers bundled directly with the
app — the exercise catalog's supporting data, plus other content that
needs to work fully offline and never depends on a server response.

- `exercise_icons.dart` — maps the plain-text icon names used in
  `assets/exercises.json` (e.g. `"spa"`) to their `IconData` constant,
  so JSON can reference an icon without needing to encode one
  directly.
- `legal_documents.dart` — the actual Privacy Policy and Terms of
  Service content, as `LegalDocument` values (see
  `lib/models/legal_document.dart`). Also defines
  `LegalDocumentConfig` — a handful of values (support email,
  developer/company name, governing law, publish date) that
  genuinely can't be known from the code and are left as explicit
  `TODO` placeholders rather than guessed. Read that class's doc
  comment before publishing either document: bundling this content
  in-app is necessary but **not sufficient** for Play Store
  submission — the Play Console listing separately requires a
  Privacy Policy URL hosted on a real, public webpage.
- `exercise_demonstrations.dart` — looping movement demonstrations
  for a handful of exercises, as `ExerciseDemonstration` values keyed
  by `Exercise.id` (see `lib/models/exercise_demonstration.dart`).
  Read this file's doc comment before assuming it's more than it is:
  these are code-drawn animated diagrams, not illustrated artwork or
  video.

The exercise catalog itself now lives in `assets/exercises.json` (25
entries covering all six `ExerciseCategory` values: jaw relaxation,
neck mobility, shoulder posture, facial massage, breathing, and
stretching) and is loaded asynchronously via
`ExerciseRepository.loadExercises()` in `lib/services/`. There is no
backend yet — this is still local, bundled content — but it's no
longer compiled into Dart source as constants, so it can be edited
without a rebuild and can be swapped for a real API later.
