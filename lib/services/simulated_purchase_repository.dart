import 'dart:async';

import 'premium_products.dart';
import 'purchase_repository.dart';

/// A [PurchaseRepository] that simulates a store, with no network
/// round-trip and no Play Console / App Store Connect setup required.
///
/// This is what `SubscriptionManager.simulated` uses, and what
/// `PremiumService`'s default constructor uses by extension — see
/// that factory's doc comment for why it's still the app's default
/// today. Every purchase "succeeds" after [simulatedDelay].
///
/// Note that `UpgradeScreen` now presents these as real, priced plans
/// with real billing terms, since it can't tell a simulated store
/// from a live one — which is the point of the abstraction, but does
/// mean the paywall reads as fully functional while this repository
/// is the active one. The prices below are the stand-ins being shown.
///
/// Also doubles as a test double: [simulateOffline] and
/// [productsRequiringApproval] let tests exercise the offline and
/// pending-purchase paths without a real store, and [forgetOwnership]
/// lets a test simulate a subscription lapsing or a purchase being
/// refunded, for exercising `SubscriptionManager.restorePurchases`'s
/// reconciliation logic.
class SimulatedPurchaseRepository implements PurchaseRepository {
  SimulatedPurchaseRepository({
    this.simulatedDelay = const Duration(milliseconds: 500),
    this.simulateOffline = false,
    Set<String>? productsRequiringApproval,
  }) : _productsRequiringApproval = productsRequiringApproval ?? {};

  /// How long [purchase] waits before "succeeding", so the upgrade
  /// flow still feels like it's doing something rather than
  /// completing instantly.
  final Duration simulatedDelay;

  /// When true, [isAvailable] reports false and [purchase] throws —
  /// lets a test (or a manual QA pass) exercise the app's offline
  /// handling without needing to actually disconnect the device.
  /// Mutable so a test can flip connectivity mid-scenario.
  bool simulateOffline;

  /// Product IDs that go through [PurchaseStatus.pending] before
  /// resolving to [PurchaseStatus.success], simulating a purchase
  /// awaiting parental approval or a slow payment method.
  final Set<String> _productsRequiringApproval;

  final _updates = StreamController<PurchaseUpdate>.broadcast();

  /// Product IDs "owned" so far, so [restorePurchases] has something
  /// to replay. Intentionally in-memory only — a fresh app launch
  /// starts with nothing owned, same as a fresh install would against
  /// a real store.
  final Set<String> _owned = {};

  var _nextTransactionId = 0;

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;

  @override
  Future<bool> isAvailable() async => !simulateOffline;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<SubscriptionProduct>> queryProducts(
    Set<String> productIds,
  ) async {
    return [
      for (final id in productIds)
        if (PremiumProducts.all.contains(id)) _productFor(id),
    ];
  }

  /// Display-only stand-ins for the three known ChadMate product
  /// IDs. A real store round-trip would never need this —
  /// [InAppPurchaseRepository] gets real, localized prices from Play
  /// Console / App Store Connect instead.
  SubscriptionProduct _productFor(String id) {
    switch (PremiumProducts.kindOf(id)) {
      case ProductKind.monthlySubscription:
        return const SubscriptionProduct(
          id: PremiumProducts.monthly,
          title: 'Premium Monthly',
          description: 'Every ChadMate feature, billed monthly.',
          formattedPrice: r'$4.99/mo',
          kind: ProductKind.monthlySubscription,
        );
      case ProductKind.yearlySubscription:
        return const SubscriptionProduct(
          id: PremiumProducts.yearly,
          title: 'Premium Yearly',
          description: 'Every ChadMate feature, billed yearly.',
          formattedPrice: r'$39.99/yr',
          kind: ProductKind.yearlySubscription,
        );
      case ProductKind.lifetime:
        return const SubscriptionProduct(
          id: PremiumProducts.lifetime,
          title: 'Premium Lifetime',
          description: 'Every ChadMate feature, forever. Pay once.',
          formattedPrice: r'$79.99',
          kind: ProductKind.lifetime,
        );
    }
  }

  @override
  Future<void> purchase(String productId) async {
    if (simulateOffline) {
      throw const PurchaseException(
        'Simulated offline: the store is unreachable.',
      );
    }
    await Future<void>.delayed(simulatedDelay);
    if (_productsRequiringApproval.contains(productId)) {
      _updates.add(
        PurchaseUpdate(productId: productId, status: PurchaseStatus.pending),
      );
      await Future<void>.delayed(simulatedDelay);
    }
    _owned.add(productId);
    _nextTransactionId += 1;
    _updates.add(
      PurchaseUpdate(
        productId: productId,
        status: PurchaseStatus.success,
        transactionId: 'simulated-$_nextTransactionId',
      ),
    );
  }

  @override
  Future<void> restorePurchases() async {
    for (final productId in _owned) {
      _nextTransactionId += 1;
      _updates.add(
        PurchaseUpdate(
          productId: productId,
          status: PurchaseStatus.success,
          transactionId: 'simulated-restore-$_nextTransactionId',
        ),
      );
    }
  }

  @override
  Future<void> completePurchase(PurchaseUpdate update) async {
    // Nothing to acknowledge — there's no real store transaction
    // behind a simulated purchase.
  }

  /// Test/dev-only hook: makes the simulated store "forget" [productId]
  /// was ever bought, as if a subscription had lapsed or a purchase
  /// had been refunded. Not part of [PurchaseRepository] — only
  /// meaningful against the concrete simulated type, since there's no
  /// real-world equivalent action a repository-agnostic caller could
  /// take (you can't reach into Play Console from the app).
  void forgetOwnership(String productId) => _owned.remove(productId);

  @override
  void dispose() {
    _updates.close();
  }
}
