import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import 'package:permedjat_shared/permedjat_shared.dart';
import '../../../logic/controller/attendance/face_controller.dart';
import 'widgets/face_capture_view.dart';

/// One-time enrollment of the employee's own face.
///
/// Starts with an explicit consent step: a face template is biometric data
/// under Egypt's labour law 14/2025, so the employee must actively agree
/// before the camera opens, and must be told they can ask HR to delete it.
class FaceEnrollScreen extends StatefulWidget {
  const FaceEnrollScreen({super.key});

  @override
  State<FaceEnrollScreen> createState() => _FaceEnrollScreenState();
}

class _FaceEnrollScreenState extends State<FaceEnrollScreen> {
  final FaceController _face = Get.find<FaceController>();
  bool _consented = false;

  Future<void> _beginCapture() async {
    setState(() => _consented = true);
    await _face.requestChallenge(purpose: 'enroll');
  }

  Future<void> _onCaptured(FaceCaptureResult result) async {
    final ok = await _face.enroll(result);
    if (!ok || !mounted) return;
    Get.back<void>();
    Get.snackbar(
      'done'.tr,
      'face_enroll_success'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text('face_enroll_title'.tr)),
      body: SafeArea(
        child: !_consented
            ? _ConsentBody(onAgree: _beginCapture)
            : GetBuilder<FaceController>(
                builder: (face) {
                  if (face.status == StatusRequest.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final challenge = face.challenge;
                  if (challenge == null) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 56, color: colors.error),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            face.errorMessage ?? 'error_try_again'.tr,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(context),
                          ),
                          const SizedBox(height: AppSpacing.s5),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _beginCapture,
                              child: Text('try_again'.tr),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return FaceCaptureView(
                    key: ValueKey(challenge.nonce),
                    challenge: LivenessChallenge.fromApi(challenge.challenge) ??
                        LivenessChallenge.blink,
                    livenessRequired: challenge.livenessRequired,
                    onCaptured: _onCaptured,
                  );
                },
              ),
      ),
    );
  }
}

class _ConsentBody extends StatelessWidget {
  final VoidCallback onAgree;
  const _ConsentBody({required this.onAgree});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.s6),
          Icon(Icons.face_retouching_natural_outlined,
              size: 72, color: colors.brand),
          const SizedBox(height: AppSpacing.s5),
          Text(
            'face_enroll_intro'.tr,
            textAlign: TextAlign.center,
            style: AppTextStyles.h3(context),
          ),
          const SizedBox(height: AppSpacing.s4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConsentPoint(text: 'face_consent_point_1'.tr),
                _ConsentPoint(text: 'face_consent_point_2'.tr),
                _ConsentPoint(text: 'face_consent_point_3'.tr),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onAgree,
            child: Text('face_consent_agree'.tr),
          ),
          const SizedBox(height: AppSpacing.s3),
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  final String text;
  const _ConsentPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: colors.brand),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 13,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
