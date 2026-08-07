import 'package:flutter/widgets.dart';

import 'background_music_service.dart';

/// Makes a single [BackgroundMusicService] instance available to the
/// whole widget tree below it — the same approach [HydrationScope]
/// and every other `*Scope` in this app use.
///
/// Wrap the app with this once (see `main.dart`), then read the
/// service anywhere below with `BackgroundMusicScope.of(context)`.
class BackgroundMusicScope extends InheritedNotifier<BackgroundMusicService> {
  const BackgroundMusicScope({
    super.key,
    required BackgroundMusicService service,
    required super.child,
  }) : super(notifier: service);

  /// Returns the nearest [BackgroundMusicService] above [context].
  ///
  /// Registers [context] to rebuild whenever the service calls
  /// `notifyListeners()` (e.g. after the volume changes in
  /// [MusicVoiceSheet]). Throws if no [BackgroundMusicScope] is found
  /// above [context], since every screen that touches background
  /// music expects one to always be present.
  static BackgroundMusicService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BackgroundMusicScope>();
    assert(scope != null, 'No BackgroundMusicScope found in context');
    return scope!.notifier!;
  }
}
