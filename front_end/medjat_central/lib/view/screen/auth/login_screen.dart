import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../core/shared/input_fields/password_input.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
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
                      child: Icon(Icons.shield_outlined,
                          size: 40, color: colors.brand),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Center(
                    child: Text(
                      'Medjat Central',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Center(
                    child: Text(
                      'لوحة إدارة الموارد البشرية',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s7),

                  PrimaryInput(
                    label: 'البريد الإلكتروني',
                    hint: 'admin@company.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل البريد الإلكتروني';
                      if (!v.contains('@')) return 'بريد إلكتروني غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  PasswordInput(
                    controller: _passCtrl,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أدخل كلمة السر';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Obx(() => _AuthButton(
                        label: 'تسجيل الدخول',
                        isLoading: auth.isEmailLoading.value,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            auth.loginWithEmail(
                              email: _emailCtrl.text.trim(),
                              password: _passCtrl.text,
                            );
                          }
                        },
                        color: colors.brand,
                        textColor: Colors.white,
                      )),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Get.toNamed(AppRoutes.signup),
                      child: Text(
                        'إنشاء حساب جديد',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          color: colors.brand,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.borderHairline)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s3),
                        child: Text('أو',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 13,
                              color: colors.textTertiary,
                            )),
                      ),
                      Expanded(child: Divider(color: colors.borderHairline)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s5),

                  Obx(() => _AuthButton(
                        label: 'المتابعة بحساب Google',
                        isLoading: auth.isGoogleLoading.value,
                        onPressed: auth.onGoogleSignIn,
                        color: colors.surface,
                        textColor: colors.textPrimary,
                        border: colors.borderHairline,
                        icon: _GoogleIcon(),
                      )),

                  if (Platform.isIOS) ...[
                    const SizedBox(height: AppSpacing.s3),
                    Obx(() => _AuthButton(
                          label: 'المتابعة بحساب Apple',
                          isLoading: auth.isAppleLoading.value,
                          onPressed: auth.onAppleSignIn,
                          color: colors.textPrimary,
                          textColor: colors.canvas,
                          icon: Icon(Icons.apple,
                              size: 20, color: colors.canvas),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;
  final Color? border;
  final Widget? icon;

  const _AuthButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.color,
    required this.textColor,
    this.border,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: border != null
                ? BorderSide(color: border!)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(textColor),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: AppSpacing.s3),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
