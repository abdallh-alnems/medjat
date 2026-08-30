import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../core/shared/input_fields/password_input.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Medjat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: colors.brand,
                    letterSpacing: -0.02,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'لوحة تحكم السوبر أدمن',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 16,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s7),
                PrimaryInput(
                  label: 'اسم المستخدم',
                  hint: 'admin',
                  controller: _usernameController,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'هذا الحقل مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s4),
                PasswordInput(
                  controller: _passwordController,
                  hint: '••••••',
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'هذا الحقل مطلوب';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s6),
                GetBuilder<AuthController>(
                  builder: (controller) {
                    return PrimaryButton(
                      text: 'تسجيل الدخول',
                      isLoading: controller.status.value.name == 'loading',
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          controller.login(
                            username: _usernameController.text.trim(),
                            password: _passwordController.text,
                          );
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
