import 'package:flutter/foundation.dart';

/// A single analytics event: a name plus optional, non-identifying
/// parameters.
///
/// Events are only ever constructed through the named constructors
/// below, never ad-hoc from arbitrary strings. That's deliberate:
/// this class is the single place where every event name and every
/// parameter the app can possibly send is defined, so "does ChadMate
/// send X?" is answerable by reading one file rather than auditing
/// every call site.
///
/// **No personally identifying information belongs in an event, ever.**
/// The onboarding flow collects the user's name; it must never appear
/// here. Nor should any free-text the user typed (custom routine
/// names, for example). Parameters are limited to enum-like values,
/// counts, and durations — things that describe *what happened*, not
/// *who it happened to*. The named constructors below only accept
/// arguments that satisfy that, which is most of the point of having
/// them.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent._(this.name, [this.parameters = const {}]);

  /// Snake-case event name. Firebase Analytics requires names to be
  /// <= 40 chars, alphanumeric + underscore, not starting with a
  /// number or a reserved `firebase_`/`google_`/`ga_` prefix — every
  /// name below is chosen to satisfy that even though the default
  /// implementation doesn't enforce it.
  final String name;

  /// Non-identifying event parameters.
  final Map<String, Object> parameters;

  // ---- Onboarding --------------------------------------------------

  /// The user finished onboarding. [goalCount] and [experienceLevel]
  /// describe *what kind* of profile was created, never the name the
  /// user entered.
  factory AnalyticsEvent.onboardingCompleted({
    required int goalCount,
    required String experienceLevel,
    required bool anyReminderEnabled,
  }) => AnalyticsEvent._('onboarding_completed', {
    'goal_count': goalCount,
    'experience_level': experienceLevel,
    'any_reminder_enabled': anyReminderEnabled,
  });

  // ---- Routine / exercise sessions ----------------------------------

  /// A guided exercise session actually began (i.e. reached the
  /// running stage, past the instructions screen and countdown).
  factory AnalyticsEvent.routineSessionStarted({
    required String exerciseCategory,
    required String difficulty,
  }) => AnalyticsEvent._('routine_session_started', {
    'exercise_category': exerciseCategory,
    'difficulty': difficulty,
  });

  /// A guided exercise session ended. [completed] distinguishes
  /// running the full duration from skipping out early — the
  /// difference between those two is the single most useful signal
  /// for whether exercise durations are set sensibly.
  factory AnalyticsEvent.routineSessionFinished({
    required String exerciseCategory,
    required bool completed,
    required int elapsedSeconds,
  }) => AnalyticsEvent._('routine_session_finished', {
    'exercise_category': exerciseCategory,
    'completed': completed,
    'elapsed_seconds': elapsedSeconds,
  });

  // ---- Premium / paywall --------------------------------------------

  /// The upgrade screen was shown. [source] records what led there
  /// (e.g. a locked feature's gate vs. the Settings row), which is
  /// what makes paywall conversion rate meaningful per entry point
  /// rather than just in aggregate.
  factory AnalyticsEvent.paywallViewed({required String source}) =>
      AnalyticsEvent._('paywall_viewed', {'source': source});

  /// A purchase flow was launched from the paywall. Not a completed
  /// purchase — see [AnalyticsEvent.purchaseCompleted] — since the
  /// store sheet can still be cancelled after this point.
  factory AnalyticsEvent.purchaseStarted({required String productId}) =>
      AnalyticsEvent._('purchase_started', {'product_id': productId});

  /// A purchase completed and the entitlement was granted.
  factory AnalyticsEvent.purchaseCompleted({
    required String productId,
    required String productKind,
  }) => AnalyticsEvent._('purchase_completed', {
    'product_id': productId,
    'product_kind': productKind,
  });

  /// A purchase attempt ended without granting anything. [reason]
  /// is a coarse category (`cancelled`, `error`, `unavailable`), not
  /// a raw error string, which could contain incidental detail.
  factory AnalyticsEvent.purchaseFailed({
    required String productId,
    required String reason,
  }) => AnalyticsEvent._('purchase_failed', {
    'product_id': productId,
    'reason': reason,
  });

  // ---- Reminders ------------------------------------------------------

  /// A reminder was turned on or off. [kind] is the [ReminderKind]
  /// name (`hydration`, `skincare`, `dailyRoutine`, `posture`) — not
  /// the time the user picked, which is closer to a daily-routine
  /// fingerprint than useful product data.
  factory AnalyticsEvent.reminderToggled({
    required String kind,
    required bool enabled,
  }) => AnalyticsEvent._('reminder_toggled', {
    'reminder_kind': kind,
    'enabled': enabled,
  });

  @override
  String toString() => parameters.isEmpty
      ? 'AnalyticsEvent($name)'
      : 'AnalyticsEvent($name, $parameters)';
}

/// Where analytics events go.
///
/// Deliberately provider-agnostic, exactly like `PurchaseRepository`
/// is for stores: nothing above this interface knows or cares whether
/// events reach Firebase, some other backend, or (as today) only a
/// debug console. Swapping providers is one line in `main.dart`, and
/// no call site changes.
abstract class AnalyticsService {
  /// Called once at startup, before any [logEvent] call.
  Future<void> initialize();

  Future<void> logEvent(AnalyticsEvent event);

  /// Records which screen the user is currently looking at. Separate
  /// from [logEvent] because most providers model screen views
  /// specially (Firebase has its own `screen_view` semantics).
  Future<void> logScreenView(String screenName);

  /// Turns collection on or off at the provider level, in addition to
  /// [TelemetryService]'s own gate. Both matter: the gate stops
  /// events being constructed and sent at all, while this tells the
  /// provider SDK itself to stop collecting the automatic,
  /// background data it gathers without any explicit call from this
  /// app (session starts, app updates, and so on).
  Future<void> setCollectionEnabled(bool enabled);
}

/// The default [AnalyticsService]: prints events in debug builds and
/// does nothing at all in release builds. **Nothing leaves the
/// device.**
///
/// This is what ships today, because no real analytics provider is
/// configured yet — see `firebase_telemetry.dart.template` and the
/// README's "Telemetry" section for what activating one involves. It
/// exists so every call site can be written, reviewed, and tested now
/// rather than being retrofitted later, and so the app's privacy
/// posture doesn't silently change the moment the instrumentation
/// lands.
class DebugAnalyticsService implements AnalyticsService {
  @override
  Future<void> initialize() async {
    debugPrint('[analytics] initialized (debug sink — nothing is sent)');
  }

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    debugPrint('[analytics] $event');
  }

  @override
  Future<void> logScreenView(String screenName) async {
    debugPrint('[analytics] screen_view: $screenName');
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    debugPrint('[analytics] collection enabled: $enabled');
  }
}

/// An [AnalyticsService] that discards everything, silently.
///
/// Used by tests, and as the substitute when the user opts out — see
/// [TelemetryService], which swaps to this rather than merely
/// skipping its own calls, so an opted-out user gets no collection
/// even from a provider SDK that would otherwise gather data on its
/// own.
class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> logEvent(AnalyticsEvent event) async {}

  @override
  Future<void> logScreenView(String screenName) async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}
}
