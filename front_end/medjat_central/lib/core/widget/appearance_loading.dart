import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/theme/theme.dart';

/// Shows a blocking loading overlay while [change] is applied, then dismisses
/// it once the app has had time to finish re-theming / re-localizing.
///
/// Switching the locale ([Get.updateLocale]) or theme ([Get.changeThemeMode])
/// forces a full rebuild of the widget tree, which janks the UI thread for a
/// moment. Covering that moment with an explicit loading screen makes the
/// transition feel intentional instead of looking like the app froze.
Future<void> runWithAppearanceOverlay(Future<void> Function() change) async {
  if (!(Get.isDialogOpen ?? false)) {
    // Not awaited: Get.dialog completes only when the route is popped, which
    // we do ourselves below once the change has settled.
    unawaited(Get.dialog<void>(
      const _AppearanceLoadingOverlay(),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
    ));
  }

  // Let the overlay paint one frame before the heavy synchronous rebuild.
  await Future<void>.delayed(const Duration(milliseconds: 60));
  await change();
  // Give MaterialApp time to settle the theme/locale rebuild + its animation.
  await Future<void>.delayed(const Duration(milliseconds: 550));

  if (Get.isDialogOpen ?? false) {
    Get.back<void>();
  }
}

class _AppearanceLoadingOverlay extends StatelessWidget {
  const _AppearanceLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s6,
            vertical: AppSpacing.s5,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'applying_changes'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
