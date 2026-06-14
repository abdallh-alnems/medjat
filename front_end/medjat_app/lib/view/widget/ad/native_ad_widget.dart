import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/constant/id/ad_id.dart';
import '../../../core/constant/theme/app_colors.dart';

/// AdMob native (advanced) ad rendered inline with the app content using the
/// platform-provided native template — no custom native factory code required.
///
/// Renders nothing until an ad is loaded (so it never reserves empty space),
/// hides itself on non-mobile platforms, adapts its colours to light/dark
/// mode, and retries with back-off when a load fails.
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key, this.templateType = TemplateType.medium});

  /// Native template size — `medium` (richer, ~320dp) or `small` (~90dp).
  final TemplateType templateType;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) return const SizedBox.shrink();
    if (!_isAdLoaded || _nativeAd == null) return const SizedBox.shrink();

    final double height =
        widget.templateType == TemplateType.medium ? 330 : 90;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height, maxHeight: height),
      child: AdWidget(ad: _nativeAd!),
    );
  }

  void _loadAd() {
    if (!mounted || !_isMobile) return;

    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    _nativeAd = NativeAd(
      adUnitId: AdManager.idNative,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.templateType,
        mainBackgroundColor: colors.surface,
        cornerRadius: 12,
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: colors.textPrimary,
          size: 15,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: colors.textSecondary,
          size: 13,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: colors.textTertiary,
          size: 12,
        ),
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: colors.brand,
          size: 14,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
              _retryCount = 0;
            });
          } else {
            ad.dispose();
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _nativeAd = null;
          _scheduleRetry();
        },
      ),
    );
    unawaited(_nativeAd!.load());
  }

  void _scheduleRetry() {
    if (!mounted || _isAdLoaded || _retryCount >= _maxRetries) return;

    _retryCount++;
    final int delaySeconds = _retryCount * 15;

    Future.delayed(Duration(seconds: delaySeconds), () {
      if (mounted && !_isAdLoaded) _loadAd();
    });
  }
}
