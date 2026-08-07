import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../services/ads_manager.dart';
import '../../services/ads_scope.dart';

/// A self-contained adaptive banner ad — place this at the bottom of
/// a screen's own [Scaffold] (as `bottomNavigationBar`, so it can
/// never overlap scrollable content or get scrolled underneath
/// anything) and it handles its own loading, sizing, Premium
/// awareness, and disposal from there.
///
/// Renders nothing at all — [SizedBox.shrink], taking up zero layout
/// space — while [AdsManager.adsEnabled] is false (Premium active),
/// while no ad has loaded yet, or if loading failed; there's
/// deliberately no placeholder box reserving space for a banner that
/// isn't there, since that would just be dead space on a free-tier
/// screen for however long a load takes or after a failure.
///
/// Sized via [AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize],
/// not a fixed [AdSize.banner] — a proper adaptive banner, as
/// requested, spanning the screen's own width and using whatever
/// height AdMob determines fits the current device/orientation best.
class AdaptiveBannerAd extends StatefulWidget {
  const AdaptiveBannerAd({super.key});

  @override
  State<AdaptiveBannerAd> createState() => _AdaptiveBannerAdState();
}

class _AdaptiveBannerAdState extends State<AdaptiveBannerAd> {
  AdsManager? _adsManager;
  BannerAd? _bannerAd;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolved once (didChangeDependencies re-fires for any
    // dependency change, not just the first) — an InheritedWidget
    // lookup like AdsScope.of isn't safe from initState, since the
    // widget isn't fully inserted into the tree yet at that point.
    if (_adsManager == null) {
      _adsManager = AdsScope.of(context);
      _adsManager!.addListener(_handleAdsManagerChanged);
    }
    _syncWithAdsEnabled();
  }

  void _handleAdsManagerChanged() => _syncWithAdsEnabled();

  /// Loads a banner if none exists yet and ads are currently enabled;
  /// disposes the one this widget owns the instant they aren't — the
  /// per-widget half of "remove banner ads instantly" (see
  /// [AdsManager]'s own doc comment for the interstitial/rewarded
  /// half, which it owns directly since those aren't tied to any one
  /// widget's lifetime the way a banner is).
  void _syncWithAdsEnabled() {
    final adsManager = _adsManager;
    if (adsManager == null) return;
    if (!adsManager.adsEnabled) {
      _disposeBanner();
    } else if (_bannerAd == null && !_isLoading) {
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    final adsManager = _adsManager;
    if (adsManager == null || !adsManager.adsEnabled) return;

    _isLoading = true;
    final width = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );

    // Premium could have activated, or this widget could have been
    // torn down, while that async lookup was in flight.
    if (!mounted || !adsManager.adsEnabled || size == null) {
      _isLoading = false;
      return;
    }

    final ad = BannerAd(
      adUnitId: AdUnitIds.banner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loadedAd) {
          _isLoading = false;
          if (!mounted || !adsManager.adsEnabled) {
            loadedAd.dispose();
            return;
          }
          setState(() => _bannerAd = loadedAd as BannerAd);
        },
        onAdFailedToLoad: (failedAd, error) {
          failedAd.dispose();
          _isLoading = false;
          // No retry loop: this screen simply shows nothing for this
          // visit. The next time this widget is built fresh (e.g. the
          // user navigates back to this tab later) is what naturally
          // gives it another attempt, rather than this racing itself
          // on a timer in the background.
        },
      ),
    );
    ad.load();
  }

  void _disposeBanner() {
    final ad = _bannerAd;
    if (ad == null) return;
    ad.dispose();
    if (mounted) {
      setState(() => _bannerAd = null);
    } else {
      _bannerAd = null;
    }
  }

  @override
  void dispose() {
    _adsManager?.removeListener(_handleAdsManagerChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
