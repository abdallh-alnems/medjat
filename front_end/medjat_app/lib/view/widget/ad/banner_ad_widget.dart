import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/constant/id/ad_id.dart';

/// Anchored adaptive AdMob banner shown at the bottom of the app shell.
///
/// Renders nothing until an ad is loaded (so it never reserves empty space),
/// hides itself on non-mobile platforms and while the keyboard is open, and
/// retries with back-off when a load fails.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  // Adaptive banner height (updated once the adaptive size is resolved).
  double _adHeight = 60;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdaptiveAd();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) return const SizedBox.shrink();
    if (!_isAdLoaded || _bannerAd == null) return const SizedBox.shrink();

    // Avoid overlapping the on-screen keyboard.
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        height: _adHeight,
        width: double.infinity,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }

  Future<void> _loadAdaptiveAd() async {
    if (!mounted || !_isMobile) return;

    final int adWidth = MediaQuery.of(context).size.width.truncate();
    final AnchoredAdaptiveBannerAdSize? adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(adWidth);

    final AdSize adSize = adaptiveSize ?? AdSize.banner;

    if (mounted) {
      setState(() {
        _adHeight = (adaptiveSize?.height ?? 60).toDouble();
      });
    }

    _bannerAd = BannerAd(
      size: adSize,
      adUnitId: AdManager.idBanner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _retryCount = 0;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _scheduleRetry();
        },
      ),
      request: const AdRequest(),
    );
    unawaited(_bannerAd!.load());
  }

  void _scheduleRetry() {
    if (!mounted || _isAdLoaded || _retryCount >= _maxRetries) return;

    _retryCount++;
    final int delaySeconds = _retryCount * 15;

    Future.delayed(Duration(seconds: delaySeconds), () {
      if (mounted && !_isAdLoaded) {
        _loadAdaptiveAd();
      }
    });
  }
}
