import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';

class ForgotPasswordController extends GetxController {
  final AuthData _authData = Get.find<AuthData>();

  final status = StatusRequest.none.obs;
  final isSendingReset = false.obs;

  Future<void> sendResetLink(String email) async {
    isSendingReset.value = true;
    status.value = StatusRequest.loading;

    final cleanEmail = email.trim().toLowerCase();
    final lang = Get.locale?.languageCode ?? 'ar';

    // Sends our own branded reset email via the backend (which generates the
    // Firebase reset link that opens Firebase's default reset page). The backend
    // is enumeration-safe and always returns success, so we show the same
    // confirmation regardless of account existence.
    final response = await _authData.sendPasswordReset(cleanEmail, lang);
    isSendingReset.value = false;

    if (response['status'] == StatusRequest.success) {
      status.value = StatusRequest.success;
      _showSuccessDialog(cleanEmail);
    } else if (response['status'] == StatusRequest.offline) {
      status.value = StatusRequest.failure;
      Get.snackbar('error'.tr, 'offline_error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      status.value = StatusRequest.failure;
      Get.snackbar('error'.tr, 'unexpected_error'.tr,
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
}
