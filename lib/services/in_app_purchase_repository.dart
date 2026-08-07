import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import 'premium_products.dart';
import 'purchase_repository.dart';

/// Real, store-backed [PurchaseRepository] — Google Play Billing on
/// Android today via the official `in_app_purchase` plugin (and
/// StoreKit automatically on iOS, once an `ios/` runner exists; see
/// the root README).
///
/// This is the only file in the app that imports `in_app_purchase`
/// directly — everything above [PurchaseRepository] works against the
/// plain Dart types in that file instead, so nothing else needs to
/// know which store SDK, or which platform, is underneath.
///
/// **Not the app's default yet.** `com.unbrokenself.chadmate` has no
/// products configured in the Play Console, so every call here would
/// fail against the real store today — see
/// `SubscriptionManager.production`'s doc comment for how to switch
/// over once that changes.
class InAppPurchaseRepository implements PurchaseRepository {
  InAppPurchaseRepository({iap.InAppPurchase? inAppPurchase})
    : _iap = inAppPurchase ?? iap.InAppPurchase.instance;

  final iap.InAppPurchase _iap;

  StreamSubscription<List<iap.PurchaseDetails>>? _subscription;
  final _updates = StreamController<PurchaseUpdate>.broadcast();

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } on Exception {
      // No Play Services, no Google account on the device, etc. —
      // "can't reach the store" either way, so this is the same
      // "unavailable" outcome as isAvailable() returning false
      // normally, not a crash.
      return false;
    }
  }

  @override
  Future<void> initialize() async {
    // Idempotent: SubscriptionManager.initialize may run more than
    // once (e.g. a screen re-mounting), but the platform purchase
    // stream should only ever be subscribed to once.
    if (_subscription != null) return;
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseDetails,
      onError: (Object error) {
        _updates.add(
          PurchaseUpdate(
            productId: '',
            status: PurchaseStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  void _handlePurchaseDetails(List<iap.PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _updates.add(
        PurchaseUpdate(
          productId: purchase.productID,
          status: _mapStatus(purchase.status),
          transactionId: purchase.purchaseID,
          errorMessage: purchase.error?.message,
          // Carried through so completePurchase can hand the exact
          // same object back to the plugin without re-fetching it,
          // and so a future server-side PurchaseVerifier has the raw
          // purchase token available via
          // purchase.verificationData.serverVerificationData without
          // this repository needing to extract it up front for a use
          // case it doesn't have yet.
          platformData: purchase,
        ),
      );
    }
  }

  PurchaseStatus _mapStatus(iap.PurchaseStatus status) {
    switch (status) {
      case iap.PurchaseStatus.pending:
        return PurchaseStatus.pending;
      case iap.PurchaseStatus.purchased:
      case iap.PurchaseStatus.restored:
        return PurchaseStatus.success;
      case iap.PurchaseStatus.error:
        // Also covers Play's "item already owned" response to a
        // redundant purchase attempt — see the PurchaseStatus.error
        // doc comment in purchase_repository.dart for why that's
        // fine to fold into the same case rather than detect
        // specially.
        return PurchaseStatus.error;
      case iap.PurchaseStatus.canceled:
        return PurchaseStatus.canceled;
    }
  }

  @override
  Future<List<SubscriptionProduct>> queryProducts(
    Set<String> productIds,
  ) async {
    final iap.ProductDetailsResponse response;
    try {
      response = await _iap.queryProductDetails(productIds);
    } on Exception catch (e) {
      throw PurchaseException('Could not reach the store: $e');
    }
    if (response.error != null) {
      throw PurchaseException(
        'Failed to load products: ${response.error!.message}',
      );
    }
    return [
      for (final details in response.productDetails)
        if (PremiumProducts.all.contains(details.id))
          SubscriptionProduct(
            id: details.id,
            title: details.title,
            description: details.description,
            formattedPrice: details.price,
            kind: PremiumProducts.kindOf(details.id),
          ),
    ];
  }

  @override
  Future<void> purchase(String productId) async {
    final iap.ProductDetailsResponse response;
    try {
      response = await _iap.queryProductDetails({productId});
    } on Exception catch (e) {
      throw PurchaseException('Could not reach the store: $e');
    }
    final matches = response.productDetails.where((p) => p.id == productId);
    if (matches.isEmpty) {
      throw PurchaseException(
        'Product "$productId" is not configured in the store yet.',
      );
    }
    bool started;
    try {
      // Play Billing treats subscriptions the same as non-consumables
      // for the purposes of *starting* a purchase — the
      // consumable/non-consumable distinction only matters for
      // whether you call consumePurchase afterward, which neither a
      // subscription nor a Lifetime purchase ever needs.
      started = await _iap.buyNonConsumable(
        purchaseParam: iap.PurchaseParam(productDetails: matches.first),
      );
    } on Exception catch (e) {
      throw PurchaseException('Could not start the purchase: $e');
    }
    if (!started) {
      throw const PurchaseException('Unable to start the purchase flow.');
    }
  }

  @override
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } on Exception catch (e) {
      throw PurchaseException('Could not restore purchases: $e');
    }
  }

  @override
  Future<void> completePurchase(PurchaseUpdate update) async {
    final details = update.platformData;
    if (details is iap.PurchaseDetails && details.pendingCompletePurchase) {
      await _iap.completePurchase(details);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _updates.close();
  }
}
