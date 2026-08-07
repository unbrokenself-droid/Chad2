import 'package:flutter_test/flutter_test.dart';

import 'package:chadmate/models/premium_feature.dart';
import 'package:chadmate/services/entitlement_manager.dart';
import 'package:chadmate/services/purchase_repository.dart';
import 'package:chadmate/services/purchase_verifier.dart';
import 'package:chadmate/services/simulated_purchase_repository.dart';
import 'package:chadmate/services/subscription_manager.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SubscriptionManager (simulated store)', () {
    late SimulatedPurchaseRepository repository;
    late SubscriptionManager manager;

    setUp(() async {
      resetSharedPreferences();
      repository = SimulatedPurchaseRepository(
        simulatedDelay: const Duration(milliseconds: 10),
      );
      manager = SubscriptionManager(
        purchaseRepository: repository,
        // Short settle window so restore-reconciliation tests don't
        // sit around for the multi-second production default.
        restoreSettleDuration: const Duration(milliseconds: 100),
      );
      await manager.initialize();
      // Every test should start from a known baseline rather than
      // depend on execution order or whatever a previous test left
      // in shared_preferences.
      await manager.debugSetTier(PremiumTier.free);
    });

    tearDown(() => manager.dispose());

    test('starts on Free with nothing unlocked', () {
      expect(manager.tier, PremiumTier.free);
      expect(manager.isPremium, isFalse);
      expect(manager.isUnlocked(PremiumFeature.customRoutines), isFalse);
      expect(manager.productId, isNull);
      expect(manager.productKind, isNull);
    });

    test('purchaseYearly grants Premium once the simulated purchase '
        'resolves', () async {
      await manager.purchaseYearly();
      // purchase() resolves once the simulated repository *emits* the
      // result on its update stream, not once SubscriptionManager has
      // finished reacting to it (broadcast stream listeners always
      // fire on a later microtask) — flush one event-loop turn so the
      // listener that grants the entitlement has actually run.
      await Future<void>.delayed(Duration.zero);

      expect(manager.isPremium, isTrue);
      expect(manager.productId, PremiumProducts.yearly);
      expect(manager.productKind, ProductKind.yearlySubscription);
      expect(manager.isUnlocked(PremiumFeature.advancedInsights), isTrue);
    });

    test('purchaseMonthly grants Premium with the monthly product', () async {
      await manager.purchaseMonthly();
      await Future<void>.delayed(Duration.zero);

      expect(manager.isPremium, isTrue);
      expect(manager.productId, PremiumProducts.monthly);
      expect(manager.productKind, ProductKind.monthlySubscription);
    });

    test(
      'purchaseLifetime grants Premium with a lifetime product kind',
      () async {
        await manager.purchaseLifetime();
        await Future<void>.delayed(Duration.zero);

        expect(manager.isPremium, isTrue);
        expect(manager.productId, PremiumProducts.lifetime);
        expect(manager.productKind, ProductKind.lifetime);
        expect(manager.productKind!.isSubscription, isFalse);
      },
    );

    test('a pending purchase is tracked until it resolves', () async {
      repository = SimulatedPurchaseRepository(
        simulatedDelay: const Duration(milliseconds: 10),
        productsRequiringApproval: {PremiumProducts.monthly},
      );
      manager = SubscriptionManager(purchaseRepository: repository);
      await manager.initialize();

      expect(manager.hasPendingPurchase, isFalse);

      final purchaseFuture = manager.purchaseMonthly();
      // Give the simulated repository time to emit the pending
      // update (10ms in) but not yet the success update (20ms in).
      await Future<void>.delayed(const Duration(milliseconds: 15));

      expect(manager.hasPendingPurchase, isTrue);
      expect(manager.pendingProductIds, contains(PremiumProducts.monthly));
      expect(
        manager.isPremium,
        isFalse,
        reason: 'a pending purchase should not grant anything yet',
      );

      await purchaseFuture;
      await Future<void>.delayed(Duration.zero);

      expect(manager.hasPendingPurchase, isFalse);
      expect(manager.isPremium, isTrue);
    });

    test(
      'purchase throws and grants nothing when the store is offline',
      () async {
        repository.simulateOffline = true;

        await expectLater(
          () => manager.purchaseYearly(),
          throwsA(isA<PurchaseException>()),
        );

        expect(manager.isPremium, isFalse);
      },
    );

    test('debugSetTier(free) revokes an active Premium entitlement', () async {
      await manager.debugSetTier(PremiumTier.premium);
      expect(manager.isPremium, isTrue);

      await manager.debugSetTier(PremiumTier.free);
      expect(manager.isPremium, isFalse);
      expect(manager.isUnlocked(PremiumFeature.premiumThemes), isFalse);
    });

    test('restorePurchases replays a still-owned product', () async {
      await manager.purchaseLifetime();
      await Future<void>.delayed(Duration.zero);
      expect(manager.isPremium, isTrue);

      // Simulate a fresh install losing the local cache but the
      // "store" still remembering what was bought.
      await manager.debugSetTier(PremiumTier.free);
      expect(manager.isPremium, isFalse);

      await manager.restorePurchases();

      expect(manager.isPremium, isTrue);
      expect(manager.productId, PremiumProducts.lifetime);
    });

    test(
      'restorePurchases revokes when the store no longer owns the '
      'granting product (lapsed subscription or refund)',
      () async {
        await manager.purchaseYearly();
        await Future<void>.delayed(Duration.zero);
        expect(manager.isPremium, isTrue);

        // The store "forgets" the purchase — standing in for a
        // lapsed subscription or a refund the app has no other way
        // to learn about without a backend.
        repository.forgetOwnership(PremiumProducts.yearly);

        await manager.restorePurchases();

        expect(manager.isPremium, isFalse);
        expect(manager.productId, isNull);
      },
    );

    test('restorePurchases is a no-op while the store is offline', () async {
      await manager.purchaseYearly();
      await Future<void>.delayed(Duration.zero);
      expect(manager.isPremium, isTrue);

      repository.simulateOffline = true;
      await manager.restorePurchases();

      // Can't reconcile against a store it can't reach — the cached
      // entitlement should be left exactly as it was, not guessed
      // away.
      expect(manager.isPremium, isTrue);
    });
  });

  group('DefaultPurchaseVerifier', () {
    test('verifies a purchase for a known product', () async {
      final verifier = DefaultPurchaseVerifier(
        knownProductIds: PremiumProducts.all,
      );

      final result = await verifier.verify(
        const PurchaseUpdate(
          productId: PremiumProducts.yearly,
          status: PurchaseStatus.success,
          transactionId: 'txn-1',
        ),
      );

      expect(result.isVerified, isTrue);
    });

    test('rejects a purchase for an unrecognized product', () async {
      final verifier = DefaultPurchaseVerifier(
        knownProductIds: PremiumProducts.all,
      );

      final result = await verifier.verify(
        const PurchaseUpdate(
          productId: 'not_a_real_product',
          status: PurchaseStatus.success,
          transactionId: 'txn-1',
        ),
      );

      expect(result.outcome, VerificationOutcome.rejected);
    });

    test(
      'flags the same transaction ID as a duplicate on redelivery',
      () async {
        final verifier = DefaultPurchaseVerifier(
          knownProductIds: PremiumProducts.all,
        );
        const update = PurchaseUpdate(
          productId: PremiumProducts.yearly,
          status: PurchaseStatus.success,
          transactionId: 'txn-1',
        );

        final first = await verifier.verify(update);
        final redelivered = await verifier.verify(update);

        expect(first.isVerified, isTrue);
        expect(redelivered.outcome, VerificationOutcome.duplicate);
      },
    );
  });
}
