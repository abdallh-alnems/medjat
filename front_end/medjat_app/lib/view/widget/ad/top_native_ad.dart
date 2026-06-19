import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/shared/layout/tab_shell.dart';
import 'native_ad_widget.dart';

/// AdMob native (medium) ad placed at the **top** of a content page.
///
/// A fresh ad is requested every time the page is built — so navigating to a
/// pushed route always shows a new ad. For screens that live inside the bottom
/// [TabShell] (kept alive in an `IndexedStack`), pass [tabIndex] so a new ad is
/// also requested each time that tab is re-selected. Failed loads retry with
/// back-off, and reloads are throttled (handled inside [NativeAdWidget]).
///
/// Renders nothing — and reserves no space — until an ad has loaded.
class TopNativeAd extends StatelessWidget {
  const TopNativeAd({
    super.key,
    this.tabIndex,
    this.horizontalMargin = AppSpacing.s4,
    this.templateType = TemplateType.medium,
  });

  /// Index of the owning tab within [TabShell], or `null` for pushed routes.
  final int? tabIndex;

  /// Horizontal inset around the ad. Pass `0` when the host already provides
  /// its own horizontal padding, so the ad keeps a uniform width across pages.
  final double horizontalMargin;

  /// Native template size — `medium` (richer, ~330dp) or `small` (~90dp).
  final TemplateType templateType;

  @override
  Widget build(BuildContext context) {
    if (const bool.fromEnvironment('SCREENSHOT_MODE')) return const SizedBox.shrink();
    Stream<void>? reloadTrigger;
    if (tabIndex != null && Get.isRegistered<TabNavController>()) {
      reloadTrigger = Get.find<TabNavController>()
          .currentIndex
          .stream
          .where((index) => index == tabIndex)
          .map<void>((_) {});
    }

    return NativeAdWidget(
      reloadTrigger: reloadTrigger,
      templateType: templateType,
      margin: EdgeInsets.fromLTRB(
        horizontalMargin,
        AppSpacing.s3,
        horizontalMargin,
        AppSpacing.s4,
      ),
    );
  }
}
