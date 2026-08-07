import 'package:flutter/material.dart';

import '../models/premium_feature.dart';
import '../services/analytics_service.dart';
import '../services/premium_scope.dart';
// Re-exports PremiumProducts, ProductKind, PurchaseException and
// SubscriptionProduct, so those don't need importing separately.
import '../services/premium_service.dart';
import '../services/telemetry_scope.dart';
import '../utils/app_haptics.dart';
import '../widgets/premium/plan_option_card.dart';
import '../widgets/premium/premium_feature_row.dart';
import '../widgets/shared/primary_button.dart';
import 'subscription_management_screen.dart';

/// The full "Go Premium" paywall: every [PremiumFeature] laid out as
/// a benefit row, under a gold hero header, with a plan picker and
/// purchase action at the bottom.
///
/// Reached from any [UpgradeCard] tap, or directly from the Premium
/// row in Settings. [highlightFeature] — the feature whose lock the
/// user actually ran into, if any — is called out at the top of the
/// benefit list so the screen still feels relevant even though every
/// feature unlocks together.
///
/// Plans are fetched from the store via [PremiumService.queryProducts]
/// rather than hardcoded, so prices are always the real, localized
/// ones the store has configured — this app never composes a price
/// string itself. Billing frequency and renewal terms are shown on
/// the plan cards and beneath the purchase button, which Play policy
/// requires *before* purchase rather than only in a confirmation
/// step.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({
    super.key,
    this.highlightFeature,
    this.source = 'unknown',
  });

  /// The feature that led the user here, if they arrived via a locked
  /// feature's [UpgradeCard] rather than Settings directly.
  final PremiumFeature? highlightFeature;

  /// Where the user came from, recorded with
  /// [AnalyticsEvent.paywallViewed]. Conversion rate is only
  /// actionable when it can be broken down by entry point — "the
  /// paywall converts at 4%" is far less useful than knowing the
  /// AMOLED-theme gate converts at 12% and the Settings row at 1%.
  final String source;

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  /// Plans fetched from the store, in the display order below. Null
  /// while loading; empty is a real (if unexpected) outcome meaning
  /// the store returned nothing configured.
  List<SubscriptionProduct>? _products;
  String? _loadError;
  String? _selectedProductId;
  var _purchasing = false;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame because both TelemetryScope
    // and PremiumScope are InheritedWidget lookups, which aren't
    // valid directly in initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      TelemetryScope.of(
        context,
      ).logEvent(AnalyticsEvent.paywallViewed(source: widget.source));
      _loadProducts();
    });
  }

  Future<void> _loadProducts() async {
    setState(() {
      _products = null;
      _loadError = null;
    });
    try {
      final products = await PremiumScope.of(context).queryProducts();
      if (!mounted) return;
      setState(() {
        _products = _ordered(products);
        // Default to the yearly plan, matching
        // PremiumProducts.defaultProductId — but fall back to
        // whatever came first rather than leaving nothing selected if
        // the store doesn't have that product configured.
        _selectedProductId = _products!.isEmpty
            ? null
            : _products!
                  .firstWhere(
                    (p) => p.id == PremiumProducts.defaultProductId,
                    orElse: () => _products!.first,
                  )
                  .id;
      });
    } on PurchaseException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load plans. $error');
    }
  }

  /// Yearly first (the anchor plan), then monthly, then lifetime.
  /// Sorted explicitly rather than trusting store return order, which
  /// isn't guaranteed to be stable.
  static List<SubscriptionProduct> _ordered(
    List<SubscriptionProduct> products,
  ) {
    const rank = {
      PremiumProducts.yearly: 0,
      PremiumProducts.monthly: 1,
      PremiumProducts.lifetime: 2,
    };
    final sorted = [...products];
    sorted.sort(
      (a, b) => (rank[a.id] ?? 99).compareTo(rank[b.id] ?? 99),
    );
    return sorted;
  }

  Future<void> _purchaseSelected() async {
    final productId = _selectedProductId;
    if (productId == null || _purchasing) return;

    AppHaptics.medium();
    final premium = PremiumScope.of(context);
    final telemetry = TelemetryScope.of(context);

    setState(() => _purchasing = true);
    telemetry.logEvent(AnalyticsEvent.purchaseStarted(productId: productId));

    try {
      await premium.purchase(productId);
    } on PurchaseException catch (error) {
      telemetry.logEvent(
        AnalyticsEvent.purchaseFailed(
          productId: productId,
          // Deliberately a coarse category, not error.message —
          // provider error strings can carry incidental detail that
          // has no business in an analytics payload.
          reason: 'unavailable',
        ),
      );
      if (!mounted) return;
      setState(() => _purchasing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    if (!mounted) return;
    setState(() => _purchasing = false);

    // `purchase()` returning means the flow was *launched*, and for
    // the simulated repository it has also already resolved. Checking
    // isPremium rather than assuming success keeps this honest once a
    // real store is wired up, where the user can still cancel the
    // sheet after this point.
    if (premium.isPremium) {
      telemetry.logEvent(
        AnalyticsEvent.purchaseCompleted(
          productId: premium.productId ?? productId,
          productKind: premium.productKind?.name ?? 'unknown',
        ),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text("You're on Premium — every feature is unlocked."),
          ),
        );
      Navigator.of(context).pop();
    } else if (premium.hasPendingPurchase) {
      // A real store can leave a purchase awaiting approval (parental
      // consent, slow payment method). Saying "payment pending" is
      // accurate; saying it failed would not be.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Your purchase is pending approval. Premium unlocks as '
              'soon as it completes.',
            ),
          ),
        );
    } else {
      telemetry.logEvent(
        AnalyticsEvent.purchaseFailed(
          productId: productId,
          reason: 'not_completed',
        ),
      );
    }
  }

  /// The plan picker: loading, error, or the real store-priced
  /// options.
  Widget _buildPlanPicker(ThemeData theme, ColorScheme colorScheme) {
    if (_loadError != null) {
      return Column(
        children: [
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    final products = _products;
    if (products == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (products.isEmpty) {
      return Column(
        children: [
          Text(
            'No plans are available right now. Please try again later.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadProducts,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final product in products) ...[
          PlanOptionCard(
            product: product,
            selected: product.id == _selectedProductId,
            badge: product.id == PremiumProducts.yearly ? 'BEST VALUE' : null,
            onSelected: () =>
                setState(() => _selectedProductId = product.id),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final premium = PremiumScope.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const goldStart = Color(0xFFF7B733);
    const goldEnd = Color(0xFFDC8A1E);

    // Highlighted feature first, then the rest in enum order.
    final features = [
      if (widget.highlightFeature != null) widget.highlightFeature!,
      for (final feature in PremiumFeature.values)
        if (feature != widget.highlightFeature) feature,
    ];

    // Written out rather than using firstOrNull, which comes from
    // package:collection — not a dependency here.
    SubscriptionProduct? found;
    for (final product in _products ?? const <SubscriptionProduct>[]) {
      if (product.id == _selectedProductId) {
        found = product;
        break;
      }
    }
    final selectedProduct = found;
    final ctaLabel = _purchasing
        ? 'Starting…'
        : selectedProduct == null
        ? 'Continue'
        : 'Continue — ${selectedProduct.formattedPrice}';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final horizontalPadding = isWide ? 32.0 : 20.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        8,
                        horizontalPadding,
                        0,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          0,
                          horizontalPadding,
                          24,
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [goldStart, goldEnd],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: goldEnd.withValues(
                                    alpha: isDark ? 0.3 : 0.38,
                                  ),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.22,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.workspace_premium,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'ChadMate Premium',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Unlock every feature and get the most '
                                  'out of your routine.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(
                                      alpha: 0.9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "WHAT'S INCLUDED",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Material(
                            color: colorScheme.surfaceContainerHighest,
                            elevation: 2,
                            shadowColor: colorScheme.shadow.withValues(
                              alpha: 0.35,
                            ),
                            surfaceTintColor: colorScheme.surfaceTint,
                            borderRadius: BorderRadius.circular(20),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                for (var i = 0; i < features.length; i++) ...[
                                  PremiumFeatureRow(feature: features[i]),
                                  if (i != features.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      indent: 68,
                                      color: theme.dividerColor,
                                    ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (premium.isPremium)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: colorScheme.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "You're on Premium",
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            Text(
                              'CHOOSE YOUR PLAN',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildPlanPicker(theme, colorScheme),
                            const SizedBox(height: 8),
                            PrimaryButton(
                              label: ctaLabel,
                              icon: Icons.workspace_premium,
                              backgroundColor: goldEnd,
                              foregroundColor: Colors.white,
                              onPressed:
                                  (selectedProduct == null || _purchasing)
                                  ? null
                                  : _purchaseSelected,
                            ),
                            const SizedBox(height: 12),
                            // Play policy requires renewal and
                            // cancellation terms to be visible before
                            // purchase, not only in a post-purchase
                            // confirmation.
                            Text(
                              selectedProduct?.kind == ProductKind.lifetime
                                  ? 'One-time payment through Google Play. '
                                        'This is not a subscription and will '
                                        'never renew.'
                                  : 'Payment is charged to your Google Play '
                                        'account. Subscriptions renew '
                                        'automatically unless cancelled at '
                                        'least 24 hours before the end of the '
                                        'current period. Manage or cancel any '
                                        'time in Settings → Manage '
                                        'Subscription.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _purchasing
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SubscriptionManagementScreen(),
                                      ),
                                    ),
                              icon: const Icon(Icons.restore, size: 18),
                              label: const Text('Restore purchases'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
