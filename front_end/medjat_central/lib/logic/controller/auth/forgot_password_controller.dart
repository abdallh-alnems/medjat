import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';

class ForgotPasswordController extends GetxController {
  final _auth = FirebaseAuth.instance;

  final status = StatusRequest.none.obs;
  final isSendingReset = false.obs;

  Future<void> sendResetLink(String email) async {
    isSendingReset.value = true;
    status.value = StatusRequest.loading;

    final cleanEmail = email.trim().toLowerCase();

    try {
      await _auth.setLanguageCode(Get.locale?.languageCode ?? 'ar');
      await _auth.sendPasswordResetEmail(email: cleanEmail);

      isSendingReset.value = false;
      status.value = StatusRequest.success;
      _showSuccessDialog(cleanEmail);
    } on FirebaseAuthException catch (e) {
      isSendingReset.value = false;
      status.value = StatusRequest.failure;

      // Firebase enables email enumeration protection by default, so it will
      // not throw 'user-not-found' for non-existing emails — it silently
      // succeeds. We only surface real errors here (invalid format, throttling).
      if (e.code == 'invalid-email' ||
          e.code == 'too-many-requests' ||
          e.code == 'missing-email') {
        Get.snackbar('خطأ', _getErrorMessage(e.code),
            snackPosition: SnackPosition.BOTTOM);
      } else {
        status.value = StatusRequest.success;
        _showSuccessDialog(cleanEmail);
      }
    } catch (e) {
      debugPrint('❌ sendResetLink error: $e');
      isSendingReset.value = false;
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', 'حدث خطأ غير متوقع',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showSuccessDialog(String email) {
    final context = Get.context;
    if (context == null) return;
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.brandSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(Icons.mark_email_read_outlined,
                      size: 36, color: colors.brand),
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              Text(
                'reset_link_sent'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'reset_link_sent_desc'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.brand,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              PrimaryButton(
                text: 'done'.tr,
                onPressed: () {
                  Get.back<void>();
                  Get.offAllNamed<void>(AppRoutes.login);
                },
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'invalid_email'.tr;
      case 'too-many-requests':
        return 'too_many_requests'.tr;
      case 'missing-email':
        return 'enter_email'.tr;
      default:
        return 'حدث خطأ غير متوقع';
    }
  }
}
