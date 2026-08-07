import 'package:flutter/foundation.dart';

import '../models/premium_feature.dart';
import 'entitlement_manager.dart' show PremiumTier;
import 'purchase_repository.dart' show SubscriptionProduct;
import 'subscription_manager.dart';

export 'entitlement_manager.dart' show PremiumTier;
export 'premium_products.dart' show PremiumProducts, ProductKind;
export 'purchase_repository.dart' show PurchaseException, SubscriptionProduct;

/// Thin backward-compatible facade over [SubscriptionManager].
///
/// This used to be a single, self-contained file that persisted a
/// [PremiumTier] flag to `SharedPreferences` directly and called that
/// a purchase. It's now real Play Billing integration — a
/// [PurchaseRepository] talking to the store, a [PurchaseVerifier]
/// deciding whether to trust what it hears, and an
/// [EntitlementManager] caching the result, all wired together by
/// [SubscriptionManager] — but every *original* method here keeps its
/// exact old name and signature, so [PremiumScope], and every screen
/// or widget that already called `PremiumScope.of(context)`, kept
/// compiling and working without changing a single line. Everything
/// below the "original API" section is new, purely additive surface
/// for the fuller feature set (specific plans, Lifetime, pending
/// purchases, restore) that no existing call site depends on yet.
///
/// If you're writing new code rather than maintaining an existing
/// call site, prefer depending on [SubscriptionManager] directly —
/// this class exists for compatibility, not because it's the
/// preferred way to reach the purchase system now.
class PremiumService extends ChangeNotifier {
  PremiumService({SubscriptionManager? subscriptionManager})
    : _subscriptions = subscriptionManager ?? SubscriptionManager.simulated(),
      _ownsSubscriptions = subscriptionManager == null {
    _subscriptions.addListener(_handleChange);
  }

  final SubscriptionManager _subscriptions;

  /// Whether this instance created [_subscriptions] itself (the
  /// `PremiumService()` no-arg case `main.dart` uses) versus having
  /// one injected. Only an owned [SubscriptionManager] gets disposed
  /// alongside this facade — an injected one might be shared or
  /// managed elsewhere.
  final bool _ownsSubscriptions;

  void _handleChange() => notifyListeners();

  // ---------------------------------------------------------------
  // Original API — every screen and widget in the app already uses
  // these; signatures are frozen.
  // ---------------------------------------------------------------

  /// Whether [load] has completed at least once. Screens that gate UI
  /// on tier can ignore this in practice — it resolves via a single
  /// fast local read, well before a user reaches a gated screen — but
  /// it's exposed for consistency with the other services' `isLoaded`
  /// flags.
  bool get isLoaded => _subscriptions.isLoaded;

  /// The user's currently active tier. Reads from the in-memory
  /// cache — reports [EntitlementManager.defaultTier] until [load]
  /// has completed once.
  PremiumTier get tier => _subscriptions.tier;

  /// Whether the user currently has an active Premium entitlement.
  bool get isPremium => _subscriptions.isPremium;

  /// Loads the cached entitlement and starts listening for purchase
  /// results. Safe to call more than once.
  Future<void> load() => _subscriptions.initialize();

  /// Whether [feature] is unlocked for the user's current tier.
  ///
  /// Every [PremiumFeature] currently requires Premium — there's no
  /// per-feature entitlement yet — but call sites should still check
  /// through this method (or `PremiumGate`) rather than comparing
  /// [tier] directly, so adding a feature that's free-tier-limited
  /// instead of fully locked, or a future mid-tier, only needs a
  /// change here.
  bool isUnlocked(PremiumFeature feature) => _subscriptions.isUnlocked(
    feature,
  );

  /// Starts a purchase for the app's single Premium plan (currently
  /// [PremiumProducts.yearly] — see [SubscriptionManager.purchasePremium]).
  ///
  /// No longer a local-only flag flip — this now launches a real
  /// purchase flow through whichever [SubscriptionManager] backs this
  /// facade. [tier] updates asynchronously once that flow resolves,
  /// so don't assume [isPremium] is already `true` the instant this
  /// `Future` completes — it means the purchase *started*, the same
  /// way it would against a real store. Can throw [PurchaseException]
  /// — e.g. if the store isn't reachable; see [purchaseMonthly]'s doc
  /// comment for the full set of new methods this facade adds if you
  /// need finer control than the single "upgrade" button.
  Future<void> upgrade() => _subscriptions.purchasePremium();

  /// Downgrades the user back to Free and persists the change.
  ///
  /// Pre-launch affordance only — see
  /// [SubscriptionManager.debugSetTier] for why this needs to be
  /// gated or removed before shipping real billing.
  Future<void> downgrade() => setTier(PremiumTier.free);

  /// Sets the active tier directly and persists the change, bypassing
  /// any store. Pre-launch affordance only — see
  /// [SubscriptionManager.debugSetTier].
  Future<void> setTier(PremiumTier tier) => _subscriptions.debugSetTier(tier);

  // ---------------------------------------------------------------
  // New API — the fuller purchase feature set. Nothing existing
  // calls these yet; add call sites freely, nothing here is frozen.
  // ---------------------------------------------------------------

  /// The product that granted the current entitlement, if any — null
  /// on Free, or on Premium from an install predating this field.
  String? get productId => _subscriptions.productId;

  /// What kind [productId] is (a subscription or
  /// [ProductKind.lifetime]) — null under the same conditions as
  /// [productId].
  ProductKind? get productKind => _subscriptions.productKind;

  /// Buys [PremiumProducts.monthly].
  Future<void> purchaseMonthly() => _subscriptions.purchaseMonthly();

  /// Buys [PremiumProducts.yearly].
  Future<void> purchaseYearly() => _subscriptions.purchaseYearly();

  /// Buys [PremiumProducts.lifetime] — a permanent, one-time
  /// purchase that never needs renewing and can't lapse.
  Future<void> purchaseLifetime() => _subscriptions.purchaseLifetime();

  /// Buys a specific [productId].
  ///
  /// What a data-driven plan picker wants: [queryProducts] returns
  /// whatever the store has configured, and each option's purchase
  /// button passes that product's own ID straight back here, rather
  /// than the UI needing a hardcoded branch per plan that would go
  /// stale the moment a fourth product is added.
  Future<void> purchase(String productId) =>
      _subscriptions.purchase(productId);

  /// Product IDs with a purchase currently awaiting resolution (e.g.
  /// parental approval, a slow payment method) — for a "Payment
  /// pending" banner.
  Set<String> get pendingProductIds => _subscriptions.pendingProductIds;

  /// Whether any purchase is currently pending — see
  /// [pendingProductIds].
  bool get hasPendingPurchase => _subscriptions.hasPendingPurchase;

  /// Whether [restorePurchases] is currently in progress — for a
  /// "Restoring…" spinner.
  bool get isRestoring => _subscriptions.isRestoring;

  /// Re-queries the store for purchases already owned on this account
  /// and grants (or, if a subscription has lapsed, revokes) the
  /// entitlement they imply. Not wired to any button yet — see
  /// [SubscriptionManager.restorePurchases]'s doc comment for why a
  /// real paywall generally needs one.
  Future<void> restorePurchases() => _subscriptions.restorePurchases();

  /// Looks up store-side pricing for [productIds] (default: every
  /// ChadMate product) — for a plan picker that shows real,
  /// localized prices instead of `UpgradeScreen`'s current flat,
  /// priceless button.
  Future<List<SubscriptionProduct>> queryProducts([
    Set<String>? productIds,
  ]) => _subscriptions.queryProducts(productIds);

  @override
  void dispose() {
    _subscriptions.removeListener(_handleChange);
    if (_ownsSubscriptions) _subscriptions.dispose();
    super.dispose();
  }
}
