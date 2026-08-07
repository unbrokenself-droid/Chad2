import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/premium_feature.dart';
import 'entitlement_manager.dart';
import 'in_app_purchase_repository.dart';
import 'premium_products.dart';
import 'purchase_repository.dart';
import 'purchase_verifier.dart';
import 'simulated_purchase_repository.dart';

export 'premium_products.dart' show PremiumProducts, ProductKind;

/// Orchestrates a purchase-backed subscription: wires a
/// [PurchaseRepository] (the *how* — talks to a store) through a
/// [PurchaseVerifier] (the *should we trust this* — see that class's
/// doc comment for the honest limits of what it can check) to an
/// [EntitlementManager] (the *what* — the locally-cached result), and
/// is the only thing in the app allowed to call
/// [EntitlementManager.grant] or [EntitlementManager.revoke].
///
/// `PremiumService` wraps one of these in a facade that keeps its
/// exact old method names (`upgrade`, `downgrade`, `isUnlocked`, ...)
/// so nothing that already called `PremiumScope.of(context)` needed
/// to change when this replaced the old single-file mock service —
/// see that class's doc comment for the full picture. New code that
/// isn't constrained by an existing call site should depend on this
/// class directly instead, since it also exposes everything the old
/// facade doesn't: buying a specific plan, pending-purchase state,
/// and restore/reconciliation.
class SubscriptionManager extends ChangeNotifier {
  SubscriptionManager({
    required PurchaseRepository purchaseRepository,
    EntitlementManager? entitlementManager,
    PurchaseVerifier? verifier,
    this.restoreSettleDuration = const Duration(seconds: 3),
  }) : _purchases = purchaseRepository,
       _entitlements = entitlementManager ?? EntitlementManager(),
       _verifier =
           verifier ??
           DefaultPurchaseVerifier(knownProductIds: PremiumProducts.all) {
    _entitlements.addListener(notifyListeners);
  }

  /// The real, store-backed configuration — Google Play Billing today
  /// via `in_app_purchase`, StoreKit automatically once an `ios/`
  /// runner is added.
  ///
  /// **Not used by default.** `com.unbrokenself.chadmate` has no
  /// products configured in the Play Console yet (see the root
  /// README's release-prep checklist), so every purchase attempt
  /// would fail against the real store today. Once real products
  /// exist, switch `PremiumService`'s default constructor argument
  /// from [simulated] to this factory — that one-line change is the
  /// entire cutover; nothing else in the app reads from a
  /// [PurchaseRepository] directly.
  factory SubscriptionManager.production() =>
      SubscriptionManager(purchaseRepository: InAppPurchaseRepository());

  /// The app's default today: an in-memory, always-succeeds store
  /// that needs no Play Console setup and no network. Matches
  /// `UpgradeScreen`'s existing "No payment required in this preview
  /// build" copy exactly, and keeps `flutter test` working without a
  /// platform-channel mock for billing.
  factory SubscriptionManager.simulated() =>
      SubscriptionManager(purchaseRepository: SimulatedPurchaseRepository());

  final PurchaseRepository _purchases;
  final EntitlementManager _entitlements;
  final PurchaseVerifier _verifier;

  /// How long [restorePurchases] waits after kicking off a restore
  /// for [PurchaseRepository.updates] to finish delivering whatever
  /// it's going to deliver, before treating that as the complete
  /// picture of what's currently owned. There's no platform signal
  /// for "that's everything, I'm done" — this is a pragmatic
  /// timeout, not a guarantee. Shorten it in tests; consider
  /// lengthening it for production if restores seem to under-report
  /// on slow connections.
  final Duration restoreSettleDuration;

  StreamSubscription<PurchaseUpdate>? _updatesSubscription;
  bool _initialized = false;

  final Set<String> _pendingProductIds = {};
  bool _restoring = false;
  final Set<String> _restoredProductIds = {};

  /// Used for [debugSetTier] — not a real store product, so it can
  /// never actually be found by [restorePurchases], meaning a debug
  /// grant is naturally cleared out the next time reconciliation runs
  /// against a reachable store. See [debugSetTier]'s doc comment.
  static const String _debugProductId = 'debug_override';

  /// Whether the cached entitlement has loaded at least once.
  bool get isLoaded => _entitlements.isLoaded;

  /// The user's currently cached tier.
  PremiumTier get tier => _entitlements.tier;

  /// Whether the cached tier is [PremiumTier.premium].
  bool get isPremium => _entitlements.isPremium;

  /// The product that granted the current entitlement, if any — see
  /// [EntitlementManager.productId].
  String? get productId => _entitlements.productId;

  /// What kind [productId] is — see [EntitlementManager.productKind].
  ProductKind? get productKind => _entitlements.productKind;

  /// Whether [feature] is unlocked for the user's current tier. Every
  /// [PremiumFeature] currently requires Premium — see that enum if
  /// this ever needs to become a per-feature entitlement instead.
  bool isUnlocked(PremiumFeature feature) => isPremium;

  /// Product IDs with a purchase currently awaiting resolution (e.g.
  /// parental approval, a slow payment method) — not wired to any UI
  /// yet, but ready for a "Payment pending" banner.
  Set<String> get pendingProductIds => Set.unmodifiable(_pendingProductIds);

  /// Whether any purchase is currently pending — see
  /// [pendingProductIds].
  bool get hasPendingPurchase => _pendingProductIds.isNotEmpty;

  /// Whether [restorePurchases] is currently in its settle window —
  /// for a "Restoring…" spinner, if you build one.
  bool get isRestoring => _restoring;

  /// Loads the cached entitlement and, the first time this is called,
  /// starts listening for purchase results. Safe to call more than
  /// once — later calls just re-sync the cached entitlement from
  /// disk, the same as every other service's `load` in this app.
  Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      _updatesSubscription = _purchases.updates.listen(_handleUpdate);
      await _purchases.initialize();
    }
    await _entitlements.load();
  }

  Future<void> _handleUpdate(PurchaseUpdate update) async {
    switch (update.status) {
      case PurchaseStatus.success:
        _pendingProductIds.remove(update.productId);
        if (_restoring) _restoredProductIds.add(update.productId);
        final result = await _verifier.verify(update);
        if (result.outcome == VerificationOutcome.verified &&
            PremiumProducts.all.contains(update.productId)) {
          await _entitlements.grant(
            productId: update.productId,
            kind: PremiumProducts.kindOf(update.productId),
          );
        } else if (result.outcome == VerificationOutcome.rejected) {
          debugPrint(
            'SubscriptionManager: rejected purchase update for '
            '"${update.productId}": ${result.reason}',
          );
        }
        // Acknowledge regardless of verification outcome — Play
        // still expects this within 3 days of any successful
        // purchase or it auto-refunds the user. Withholding it
        // doesn't undo a payment that already went through; a
        // rejected verification is a signal to investigate, not a
        // way to claw back money this app doesn't control.
        await _purchases.completePurchase(update);
        notifyListeners();
        break;
      case PurchaseStatus.pending:
        _pendingProductIds.add(update.productId);
        notifyListeners();
        break;
      case PurchaseStatus.canceled:
        _pendingProductIds.remove(update.productId);
        notifyListeners();
        break;
      case PurchaseStatus.error:
        _pendingProductIds.remove(update.productId);
        // Deliberately doesn't touch the entitlement here — a failed
        // *new* purchase attempt should never take away one the user
        // already has. This also covers Play's "item already owned"
        // response to a redundant purchase attempt (e.g. a
        // double-tap): if update.productId is exactly what's already
        // granted, there's nothing wrong and nothing to change.
        notifyListeners();
        break;
    }
  }

  /// Buys [PremiumProducts.defaultProductId] — what `UpgradeScreen`'s
  /// single "Upgrade to Premium" button offers today. Kept for
  /// `PremiumService.upgrade`; new code choosing a specific plan
  /// should call [purchaseMonthly], [purchaseYearly], or
  /// [purchaseLifetime] instead.
  Future<void> purchasePremium() =>
      purchase(PremiumProducts.defaultProductId);

  Future<void> purchaseMonthly() => purchase(PremiumProducts.monthly);

  Future<void> purchaseYearly() => purchase(PremiumProducts.yearly);

  Future<void> purchaseLifetime() => purchase(PremiumProducts.lifetime);

  /// Buys a specific [productId]. Launches the platform purchase
  /// sheet and returns once that's launched, not once it's finished;
  /// [tier] updates asynchronously once [_handleUpdate] sees the
  /// result — the same fire-and-forget pattern every other
  /// listener-driven service in this app uses.
  ///
  /// Throws [PurchaseException] immediately, without touching the
  /// store, if [PurchaseRepository.isAvailable] reports false — this
  /// is the "graceful offline" check: failing fast with a clear,
  /// catchable reason beats letting a raw platform error surface
  /// partway through a purchase sheet opening.
  Future<void> purchase(String productId) async {
    if (!await _purchases.isAvailable()) {
      throw const PurchaseException(
        'The store is not reachable right now — check your connection '
        'and try again.',
      );
    }
    await _purchases.purchase(productId);
  }

  /// Looks up store-side pricing for every product in [productIds]
  /// (default: [PremiumProducts.all]) — for building a plan picker
  /// that shows real, localized prices instead of the flat, priceless
  /// "Upgrade to Premium" button `UpgradeScreen` has today.
  Future<List<SubscriptionProduct>> queryProducts([
    Set<String>? productIds,
  ]) => _purchases.queryProducts(productIds ?? PremiumProducts.all);

  /// Re-queries the store for purchases already owned on this account
  /// (e.g. after a reinstall) and grants the entitlement they imply.
  ///
  /// Also the app's only way to notice a subscription lapsed or was
  /// refunded, since there's no backend here to push that information
  /// proactively: if the current entitlement's product isn't among
  /// what the store reports as owned once this settles, it's revoked
  /// to match. Not wired to any button yet — a real paywall generally
  /// wants one (Apple requires it); wire this up to whichever UI you
  /// add for that.
  ///
  /// If the store can't be reached right now, this returns without
  /// changing anything — reconciling against a store you can't
  /// actually query would mean guessing, and staying on the
  /// last-known entitlement is the correct offline behavior, not a
  /// failure worth throwing over.
  Future<void> restorePurchases() async {
    if (!await _purchases.isAvailable()) return;

    _restoredProductIds.clear();
    _restoring = true;
    notifyListeners();
    try {
      await _purchases.restorePurchases();
      await Future<void>.delayed(restoreSettleDuration);
    } finally {
      _restoring = false;
      notifyListeners();
    }

    final entitledProductId = _entitlements.productId;
    if (entitledProductId != null &&
        !_restoredProductIds.contains(entitledProductId)) {
      // The store no longer reports the product that granted the
      // current entitlement as owned — most likely a lapsed
      // subscription or a refund. Revoke to match. A debug override
      // (see debugSetTier) is cleared here too, since it was never a
      // real purchase the store could confirm in the first place.
      await _entitlements.revoke();
    }
  }

  /// Sets [tier] directly, bypassing the store entirely.
  ///
  /// This is a pre-launch affordance, not a real feature — it's what
  /// backs `PremiumService.upgrade`'s old flag-flip behavior in a
  /// build that has no real store products yet, and what Settings'
  /// "Switch to Free" row uses today. Once
  /// `com.unbrokenself.chadmate` has a live Play Store subscription, a
  /// real subscriber calling this to "switch to Free" would only
  /// desync the local cache from what Google is still billing them
  /// for — the next [restorePurchases] (or an ordinary purchase-stream
  /// update) would just grant Premium right back. **Gate or remove
  /// the "Switch to Free" row in Settings before shipping real
  /// billing.**
  Future<void> debugSetTier(PremiumTier tier) => tier == PremiumTier.free
      ? _entitlements.revoke()
      : _entitlements.grant(
          productId: _debugProductId,
          kind: ProductKind.lifetime,
        );

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    _entitlements.removeListener(notifyListeners);
    _entitlements.dispose();
    _purchases.dispose();
    super.dispose();
  }
}
