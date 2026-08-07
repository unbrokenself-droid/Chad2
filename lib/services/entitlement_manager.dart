import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'premium_products.dart';

/// The two subscription tiers ChadMate supports.
///
/// [free] is the default for every new install. [premium] unlocks
/// every gated feature — there's currently no separate per-feature
/// purchase, just the one tier upgrade.
enum PremiumTier {
  free,
  premium;

  /// Short, user-facing label, e.g. shown on the Settings summary row.
  String get label {
    switch (this) {
      case PremiumTier.free:
        return 'Free';
      case PremiumTier.premium:
        return 'Premium';
    }
  }
}

/// Persists and broadcasts the user's locally-known entitlement: not
/// just [tier], but which [productId] (and [productKind]) granted it,
/// so `SubscriptionManager` can later reconcile that against what the
/// store actually reports (e.g. to notice a lapsed subscription on
/// restore).
///
/// Deliberately "dumb": it caches whatever it's told to [grant] or
/// [revoke] and never talks to a store itself. That split is what
/// lets [tier] and [isPremium] be read synchronously (e.g. from a
/// build method) while `SubscriptionManager` reconciles this cache
/// against the real store in the background and updates it if they
/// ever disagree — the same reason every other `*_service.dart` file
/// in this app caches its own state instead of re-reading storage on
/// every access.
///
/// Only `SubscriptionManager` should call [grant] or [revoke]; every
/// other reader should treat this as read-only.
class EntitlementManager extends ChangeNotifier {
  EntitlementManager({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Unchanged from the single-file `PremiumService` this originally
  /// replaced, so every install that already has a tier saved —
  /// including every dev/test device already running this app —
  /// keeps it instead of silently resetting to Free.
  static const String _tierKey = 'premium_tier';
  static const String _productIdKey = 'premium_product_id';
  static const String _productKindKey = 'premium_product_kind';

  /// The tier every new install starts on.
  static const PremiumTier defaultTier = PremiumTier.free;

  final SharedPreferencesAsync _preferences;

  PremiumTier _tier = defaultTier;
  String? _productId;
  ProductKind? _productKind;
  bool _loaded = false;

  /// Whether [load] has completed at least once.
  bool get isLoaded => _loaded;

  /// The cached tier. Reports [defaultTier] until [load] resolves.
  PremiumTier get tier => _tier;

  /// Whether the cached tier is [PremiumTier.premium].
  bool get isPremium => _tier == PremiumTier.premium;

  /// The store product ID that granted the current entitlement, if
  /// any. Null on Free, and also null on Premium granted by an
  /// install that predates this field (there's nothing to backfill
  /// it from) — callers that key behavior off this should handle
  /// null as "premium, but which product isn't known."
  String? get productId => _productId;

  /// What kind [productId] is. Null under the same conditions as
  /// [productId].
  ProductKind? get productKind => _productKind;

  /// Loads the persisted entitlement from disk. Safe to call more
  /// than once; subsequent calls just re-sync from storage.
  Future<void> load() async {
    final storedTier = await _preferences.getString(_tierKey);
    _tier = _decodeTier(storedTier);
    _productId = await _preferences.getString(_productIdKey);
    _productKind = _decodeKind(await _preferences.getString(_productKindKey));
    _loaded = true;
    notifyListeners();
  }

  static PremiumTier _decodeTier(String? raw) {
    if (raw == null) return defaultTier;
    try {
      return PremiumTier.values.byName(raw);
    } on ArgumentError {
      // Corrupt or unrecognized stored value shouldn't crash the
      // app; fall back to Free instead.
      return defaultTier;
    }
  }

  static ProductKind? _decodeKind(String? raw) {
    if (raw == null) return null;
    try {
      return ProductKind.values.byName(raw);
    } on ArgumentError {
      return null;
    }
  }

  /// Grants Premium via [productId] of kind [kind], and persists all
  /// three fields together. Called by `SubscriptionManager` after a
  /// purchase passes verification, a restore finds an active
  /// purchase, or — pre-launch only — a debug override is set.
  Future<void> grant({
    required String productId,
    required ProductKind kind,
  }) async {
    final changed =
        _tier != PremiumTier.premium ||
        _productId != productId ||
        _productKind != kind;
    if (!changed) return;
    _tier = PremiumTier.premium;
    _productId = productId;
    _productKind = kind;
    notifyListeners();
    await Future.wait([
      _preferences.setString(_tierKey, PremiumTier.premium.name),
      _preferences.setString(_productIdKey, productId),
      _preferences.setString(_productKindKey, kind.name),
    ]);
  }

  /// Revokes back to [PremiumTier.free] and clears the stored product
  /// info. Called by `SubscriptionManager` when a restore finds no
  /// active purchase behind the current entitlement, or via the
  /// pre-launch "Switch to Free" debug action in Settings.
  Future<void> revoke() async {
    if (_tier == PremiumTier.free) return;
    _tier = PremiumTier.free;
    _productId = null;
    _productKind = null;
    notifyListeners();
    await Future.wait([
      _preferences.setString(_tierKey, PremiumTier.free.name),
      _preferences.remove(_productIdKey),
      _preferences.remove(_productKindKey),
    ]);
  }
}
