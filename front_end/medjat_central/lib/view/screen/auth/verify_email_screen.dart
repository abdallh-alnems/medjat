import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final auth = Get.find<AuthController>();
      auth.checkEmailVerified(silent: true);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final auth = Get.find<AuthController>();
      auth.checkEmailVerified(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final colors = AppColors.of(context);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.brandSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Icon(Icons.mark_email_read_outlined,
                      size: 40, color: colors.brand),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  'verify_your_email'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'sent_activation_link_to'.tr,
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
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.brand,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'click_link_to_activate'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s7),
                PrimaryButton(
                  text: 'activated'.tr,
                  onPressed: () => auth.checkEmailVerified(),
                ),
                const SizedBox(height: AppSpacing.s4),
                Obx(() => PrimaryButton(
                      text: 'resend_link'.tr,
                      isLoading: auth.isSendingVerification.value,
                      onPressed: auth.isSendingVerification.value
                          ? () {}
                          : () => auth.resendVerificationEmail(),
                      enabled: !auth.isSendingVerification.value,
                    )),
                const SizedBox(height: AppSpacing.s6),
                TextButton(
                  onPressed: () async {
                    await auth.logout();
                  },
                  child: Text(
                    'change_email_or_back'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
