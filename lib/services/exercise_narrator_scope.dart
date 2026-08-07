import 'package:flutter/widgets.dart';

import 'exercise_narrator.dart';

/// Makes a single [ExerciseNarrator] instance available to the whole
/// widget tree below it — the same approach [HydrationScope] and
/// every other `*Scope` in this app use.
///
/// Deliberately typed to the abstract [ExerciseNarrator], not
/// [TtsExerciseNarrator] — every reader goes through
/// `ExerciseNarratorScope.of(context)`, which only ever hands back the
/// interface type. `main.dart` is the one place that knows the
/// current instance happens to be a [TtsExerciseNarrator]; nothing
/// below this scope does, or needs to.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `ExerciseNarratorScope.of(context)`.
class ExerciseNarratorScope extends InheritedNotifier<ExerciseNarrator> {
  const ExerciseNarratorScope({
    super.key,
    required ExerciseNarrator narrator,
    required super.child,
  }) : super(notifier: narrator);

  /// Returns the nearest [ExerciseNarrator] above [context].
  ///
  /// Registers [context] to rebuild whenever the narrator calls
  /// `notifyListeners()` (e.g. as playback advances from one segment
  /// to the next). Throws if no [ExerciseNarratorScope] is found
  /// above [context], since every screen that narrates an exercise
  /// expects one to always be present.
  static ExerciseNarrator of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ExerciseNarratorScope>();
    assert(scope != null, 'No ExerciseNarratorScope found in context');
    return scope!.notifier!;
  }
}
