import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';
import '../../../logic/controller/home/home_controller.dart';

/// Photo check-in / check-out (`photo_gps`).
///
/// Deliberately the plainest camera flow in the app. It is NOT a cheaper
/// [FaceCheckInScreen]: nothing here is measured, no embedding is produced, no
/// liveness action is asked for, and the photo can never cause a rejection. It
/// is evidence a manager looks at if a day is disputed, and a company chooses it
/// precisely to avoid processing biometric data at all (law 14/2025).
///
/// So there is no custom camera view either — the system camera via
/// `image_picker` is the right tool. A bespoke preview would imply the app is
/// analysing the frame, which is exactly the impression this method must not
/// give.
class PhotoCheckInScreen extends StatefulWidget {
  const PhotoCheckInScreen({super.key});

  @override
  State<PhotoCheckInScreen> createState() => _PhotoCheckInScreenState();
}

class _PhotoCheckInScreenState extends State<PhotoCheckInScreen> {
  /// The server refuses anything over ~1.5 MB decoded (PunchPhotoService).
  /// These bounds keep an ordinary capture comfortably under that without the
  /// employee ever meeting the limit — a rejection here would be the app's
  /// fault, not theirs.
  static const int _maxWidth = 1080;
  static const int _quality = 70;

  /// Matches the server's cap. Checked locally so a too-large image fails
  /// immediately rather than after a slow upload on a weak connection.
  static const int _maxBytes = 1500000;

  bool _capturing = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    Get.find<AttendanceController>().reset();
    // Straight into the camera: this screen has nothing else on it, and making
    // the employee tap a button to reach the button is friction for nothing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() {
      _capturing = true;
      _localError = null;
    });

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: _maxWidth.toDouble(),
        imageQuality: _quality,
      );

      if (!mounted) return;

      // Cancelled the camera. Go back rather than sit on an empty screen.
      if (picked == null) {
        Get.back<void>();
        return;
      }

      final bytes = await File(picked.path).readAsBytes();
      if (!mounted) return;

      if (bytes.length > _maxBytes) {
        setState(() {
          _capturing = false;
          _localError = 'photo_too_large'.tr;
        });
        return;
      }

      await Get.find<AttendanceController>().processPhotoCheck(
        base64Encode(bytes),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _localError = 'photo_capture_failed'.tr);
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCheckOut = Get.find<HomeController>().canCheckOut;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(isCheckOut
            ? 'photo_check_out_title'.tr
            : 'photo_check_in_title'.tr),
      ),
      body: SafeArea(
        child: GetBuilder<AttendanceController>(
          builder: (attendance) {
            if (_capturing || attendance.isProcessing) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      attendance.isProcessing
                          ? 'photo_sending'.tr
                          : 'photo_opening_camera'.tr,
                      style: AppTextStyles.body(context),
                    ),
                  ],
                ),
              );
            }

            final message = _localError ??
                (attendance.status == StatusRequest.failure
                    ? attendance.errorMessage
                    : null);

            if (message != null) {
              return _ErrorBody(
                message: message,
                onRetry: () {
                  Get.find<AttendanceController>().reset();
                  _capture();
                },
              );
            }

            // Reached only in the moment between the camera closing and the
            // request starting.
            return const Center(child: CircularProgressIndicator());
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
