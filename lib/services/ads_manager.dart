import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'premium_service.dart';

/// ChadMate's real, production AdMob ad unit IDs — see this class's
/// own doc comment for why these specific values (not test IDs) are
/// used directly rather than swapped based on build mode.
class AdUnitIds {
  const AdUnitIds._();

  static const String appId = 'ca-app-pub-9035742345664521~6576403209';
  static const String banner = 'ca-app-pub-9035742345664521/8144755889';
  static const String rewarded = 'ca-app-pub-9035742345664521/9418309106';
  static const String interstitial =
      'ca-app-pub-9035742345664521/5096900657';
}

/// The outcome of [AdsManager.showRewardedAd] — every branch a caller
/// (see [WorkoutUnlockSheet]) needs to react to differently: only
/// [rewarded] should actually unlock anything.
enum RewardedAdResult {
  /// The ad played to completion and the reward was granted.
  rewarded,

  /// The user closed the ad before it finished, or it finished
  /// without granting a reward — AdMob distinguishes these
  /// internally, but a caller only interested in "did I earn the
  /// unlock" doesn't need to.
  notRewarded,

  /// No ad was ready to show (still loading, or the last load
  /// attempt failed) — see [AdsManager.isRewardedAdReady] to check
  /// before offering the option at all, so this is mostly a fallback
  /// for the race between "was ready" and "actually tapped".
  notReady,

  /// The ad was ready but the SDK failed to actually present it
  /// (e.g. the activity wasn't in a valid state).
  failedToShow,
}

/// Owns every AdMob ad ChadMate shows: preloads rewarded and
/// interstitial ads, exposes reactive state a banner widget can
/// render itself from, and is the single place Premium status is
/// checked before any ad-related work happens at all.
///
/// **MVVM placement.** This is the ViewModel: it holds ad state
/// ([isRewardedAdReady], [isInterstitialReady], [adsEnabled]) as
/// plain, observable properties (`ChangeNotifier`, the same pattern
/// every other service in this app already uses) and exposes intents
/// as methods ([showRewardedAd], [maybeShowInterstitialAfterSession])
/// — never touching a `BuildContext` or any widget directly. The
/// "Model" side is the raw google_mobile_ads types (`RewardedAd`,
/// `InterstitialAd`, `BannerAd`) this class wraps; the "View" side is
/// [AdaptiveBannerAd] and [WorkoutUnlockSheet], which read this
/// class's state and call its methods, never touching
/// google_mobile_ads directly themselves.
///
/// **Real ad unit IDs, not test ones.** [AdUnitIds] holds ChadMate's
/// actual, already-configured AdMob identifiers, used directly here
/// rather than swapped for Google's shared test IDs based on
/// `kDebugMode` — the request that built this asked for these exact
/// IDs. That does mean whoever tests this needs to register their own
/// device as an AdMob test device (`RequestConfiguration` below is
/// where that goes) rather than tapping real ads during development —
/// interacting with your own live ads, even accidentally, risks the
/// AdMob account over invalid traffic, and no amount of app-side code
/// can substitute for that account-level step.
///
/// **Premium.** [_handlePremiumChanged] is the one place that reacts
/// to [PremiumService] flipping tiers — on entering Premium, every
/// loaded ad is disposed immediately ([_disposeAllAds]) and nothing
/// new ever loads while [adsEnabled] is false; on leaving it (a
/// downgrade path this app doesn't currently expose, but nothing here
/// assumes it can't happen), preloading picks back up. Both a fresh
/// purchase and [PremiumService.restorePurchases] land on the exact
/// same [PremiumService.isPremium] flip, so both are covered by this
/// one listener — there's no separate "restore" code path to keep in
/// sync.
class AdsManager extends ChangeNotifier {
  AdsManager({required PremiumService premium}) : _premium = premium {
    _premium.addListener(_handlePremiumChanged);
  }

  final PremiumService _premium;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _rewardedAdLoading = false;
  bool _interstitialAdLoading = false;
  bool _initialized = false;

  /// Guards a rewarded ad's own show() call against being invoked a
  /// second time while the first is still resolving (e.g. a
  /// double-tap on "Watch Ad") — separate from [_rewardedAdLoading],
  /// which guards *loading* a new one.
  bool _rewardedAdShowing = false;

  /// The last time an interstitial was actually shown — the cooldown
  /// [maybeShowInterstitialAfterSession] enforces on top of "at most
  /// once per completed session" (that part is the caller's job, via
  /// its own per-session guard — see WorkoutSessionScreen), as a
  /// second, independent safety net against ever showing two in quick
  /// succession regardless of how many places end up calling this.
  DateTime? _lastInterstitialShownAt;

  static const Duration _interstitialCooldown = Duration(minutes: 2);

  /// Whether ads should be shown at all right now. `false` whenever
  /// [PremiumService.isPremium] is true — every other getter and
  /// method on this class already respects this on its own, but it's
  /// exposed directly for [AdaptiveBannerAd] to check before even
  /// attempting to build a banner.
  bool get adsEnabled => !_premium.isPremium;

  bool get isRewardedAdReady => _rewardedAd != null;
  bool get isInterstitialReady => _interstitialAd != null;

  /// Starts up the Mobile Ads SDK and preloads the rewarded and
  /// interstitial ads. Call once, near app startup (see `main.dart`)
  /// — safe to call more than once, but a no-op past the first
  /// successful call, and a no-op entirely while [adsEnabled] is
  /// false.
  Future<void> initialize() async {
    if (_initialized || !adsEnabled) return;
    _initialized = true;

    await MobileAds.instance.initialize();

    unawaited(_loadRewardedAd());
    unawaited(_loadInterstitialAd());
  }

  void _handlePremiumChanged() {
    if (_premium.isPremium) {
      _disposeAllAds();
    } else if (_initialized) {
      // Coming back from Premium (not a path this app's UI currently
      // offers, but the listener doesn't assume it can't happen) —
      // resume preloading rather than leaving ads permanently off
      // for the rest of the app's lifetime.
      unawaited(_loadRewardedAd());
      unawaited(_loadInterstitialAd());
    }
    notifyListeners();
  }

  /// Disposes any currently-loaded rewarded/interstitial ad
  /// immediately — called the instant [PremiumService] reports
  /// Premium, satisfying "dispose of any loaded ads immediately after
  /// Premium is unlocked" without waiting for whatever screen
  /// happens to be showing an ad-related widget to notice on its own.
  /// [AdaptiveBannerAd] disposes its own [BannerAd] the same way, from
  /// its own [adsEnabled] check — banners aren't tracked here since
  /// each is owned by the individual widget showing it, not this
  /// singleton.
  void _disposeAllAds() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  Future<void> _loadRewardedAd() async {
    if (!adsEnabled || _rewardedAdLoading || _rewardedAd != null) return;
    _rewardedAdLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdUnitIds.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAdLoading = false;
            // Premium (or a dispose()) could have landed while this
            // load was in flight — don't hang on to an ad that
            // shouldn't exist anymore just because it happened to
            // finish loading after that.
            if (!adsEnabled) {
              ad.dispose();
              return;
            }
            _rewardedAd = ad;
            notifyListeners();
          },
          onAdFailedToLoad: (error) {
            _rewardedAdLoading = false;
            // No retry loop here: the next natural trigger — opening
            // WorkoutUnlockSheet, which checks isRewardedAdReady and
            // calls this again if it's false — is what re-attempts
            // it, rather than this racing itself on a timer.
          },
        ),
      );
    } catch (_) {
      // No internet, Play Services unavailable, etc. — fail
      // silently; isRewardedAdReady staying false is the caller's
      // signal, not an exception it needs to catch.
      _rewardedAdLoading = false;
    }
  }

  Future<void> _loadInterstitialAd() async {
    if (!adsEnabled || _interstitialAdLoading || _interstitialAd != null) {
      return;
    }
    _interstitialAdLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: AdUnitIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAdLoading = false;
            if (!adsEnabled) {
              ad.dispose();
              return;
            }
            _interstitialAd = ad;
            notifyListeners();
          },
          onAdFailedToLoad: (error) {
            _interstitialAdLoading = false;
          },
        ),
      );
    } catch (_) {
      _interstitialAdLoading = false;
    }
  }

  /// Shows the preloaded rewarded ad, if one is ready and
  /// [adsEnabled]. Resolves to [RewardedAdResult.rewarded] only if
  /// the user actually watched it through to the reward — every other
  /// outcome ([RewardedAdResult.notRewarded],
  /// [RewardedAdResult.notReady], [RewardedAdResult.failedToShow]) is
  /// "don't unlock anything" from [WorkoutUnlockSheet]'s point of
  /// view, just with different messaging for each.
  ///
  /// Whatever the outcome, the consumed ad is disposed and a new one
  /// starts preloading immediately after — "automatically request a
  /// new ad after one is consumed", so the *next* unlock attempt has
  /// a fresh ad ready rather than needing its own cold load.
  Future<RewardedAdResult> showRewardedAd() async {
    if (!adsEnabled) return RewardedAdResult.notReady;
    final ad = _rewardedAd;
    if (ad == null || _rewardedAdShowing) return RewardedAdResult.notReady;

    _rewardedAdShowing = true;
    _rewardedAd = null; // Claimed for this show attempt; see finally below.
    notifyListeners();

    final resultCompleter = Completer<RewardedAdResult>();
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(RewardedAdResult.failedToShow);
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!resultCompleter.isCompleted) {
          resultCompleter.complete(
            earnedReward
                ? RewardedAdResult.rewarded
                : RewardedAdResult.notRewarded,
          );
        }
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          earnedReward = true;
        },
      );
    } catch (_) {
      if (!resultCompleter.isCompleted) {
        resultCompleter.complete(RewardedAdResult.failedToShow);
      }
    }

    final result = await resultCompleter.future;
    _rewardedAdShowing = false;
    unawaited(_loadRewardedAd());
    notifyListeners();
    return result;
  }

  /// Shows the preloaded interstitial if one is ready, [adsEnabled],
  /// and the cooldown since the last one has elapsed — a no-op
  /// (resolves immediately, shows nothing) otherwise, which is the
  /// correct behavior for every one of those cases: no ad ready, no
  /// point failing the caller over it; Premium active, nothing should
  /// show; still within cooldown, skip rather than stack a second ad
  /// right behind the last one.
  ///
  /// Intended to be called exactly once per completed session — see
  /// [WorkoutSessionScreen], which guards that with its own
  /// per-session flag — with this method's cooldown existing as a
  /// second, independent safety net rather than the only thing
  /// standing between a user and back-to-back interstitials.
  Future<void> maybeShowInterstitialAfterSession() async {
    if (!adsEnabled) return;
    final ad = _interstitialAd;
    if (ad == null) return;

    final lastShown = _lastInterstitialShownAt;
    if (lastShown != null &&
        DateTime.now().difference(lastShown) < _interstitialCooldown) {
      return;
    }

    _interstitialAd = null;
    notifyListeners();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadInterstitialAd());
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadInterstitialAd());
      },
    );

    _lastInterstitialShownAt = DateTime.now();
    try {
      await ad.show();
    } catch (_) {
      // onAdFailedToShowFullScreenContent above already handles the
      // SDK-reported failure path; this only guards the exceedingly
      // rare case of show() itself throwing synchronously.
      ad.dispose();
      unawaited(_loadInterstitialAd());
    }
  }

  @override
  void dispose() {
    _premium.removeListener(_handlePremiumChanged);
    _disposeAllAds();
    super.dispose();
  }
}
