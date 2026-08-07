import 'package:flutter/widgets.dart';

import 'library_bookmarks_service.dart';

/// Makes a single [LibraryBookmarksService] instance available to the
/// whole widget tree below it.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `LibraryBookmarksScope.of(context)`.
class LibraryBookmarksScope extends InheritedNotifier<LibraryBookmarksService> {
  const LibraryBookmarksScope({
    super.key,
    required LibraryBookmarksService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [LibraryBookmarksService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after a bookmark is toggled elsewhere).
  /// Throws if no [LibraryBookmarksScope] is found above [context].
  static LibraryBookmarksService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<LibraryBookmarksScope>();
    assert(scope != null, 'No LibraryBookmarksScope found in context');
    return scope!.notifier!;
  }
}
