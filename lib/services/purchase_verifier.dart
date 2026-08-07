import 'purchase_repository.dart';

/// Whether a [PurchaseVerifier] trusts a [PurchaseUpdate] enough for
/// `SubscriptionManager` to grant the entitlement it implies.
enum VerificationOutcome {
  /// Trusted — grant the entitlement.
  verified,

  /// The exact same transaction was already processed once. Not
  /// suspicious by itself (Play can redeliver a purchase update after
  /// a stream reconnect); just redundant. `SubscriptionManager` still
  /// acknowledges the purchase either way, since Play expects that
  /// regardless of whether this app happened to see it twice.
  duplicate,

  /// Actively untrustworthy — e.g. a product ID this app doesn't
  /// recognize. Worth investigating; see [PurchaseVerifier].
  rejected,
}

/// The result of [PurchaseVerifier.verify].
class VerificationResult {
  const VerificationResult._(this.outcome, this.reason);

  const VerificationResult.verified() : this._(VerificationOutcome.verified, null);

  const VerificationResult.duplicate(String reason)
    : this._(VerificationOutcome.duplicate, reason);

  const VerificationResult.rejected(String reason)
    : this._(VerificationOutcome.rejected, reason);

  final VerificationOutcome outcome;

  /// Human-readable detail, always non-null except when [outcome] is
  /// [VerificationOutcome.verified].
  final String? reason;

  bool get isVerified => outcome == VerificationOutcome.verified;
}

/// Decides whether a [PurchaseUpdate] reporting
/// [PurchaseStatus.success] should actually be trusted enough to
/// grant an entitlement for.
///
/// This is the layer to replace with real server-side verification —
/// see [DefaultPurchaseVerifier]'s doc comment for exactly what that
/// would involve and why this app doesn't have it yet.
abstract class PurchaseVerifier {
  Future<VerificationResult> verify(PurchaseUpdate update);
}

/// The verification this app can actually do without a backend:
/// structural sanity checks plus a replay/idempotency guard.
///
/// **This is not cryptographic proof of purchase, and it isn't meant
/// to look like one.** Real purchase verification — confirming a
/// purchase wasn't forged, hasn't since been refunded, and genuinely
/// belongs to this app's Play Console listing — requires calling the
/// [Google Play Developer API](https://developers.google.com/android-publisher)
/// from a trusted server using the purchase token
/// `in_app_purchase` attaches to every [PurchaseUpdate] (see
/// [PurchaseUpdate.platformData] — [InAppPurchaseRepository] carries
/// the plugin's raw `PurchaseDetails.verificationData
/// .serverVerificationData` through it precisely so a future
/// server-side verifier has it available). ChadMate has no
/// backend yet, so that call can't happen anywhere in this app today
/// — this class is a deliberately-labeled stand-in for it, not a
/// claim that checking things client-side is secure. A device with
/// root access (or a patched Play Store) can bypass *any* check that
/// runs entirely on the device, this one included; moving the trust
/// decision onto a server you control is the only real fix, and the
/// only thing that can also catch a purchase being refunded *after*
/// it was granted.
///
/// To add real verification once a backend exists: implement
/// [PurchaseVerifier] with a class that sends the purchase token from
/// [PurchaseUpdate.platformData] to your endpoint, awaits a
/// server-confirmed answer, and returns
/// [VerificationResult.rejected] unless the server says the purchase
/// is genuinely valid — then pass an instance of it into
/// `SubscriptionManager`'s constructor instead of this class.
class DefaultPurchaseVerifier implements PurchaseVerifier {
  DefaultPurchaseVerifier({required Set<String> knownProductIds})
    : _knownProductIds = knownProductIds;

  final Set<String> _knownProductIds;

  /// Transaction IDs already granted this session, so a redelivered
  /// stream event doesn't get processed (and re-acknowledged) twice.
  /// Intentionally in-memory only, not persisted — this is a
  /// same-session replay guard, not a permanent purchase ledger; nothing
  /// here needs to survive an app restart, since a genuinely-new
  /// stream delivery after a restart is exactly what should be
  /// processed again on its own merits.
  final Set<String> _processedTransactionIds = {};

  @override
  Future<VerificationResult> verify(PurchaseUpdate update) async {
    if (!_knownProductIds.contains(update.productId)) {
      return VerificationResult.rejected(
        'Unrecognized product "${update.productId}".',
      );
    }
    final transactionId = update.transactionId;
    if (transactionId != null &&
        !_processedTransactionIds.add(transactionId)) {
      return VerificationResult.duplicate(
        'Transaction $transactionId was already processed.',
      );
    }
    return const VerificationResult.verified();
  }
}
