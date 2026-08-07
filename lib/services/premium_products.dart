/// What kind of product grants (or would grant) entitlement — a
/// subscription that can lapse or be canceled, or a one-time
/// "Lifetime" purchase that never expires.
///
/// This lives in its own file, separate from `subscription_manager.dart`,
/// specifically so `EntitlementManager` and both `PurchaseRepository`
/// implementations can depend on it without any of them needing to
/// import `subscription_manager.dart` itself — that would create an
/// import cycle, since `subscription_manager.dart` depends on all of
/// them.
enum ProductKind {
  monthlySubscription,
  yearlySubscription,
  lifetime;

  /// Whether this kind can lapse (expire, get canceled, fail to
  /// renew) — true for both subscription kinds, false for
  /// [lifetime]. Nothing in this app currently branches on this, but
  /// it's the natural place to ask the question once something does
  /// (e.g. deciding whether a "Manage Subscription" deep link makes
  /// sense to show).
  bool get isSubscription => this != ProductKind.lifetime;
}

/// Store product identifiers for ChadMate Premium, and what kind
/// each one is.
///
/// These IDs must match what's configured in the Google Play Console
/// (and, later, App Store Connect) exactly — the store is the source
/// of truth for price and billing period, not this file. Every ID
/// ChadMate ever purchases must be listed in [all], since
/// [kindOf] — which both purchase repositories and
/// `SubscriptionManager` rely on — throws for anything it doesn't
/// recognize.
abstract final class PremiumProducts {
  static const String monthly = 'premium_monthly';
  static const String yearly = 'premium_yearly';
  static const String lifetime = 'premium_lifetime';

  /// What `SubscriptionManager.purchasePremium` buys — the single
  /// plan `UpgradeScreen`'s one "Upgrade to Premium" button offers,
  /// since that paywall doesn't have a plan picker yet.
  static const String defaultProductId = yearly;

  static const Set<String> subscriptions = {monthly, yearly};
  static const Set<String> all = {monthly, yearly, lifetime};

  /// The [ProductKind] for a known product [id].
  ///
  /// Throws [ArgumentError] if [id] isn't in [all] — every product
  /// this app purchases has to be registered here for
  /// `SubscriptionManager` to know how to buy it (subscription vs.
  /// one-time) and how `EntitlementManager` should persist it. In
  /// practice this is only ever called after a purchase has already
  /// passed `DefaultPurchaseVerifier`'s "known product" check, so
  /// hitting the throw path would mean that check has a bug, not that
  /// a real user did anything wrong.
  static ProductKind kindOf(String id) {
    switch (id) {
      case monthly:
        return ProductKind.monthlySubscription;
      case yearly:
        return ProductKind.yearlySubscription;
      case lifetime:
        return ProductKind.lifetime;
      default:
        throw ArgumentError.value(
          id,
          'id',
          'Unrecognized ChadMate product ID',
        );
    }
  }
}
