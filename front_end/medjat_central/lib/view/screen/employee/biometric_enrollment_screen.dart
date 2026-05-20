import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/biometric/face_enrollment_controller.dart';

class BiometricEnrollmentScreen extends StatelessWidget {
  const BiometricEnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int employeeId = (Get.arguments as Map<String, dynamic>?)?['employee_id'] as int? ?? 0;
    final String employeeName = (Get.arguments as Map<String, dynamic>?)?['employee_name'] as String? ?? '';
    final ctrl = Get.put(FaceEnrollmentController());
    ctrl.loadStatus(employeeId);

    return Scaffold(
      appBar: AppBar(title: Text('biometric_enrollment'.tr)),
      body: GetBuilder<FaceEnrollmentController>(
        builder: (_) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employeeName, style: AppTextStyles.h2(context)),
                const SizedBox(height: AppSpacing.s5),
                _FaceSection(ctrl: ctrl, employeeId: employeeId),
                const SizedBox(height: AppSpacing.s5),
                _FingerprintSection(ctrl: ctrl, employeeId: employeeId),
                const SizedBox(height: AppSpacing.s5),
                if (ctrl.enrollment?.isEnrolled == true)
                  _DeleteSection(ctrl: ctrl, employeeId: employeeId),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FaceSection extends StatelessWidget {
  final FaceEnrollmentController ctrl;
  final int employeeId;
  const _FaceSection({required this.ctrl, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasFace = ctrl.enrollment?.hasFace ?? false;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: hasFace ? colors.success : colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.face_outlined, size: 22, color: hasFace ? colors.success : colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Text('face_enrollment'.tr,
                  style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (hasFace)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('enrolled'.tr,
                      style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 11, color: colors.success, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showFaceCaptureSheet(context),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(hasFace ? 're_enroll_face'.tr : 'enroll_face'.tr,
                  style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.brand,
                side: BorderSide(color: colors.brand),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFaceCaptureSheet(BuildContext context) {
    Get.snackbar('coming_soon'.tr, 'face_enrollment_placeholder'.tr,
        snackPosition: SnackPosition.BOTTOM);
  }
}

class _FingerprintSection extends StatelessWidget {
  final FaceEnrollmentController ctrl;
  final int employeeId;
  const _FingerprintSection({required this.ctrl, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasFingerprint = ctrl.enrollment?.hasFingerprint ?? false;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: hasFingerprint ? colors.success : colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint, size: 22, color: hasFingerprint ? colors.success : colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Text('fingerprint_enrollment'.tr,
                  style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (hasFingerprint)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text('enrolled'.tr,
                      style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 11, color: colors.success, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.sunken,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              children: [
                Icon(Icons.usb_outlined, size: 32, color: colors.textTertiary),
                const SizedBox(height: AppSpacing.s2),
                Text('fingerprint_usb_placeholder'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12, color: colors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteSection extends StatelessWidget {
  final FaceEnrollmentController ctrl;
  final int employeeId;
  const _DeleteSection({required this.ctrl, required this.employeeId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('delete_biometric'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s2),
          if (ctrl.enrollment?.hasFace == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.face_outlined, size: 20, color: colors.error),
              title: Text('delete_face'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13)),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
                onPressed: () => _confirmDelete(context, 'face'),
              ),
            ),
          if (ctrl.enrollment?.hasFingerprint == true)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.fingerprint, size: 20, color: colors.error),
              title: Text('delete_fingerprint'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13)),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: colors.error, size: 20),
                onPressed: () => _confirmDelete(context, 'fingerprint'),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String type) {
    Get.dialog<void>(
      AlertDialog(
        title: Text('confirm_delete'.tr),
        content: Text(type == 'face' ? 'confirm_delete_face'.tr : 'confirm_delete_fingerprint'.tr),
        actions: [
          TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back<void>();
              ctrl.deleteBiometric(employeeId, type);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.of(context).error),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}
