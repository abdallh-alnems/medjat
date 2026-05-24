import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/auth/forgot_password_controller.dart';

class ForgotPasswordScreen extends StatelessWidget {
  ForgotPasswordScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ForgotPasswordController());
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.brandSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(Icons.lock_reset_outlined,
                          size: 40, color: colors.brand),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Center(
                    child: Text(
                      'forgot_password'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Center(
                    child: Text(
                      'forgot_password_desc'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s7),
                  PrimaryInput(
                    label: 'email'.tr,
                    hint: '',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'enter_email'.tr;
                      if (!v.contains('@')) return 'invalid_email'.tr;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Obx(() => PrimaryButton(
                        text: 'send_reset_link'.tr,
                        isLoading: ctrl.isSendingReset.value,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            ctrl.sendResetLink(_emailCtrl.text.trim());
                          }
                        },
                      )),
                  const SizedBox(height: AppSpacing.s4),
                  Center(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text(
                        'back_to_login'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          color: colors.brand,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
