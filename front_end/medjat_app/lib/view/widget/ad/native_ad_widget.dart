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
  const NativeAdWidget({
    super.key,
    this.templateType = TemplateType.small,
    this.reloadTrigger,
    this.margin = EdgeInsets.zero,
  });

  /// Native template size — `small` (~90dp), the size used app-wide, or
  /// `medium` (~330dp).
  final TemplateType templateType;

  /// Optional stream that, on each event, requests a fresh ad. Used when the
  /// widget stays alive across navigation (e.g. an `IndexedStack` tab) so a new
  /// ad is fetched every time the page becomes visible again. Reloads are
  /// throttled so a fresh ad is never requested more often than AdMob advises.
  final Stream<void>? reloadTrigger;

  /// Spacing applied around the ad — only while an ad is actually shown, so no
  /// empty gap is reserved before the first ad loads.
  final EdgeInsetsGeometry margin;

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  StreamSubscription<void>? _reloadSub;
  DateTime? _lastLoadStart;

  /// Minimum gap between automatic reloads, to respect AdMob's guidance and
  /// avoid burning impressions on rapid navigation.
  static const Duration _minReloadInterval = Duration(seconds: 30);

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_isMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadAd());
      _reloadSub = widget.reloadTrigger?.listen((_) => _reload());
    }
  }

  @override
  void dispose() {
    _reloadSub?.cancel();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (const bool.fromEnvironment('SCREENSHOT_MODE')) return const SizedBox.shrink();
    if (!_isMobile) return const SizedBox.shrink();
    if (!_isAdLoaded || _nativeAd == null) return const SizedBox.shrink();

    final double height =
        widget.templateType == TemplateType.medium ? 330 : 90;

    return Padding(
      padding: widget.margin,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height, maxHeight: height),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }

  /// Disposes the current ad and fetches a fresh one (used by [reloadTrigger]).
  void _reload() {
    if (!mounted || !_isMobile) return;
    if (_lastLoadStart != null &&
        DateTime.now().difference(_lastLoadStart!) < _minReloadInterval) {
      return;
    }

    final NativeAd? old = _nativeAd;
    setState(() {
      _isAdLoaded = false;
      _nativeAd = null;
      _retryCount = 0;
    });
    // Defer disposal until after the frame that removed the old AdWidget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
      if (mounted) _loadAd();
    });
  }

  void _loadAd() {
    if (!mounted || !_isMobile) return;
    _lastLoadStart = DateTime.now();

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
