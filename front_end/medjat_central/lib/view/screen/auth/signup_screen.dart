import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../core/shared/input_fields/password_input.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class SignUpScreen extends StatelessWidget {
  SignUpScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('create_account'.tr)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: colors.brandSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(Icons.person_add_outlined,
                          size: 32, color: colors.brand),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Center(
                    child: Text(
                      'create_account'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Center(
                    child: Text(
                      'enter_data_to_create_account'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s7),

                  PrimaryInput(
                    label: 'name'.tr,
                    hint: '',
                    controller: _nameCtrl,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'enter_name'.tr;
                      if (v.trim().length < 3) return 'name_too_short'.tr;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
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
                  const SizedBox(height: AppSpacing.s4),
                  PasswordInput(
                    controller: _passCtrl,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'enter_password'.tr;
                      if (v.length < 8) return 'password_min_length'.tr;
                      if (!RegExp(r'[a-zA-Z]').hasMatch(v)) {
                        return 'password_weak'.tr;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  PasswordInput(
                    label: 'confirm_password'.tr,
                    hint: '',
                    controller: _confirmPassCtrl,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 're_enter_password'.tr;
                      if (v != _passCtrl.text) return 'passwords_not_match'.tr;
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s6),

                  Obx(() => PrimaryButton(
                        text: 'create_account_btn'.tr,
                        isLoading: auth.isEmailLoading.value,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            auth.signUpWithEmail(
                              name: _nameCtrl.text.trim(),
                              email: _emailCtrl.text.trim(),
                              password: _passCtrl.text,
                            );
                          }
                        },
                      )),

                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'already_have_account'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          color: colors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text(
                          'login'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.brand,
                          ),
                        ),
                      ),
                    ],
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
