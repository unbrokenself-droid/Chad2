import 'package:flutter/widgets.dart';

import 'exercise_completion_service.dart';

/// Makes a single [ExerciseCompletionService] instance available to
/// the whole widget tree below it, without pulling in a
/// state-management package — the same approach [FavoritesScope] uses
/// for favorites.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `CompletionScope.of(context)`.
class CompletionScope extends InheritedNotifier<ExerciseCompletionService> {
  const CompletionScope({
    super.key,
    required ExerciseCompletionService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [ExerciseCompletionService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after an exercise is marked complete
  /// elsewhere), same as
  /// `InheritedWidget.dependOnInheritedWidgetOfExactType`. Throws if
  /// no [CompletionScope] is found above [context], since every
  /// screen that needs completion state expects one to always be
  /// present.
  static ExerciseCompletionService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<CompletionScope>();
    assert(scope != null, 'No CompletionScope found in context');
    return scope!.notifier!;
  }
}
