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
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
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
                      'إنشاء حساب جديد',
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
                      'أدخل بياناتك لإنشاء حساب الإدارة',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s7),

                  PrimaryInput(
                    label: 'الاسم',
                    hint: 'الاسم',
                    controller: _nameCtrl,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'أدخل اسمك';
                      if (v.trim().length < 3) return 'الاسم قصير';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
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
                      if (v.length < 6) return 'كلمة السر يجب أن تكون ٦ أحرف على الأقل';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  PasswordInput(
                    label: 'تأكيد كلمة السر',
                    hint: 'أعد إدخال كلمة السر',
                    controller: _confirmPassCtrl,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'أعد إدخال كلمة السر';
                      if (v != _passCtrl.text) return 'كلمتا السر غير متطابقتين';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s6),

                  Obx(() => PrimaryButton(
                        text: 'إنشاء الحساب',
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
                        'لديك حساب بالفعل؟',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          color: colors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Get.back(),
                        child: Text(
                          'تسجيل الدخول',
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
