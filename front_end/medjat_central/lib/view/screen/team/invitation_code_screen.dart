import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';

class InvitationCodeScreen extends StatelessWidget {
  const InvitationCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final code = Get.arguments as String? ?? '';

    return Scaffold(
      appBar: AppBar(title: Text('invitation_code_label'.tr)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.s6),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(Icons.check_circle_outline,
                    size: 36, color: colors.success),
              ),
              const SizedBox(height: AppSpacing.s5),
              Text('share_invitation_with'.tr,
                  style: AppTextStyles.h2(context),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.s6),
              Text('invitation_code_label'.tr,
                  style: AppTextStyles.bodySecondary(context)),
              const SizedBox(height: AppSpacing.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s6,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: colors.brandSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.brand, width: 2),
                ),
                child: Text(
                  code,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: colors.brand,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'invitation_valid_for'.tr,
                style: AppTextStyles.sm(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s5),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Get.snackbar('done'.tr, 'code_copied'.tr,
                      snackPosition: SnackPosition.BOTTOM);
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text('copy_code'.tr),
              ),
              const SizedBox(height: AppSpacing.s5),
              PrimaryButton(
                text: 'done'.tr,
                onPressed: () => Get.back(result: true),
              ),
              const SizedBox(height: AppSpacing.s5),
            ],
          ),
        ),
      ),
    );
  }
}
