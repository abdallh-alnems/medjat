import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import 'package:medjat_shared/medjat_shared.dart';
import '../../../data/model/face_proof_model.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';
import '../../../logic/controller/attendance/face_controller.dart';
import '../../../logic/controller/home/home_controller.dart';
import 'widgets/face_capture_view.dart';

/// Selfie check-in / check-out.
///
/// Flow: ask the server for a single-use challenge → run the camera until the
/// employee performs it and a good-quality frame is captured → send the
/// embedding for the server to verify. The device never decides the match.
class FaceCheckInScreen extends StatefulWidget {
  const FaceCheckInScreen({super.key});

  @override
  State<FaceCheckInScreen> createState() => _FaceCheckInScreenState();
}

class _FaceCheckInScreenState extends State<FaceCheckInScreen> {
  final FaceController _face = Get.find<FaceController>();

  @override
  void initState() {
    super.initState();
    Get.find<AttendanceController>().reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final isCheckOut = Get.find<HomeController>().canCheckOut;
    final ok = await _face.requestChallenge(
      purpose: isCheckOut ? 'check_out' : 'check_in',
    );
    // Not enrolled yet — send them to enrollment rather than into a camera
    // that can only ever fail.
    if (!ok && _face.notEnrolled && mounted) {
      await Get.offNamed<void>(AppRoutes.faceEnroll);
    }
  }

  Future<void> _onCaptured(FaceCaptureResult result) async {
    final challenge = _face.challenge;
    if (challenge == null) return;

    final proof = FaceProof(
      embedding: result.embedding,
      nonce: challenge.nonce,
      livenessPassed: result.livenessPassed,
      imageBase64: result.imageBase64,
    );

    await Get.find<AttendanceController>().processFaceCheck(proof);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCheckOut = Get.find<HomeController>().canCheckOut;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(isCheckOut
            ? 'face_check_out_title'.tr
            : 'face_check_in_title'.tr),
      ),
      body: SafeArea(
        child: GetBuilder<FaceController>(
          builder: (face) {
            if (face.status == StatusRequest.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final challenge = face.challenge;
            if (challenge == null) {
              return _ErrorBody(
                message: face.errorMessage ?? 'error_try_again'.tr,
                onRetry: _start,
              );
            }

            return GetBuilder<AttendanceController>(
              builder: (attendance) {
                if (attendance.isProcessing) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.s3),
                        Text('face_verifying'.tr,
                            style: AppTextStyles.body(context)),
                      ],
                    ),
                  );
                }

                if (attendance.status == StatusRequest.failure) {
                  return _ErrorBody(
                    message: attendance.errorMessage ?? 'error_try_again'.tr,
                    // A burnt nonce can't be reused, so retrying means asking
                    // for a fresh challenge, not re-sending the old capture.
                    onRetry: () {
                      Get.find<AttendanceController>().reset();
                      _start();
                    },
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
            );
          },
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: colors.error),
          const SizedBox(height: AppSpacing.s4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context),
          ),
          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              child: Text('try_again'.tr),
            ),
          ),
        ],
      ),
    );
  }
}
