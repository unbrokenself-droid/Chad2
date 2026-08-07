import 'premium_products.dart';

/// The store-agnostic contract [SubscriptionManager] uses to talk to
/// a real (or simulated) purchase backend.
///
/// Nothing above this file — [EntitlementManager], [SubscriptionManager],
/// [PremiumService], or anything in `screens/`/`widgets/` — should
/// ever import `package:in_app_purchase` directly, or know whether
/// purchases are actually simulated right now. That knowledge is
/// confined to whichever concrete implementation is in use:
/// [InAppPurchaseRepository] for the real store, or
/// [SimulatedPurchaseRepository] for local development.
abstract class PurchaseRepository {
  /// Whether the underlying store can currently be reached (signed
  /// into the device, network up, etc.) — checked before every
  /// purchase attempt so a lack of connectivity fails fast with a
  /// clear [PurchaseException] instead of a raw platform error, and
  /// available for callers that want to hide a buy button entirely
  /// rather than let [purchase] fail.
  Future<bool> isAvailable();

  /// Starts listening for purchase results on [updates]. Must be
  /// called once, before [purchase] or [restorePurchases] can
  /// produce anything on that stream. Safe to call more than once —
  /// later calls are a no-op.
  Future<void> initialize();

  /// Looks up store-side info (localized price, title, description)
  /// for [productIds]. IDs the store doesn't recognize are silently
  /// omitted from the result rather than causing an error, so callers
  /// should compare the returned list's length against the request if
  /// they need to know about missing products specifically.
  Future<List<SubscriptionProduct>> queryProducts(Set<String> productIds);

  /// Starts a purchase flow for [productId] — typically opens a
  /// platform purchase sheet. Completes once that flow has been
  /// *launched*, not once it's finished; the actual outcome (success,
  /// pending approval, cancellation, or error) arrives later on
  /// [updates]. Throws [PurchaseException] if the flow couldn't even
  /// be started — the store is unreachable, or [productId] isn't a
  /// configured product.
  Future<void> purchase(String productId);

  /// Re-queries the store for purchases this account already owns
  /// (e.g. after a reinstall or a new device) and replays each one on
  /// [updates] exactly as if it had just completed.
  Future<void> restorePurchases();

  /// Tells the store [update] has been fully delivered to the user.
  /// Required for Google Play to acknowledge a purchase within three
  /// days of it happening — Play auto-refunds anything left
  /// unacknowledged — and for StoreKit to finish the transaction.
  /// Call exactly once per [update], and only after
  /// [SubscriptionManager] has finished acting on it (verifying it
  /// and granting the entitlement it implies).
  Future<void> completePurchase(PurchaseUpdate update);

  /// Every purchase result — fresh purchases, restored purchases,
  /// pending states, and billing errors — for as long as this
  /// repository is alive. [SubscriptionManager] is the only intended
  /// listener.
  Stream<PurchaseUpdate> get updates;

  /// Releases the subscription backing [updates]. Call exactly once,
  /// when the owning [SubscriptionManager] is disposed.
  void dispose();
}

/// A single purchasable plan, as the store actually has it configured
/// — price and title are whatever the store returns, never hard-coded
/// here, since only the store knows the user's local currency and any
/// regional pricing.
class SubscriptionProduct {
  const SubscriptionProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.formattedPrice,
    required this.kind,
  });

  /// Must match a product ID configured in the Play Console (and
  /// later App Store Connect) exactly — see `PremiumProducts`.
  final String id;

  final String title;
  final String description;

  /// Already localized and formatted by the store (e.g. `"$9.99"` or
  /// `"£7.99"`). Never reformat [formattedPrice] or build your own
  /// currency symbol on top of a raw number — that's exactly the kind
  /// of thing that goes wrong across regions.
  final String formattedPrice;

  /// Whether [id] is a lapsable subscription or a permanent
  /// [ProductKind.lifetime] purchase — for a plan picker to label
  /// pricing correctly (e.g. "/year" vs. "one-time").
  final ProductKind kind;
}

/// The outcome of a single purchase attempt or restore, as reported
/// on [PurchaseRepository.updates].
enum PurchaseStatus {
  /// Awaiting parental approval, a slow payment method, etc. Not
  /// final — another update for the same purchase will follow.
  pending,

  /// A completed purchase, whether it just happened or was found by
  /// [PurchaseRepository.restorePurchases].
  success,

  /// The user backed out of the purchase sheet. Not an error.
  canceled,

  /// The purchase failed for a reason other than the user cancelling
  /// — see [PurchaseUpdate.errorMessage]. Also covers the store
  /// reporting "already owned" for a redundant purchase attempt;
  /// [SubscriptionManager] treats that the same as any other error
  /// (i.e. it doesn't touch the entitlement either way), which is the
  /// correct outcome for both cases.
  error,
}

/// A single event on [PurchaseRepository.updates].
class PurchaseUpdate {
  const PurchaseUpdate({
    required this.productId,
    required this.status,
    this.transactionId,
    this.errorMessage,
    this.platformData,
  });

  final String productId;
  final PurchaseStatus status;

  /// The store's identifier for this specific transaction, if it has
  /// one yet (a [PurchaseStatus.pending] update may not). Used by
  /// `DefaultPurchaseVerifier` to reject the same transaction being
  /// processed twice (e.g. after a stream reconnect redelivers it).
  final String? transactionId;

  /// Human-readable detail when [status] is [PurchaseStatus.error].
  final String? errorMessage;

  /// Opaque, implementation-specific payload a [PurchaseRepository]
  /// can stash here and read back out of the same [PurchaseUpdate] in
  /// [PurchaseRepository.completePurchase] — e.g.
  /// [InAppPurchaseRepository] round-trips the plugin's own purchase
  /// object through this rather than re-fetching it, and it's also
  /// where the raw server verification token lives if you add
  /// server-side verification later (see `DefaultPurchaseVerifier`'s
  /// doc comment). Nothing outside a [PurchaseRepository]
  /// implementation should read or depend on this.
  final Object? platformData;
}

/// Thrown when [PurchaseRepository.purchase] or
/// [PurchaseRepository.queryProducts] can't even get as far as
/// talking to the store — including the store being unreachable
/// entirely (see [PurchaseRepository.isAvailable]). An already-failed
/// purchase attempt arrives as a [PurchaseUpdate] with
/// [PurchaseStatus.error] instead — this exception is for the request
/// never making it that far.
class PurchaseException implements Exception {
  const PurchaseException(this.message);

  final String message;

  @override
  String toString() => 'PurchaseException: $message';
}
