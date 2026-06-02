import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/routes/app_routes.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../core/shared/input_fields/primary_input.dart';
import '../../../../logic/controller/auth/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'اطلب رقم هاتفك وكود التفعيل من إدارة الشركة',
                    style: AppTextStyles.bodySecondary(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  PrimaryInput(
                    label: 'رقم الهاتف',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'مطلوب';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  PrimaryInput(
                    label: 'كود التفعيل',
                    controller: _codeController,
                    keyboardType: TextInputType.text,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'مطلوب';
                      if (v.trim().length < 4) return 'كود قصير جداً';
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
                                  controller.login(
                                    phone: _phoneController.text,
                                    code: _codeController.text,
                                  );
                                }
                              },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        Get.toNamed<void>(AppRoutes.kioskPair),
                    child: Text(
                      'وضع الكيوسك',
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
}
