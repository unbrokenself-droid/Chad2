# services

Integrations with the outside world: local storage, device sensors/camera,
analytics, and any future backend or API clients.

- `exercise_repository.dart` — loads and parses the exercise catalog
  from the bundled `assets/exercises.json` asset. Currently the app's
  only "external" data source; kept behind `ExerciseRepository` so a
  real API-backed implementation could be swapped in later without
  changing any screen. Throws `ExerciseLoadException` on a missing
  asset, invalid JSON, or a malformed entry.

### Telemetry (analytics + crash reporting)

Same interface-plus-swappable-implementation shape as the purchase
layer. Everything routes through `TelemetryService`, which is the only
place the user's opt-out is enforced — no call site can reach a
provider directly.

- `analytics_service.dart` — the `AnalyticsService` interface and
  `AnalyticsEvent`. Events are only constructible via named
  factories, so this file is the complete, readable list of every
  event the app can send. Also holds `DebugAnalyticsService` (the
  current default — `debugPrint` only, nothing leaves the device) and
  `NoOpAnalyticsService`.
- `crash_reporter.dart` — the `CrashReporter` interface plus the
  matching debug and no-op implementations.
- `telemetry_service.dart` — owns both opt-out preferences, persists
  them, gates every call, and swallows provider failures so telemetry
  can never break a user-facing flow. Read its doc comment on the
  consent model before shipping to EU/UK markets.
- `telemetry_scope.dart` — the `InheritedNotifier` scope. Note its
  `of()` defaults to `listen: false`, unlike most scopes here.
- `firebase_telemetry.dart.template` — the real Firebase
  implementation, deliberately **not** compiled. `firebase_core`
  breaks the Android build until `google-services.json` exists, so
  this ships as a template with activation steps in its header
  comment rather than as a live file that wouldn't build.

**No third-party provider is active.** Production crashes are
currently invisible; the plumbing is in place so activating one is a
one-line change in `main.dart`, but that change hasn't been made.
Activating a provider also requires updating the Privacy Policy — see
the `FLAG:` comments in `lib/data/legal_documents.dart`.

### Premium / purchases

Split into collaborating pieces so payment logic stays out of the UI
layer entirely — screens only ever see `premium_service.dart`.

- `premium_products.dart` — `ProductKind` (subscription vs. Lifetime)
  and `PremiumProducts` (the app's three store product IDs — monthly,
  yearly, lifetime — and which kind each is). A leaf file everything
  else in this list depends on, so it can't create an import cycle.
- `purchase_repository.dart` — the `PurchaseRepository` interface
  (plus its `SubscriptionProduct` / `PurchaseUpdate` / `PurchaseStatus`
  / `PurchaseException` supporting types) that `SubscriptionManager`
  talks to instead of a specific store SDK.
- `in_app_purchase_repository.dart` — the real `PurchaseRepository`,
  backed by Google Play Billing via the `in_app_purchase` plugin. Not
  used by default yet — see `SubscriptionManager.production`'s doc
  comment.
- `simulated_purchase_repository.dart` — the `PurchaseRepository`
  actually in use today: an in-memory store needing no Play Console
  setup, matching the paywall's "preview build" copy. Also a test
  double — it can simulate pending purchases, an unreachable store,
  and a purchase being "forgotten" (a lapsed subscription or refund).
- `purchase_verifier.dart` — `PurchaseVerifier` and the
  `DefaultPurchaseVerifier` this app actually uses: a replay guard and
  a known-product check, **not** cryptographic proof of purchase. Read
  its doc comment before assuming this is more secure than it is —
  real verification needs a backend this app doesn't have yet.
- `entitlement_manager.dart` — the `PremiumTier` enum and
  `EntitlementManager`, which persists and broadcasts the user's
  cached entitlement (tier, product ID, and product kind). Doesn't
  talk to a store itself.
- `subscription_manager.dart` — `SubscriptionManager`, the app's
  actual purchase orchestrator: wires a repository, a verifier, and an
  entitlement manager together, tracks pending purchases, and
  reconciles entitlement on `restorePurchases`.
- `premium_service.dart` — thin backward-compatible facade over
  `SubscriptionManager`, kept so `PremiumScope` and every existing
  `PremiumScope.of(context)` call site didn't need to change. Also
  where the fuller API (specific plans, restore, pending state) is
  exposed for new code.
