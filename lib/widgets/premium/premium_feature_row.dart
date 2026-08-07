import 'package:flutter/material.dart';

import '../../models/premium_feature.dart';

/// A single [PremiumFeature] rendered as an icon-circle + title +
/// description row — the gold-tinted benefit list shown on both
/// [UpgradeScreen] and [PremiumIntroScreen].
///
/// Extracted from what used to be `UpgradeScreen`'s own private
/// `_BenefitRow` specifically so `PremiumIntroScreen` could reuse the
/// exact same rendering rather than growing a second, easily-drifting
/// copy of it — the two screens should look like they're describing
/// the same thing, because they are.
class PremiumFeatureRow extends StatelessWidget {
  const PremiumFeatureRow({super.key, required this.feature});

  final PremiumFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDC8A1E).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.icon,
              color: const Color(0xFFDC8A1E),
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
