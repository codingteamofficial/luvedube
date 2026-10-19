import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps your rewarded ad. Same behaviour as before (action first, then ad),
/// plus: no double-loading, and a cool-down so users aren't hit on every tap.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // TODO: while developing use Google's test id:
  // 'ca-app-pub-3940256099942544/5224354917'
  static const String _unitId = 'ca-app-pub-7211660777598396/4273277370';

  /// Minimum time between two ads. Set to Duration.zero for "every action".
  static const Duration minGap = Duration(seconds: 45);

  RewardedAd? _ad;
  bool _loading = false;
  DateTime? _lastShown;

  void load() {
    if (_ad != null || _loading) return;
    _loading = true;
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          _loading = false;
          if (kDebugMode) debugPrint('Ad failed: $error');
        },
      ),
    );
  }

  /// Runs [action] fully first (dialogs, saving, etc.), then shows an ad.
  Future<void> runThenAd(FutureOr<void> Function() action) async {
    await action();
    _showIfReady();
  }

  void _showIfReady() {
    final ad = _ad;
    if (ad == null) {
      load();
      return;
    }
    final now = DateTime.now();
    if (_lastShown != null && now.difference(_lastShown!) < minGap) return;

    _ad = null;
    _lastShown = now;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        load();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        load();
      },
    );
    ad.show(onUserEarnedReward: (_, __) {});
  }
}
