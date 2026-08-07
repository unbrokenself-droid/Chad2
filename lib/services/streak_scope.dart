import 'package:flutter/widgets.dart';

import 'streak_service.dart';

/// Makes a single [StreakService] instance available to the whole
/// widget tree below it, without pulling in a state-management
/// package — the same approach [CompletionScope], [HydrationScope],
/// and [SkincareScope] use.
///
/// Wrap the app with this once (see `main.dart`), below the
/// [CompletionScope], `HydrationScope`, and `SkincareScope` it reads
/// from, then read the service anywhere below with
/// `StreakScope.of(context)`.
class StreakScope extends InheritedNotifier<StreakService> {
  const StreakScope({
    super.key,
    required StreakService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [StreakService] above [context].
  ///
  /// Registers [context] to rebuild whenever any streak-relevant
  /// change happens — a workout is completed, water is logged, or a
  /// skincare step is checked off — anywhere in the app. Throws if no
  /// [StreakScope] is found above [context], since every screen that
  /// needs streak state expects one to always be present.
  static StreakService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StreakScope>();
    assert(scope != null, 'No StreakScope found in context');
    return scope!.notifier!;
  }
}
