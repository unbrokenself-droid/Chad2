# models

Data models and entities (plain Dart classes representing core data such as
exercises, routines, or user profiles).

- `exercise.dart` — the `Exercise` model, plus its `ExerciseDifficulty`,
  `ExerciseBodyPart`, and `ExerciseCategory` enums.
- `legal_document.dart` — `LegalDocument` and `LegalDocumentSection`,
  the plain-data shape the Privacy Policy and Terms of Service are
  modeled as (see `lib/data/legal_documents.dart` for the actual
  content, `lib/screens/legal_document_screen.dart` for how it's
  rendered).
- `exercise_demonstration.dart` — `DemonstrationKeyframe` and
  `ExerciseDemonstration` (a looping sequence of target poses) plus
  `DemonstrationPose` (one interpolated frame) and the interpolation
  logic itself (`ExerciseDemonstration.poseAt`). Linked to an
  `Exercise` by ID rather than being a field on it — see
  `lib/data/exercise_demonstrations.dart` for why, and for the actual
  content.
