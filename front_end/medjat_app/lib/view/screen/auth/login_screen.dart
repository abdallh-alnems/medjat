import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../core/shared/input_fields/password_input.dart';
import '../../../../core/shared/input_fields/primary_input.dart';
import '../../../../logic/controller/auth/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _activationCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showActivation = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _activationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = Get.find<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 64,
                    color: AppColors.brand(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تسجيل الدخول',
                    style: AppTextStyles.h2(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سجّل دخولك بحسابك لتفعيل التطبيق',
                    style: AppTextStyles.bodySecondary(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  if (!_showActivation) ...[
                    PrimaryInput(
                      label: 'البريد الإلكتروني',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        if (!v.contains('@')) return 'بريد غير صالح';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    PasswordInput(
                      label: 'كلمة المرور',
                      controller: _passwordController,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        if (v.length < 6) return '6 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    GetBuilder<AuthController>(
                      builder: (_) {
                        final isLoading =
                            controller.status.value == StatusRequest.loading;
                        return PrimaryButton(
                          text: 'تسجيل الدخول',
                          isLoading: isLoading,
                          onPressed: isLoading
                              ? () {}
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    controller.signInWithEmailPassword(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    );
                                  }
                                },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _divider(theme),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => controller.signInWithGoogle(),
                      icon: Image.asset(
                        'assets/images/google_logo.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.login, size: 20),
                      ),
                      label: const Text('الدخول بحساب Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: theme.dividerColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ],

                  if (_showActivation) ...[
                    Text(
                      'أدخل كود التفعيل',
                      style: AppTextStyles.h3(context),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    PrimaryInput(
                      label: 'كود التفعيل',
                      controller: _activationCodeController,
                      keyboardType: TextInputType.text,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'مطلوب';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    GetBuilder<AuthController>(
                      builder: (_) {
                        final isLoading =
                            controller.status.value == StatusRequest.loading;
                        return PrimaryButton(
                          text: 'تفعيل',
                          isLoading: isLoading,
                          onPressed: isLoading
                              ? () {}
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    controller.activateWithCode(
                                      _activationCodeController.text,
                                    );
                                  }
                                },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showActivation = !_showActivation),
                    child: Text(
                      _showActivation
                          ? 'العودة لتسجيل الدخول'
                          : 'لديّ كود تفعيل',
                      style: TextStyle(color: AppColors.brand(context)),
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

  Widget _divider(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: Divider(color: theme.dividerColor)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('أو', style: AppTextStyles.bodySecondary(context)),
        ),
        Expanded(child: Divider(color: theme.dividerColor)),
      ],
    );
  }
}
