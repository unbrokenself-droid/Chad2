import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Points every `SharedPreferencesAsync()` constructed anywhere in the
/// app at a fresh, empty in-memory store, instead of a real platform
/// channel.
///
/// `flutter test` runs in a bare Dart VM with no Android/iOS host
/// underneath it, so `shared_preferences`' real platform
/// implementation is never registered. Without this, any service that
/// defaults to `SharedPreferencesAsync()` — which is most of them:
/// `EntitlementManager`, `TelemetryService`, and every other
/// `*_service.dart` file that persists anything — throws `Bad state:
/// The SharedPreferencesAsyncPlatform instance must be set.` the
/// moment it's touched, and every test that constructs one (directly,
/// or transitively by building the whole app) fails.
///
/// `InMemorySharedPreferencesAsync` is `shared_preferences`' own
/// package-provided test double for exactly this, reached through the
/// same `SharedPreferencesAsyncPlatform.instance` seam every real
/// platform implementation registers itself through — this is the
/// intended way to test code that uses `SharedPreferencesAsync`, not
/// a workaround.
///
/// Call this at the top of `setUp()`, not `setUpAll()`: it replaces
/// the platform instance with a brand new store each time, which is
/// what gives every test a clean slate regardless of what an earlier
/// test in the same file wrote.
///
/// [seed] pre-populates specific keys before anything reads from the
/// store — e.g. marking onboarding complete so a widget test can
/// reach the main app without needing to click through the actual
/// onboarding flow first. Deliberately just `Map<String, Object>`
/// rather than this file knowing about any particular service's
/// keys: each test supplies its own, keeping that knowledge next to
/// the test that actually depends on it.
void resetSharedPreferences({Map<String, Object> seed = const {}}) {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync
      .withData(seed);
}
