import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/password_input.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/admin_account/admin_account_controller.dart';

class AddAdminScreen extends StatefulWidget {
  const AddAdminScreen({super.key});

  @override
  State<AddAdminScreen> createState() => _AddAdminScreenState();
}

class _AddAdminScreenState extends State<AddAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'admin';
  bool _loading = false;

  static const _roles = {
    'readonly': 'قراءة فقط',
    'admin': 'مشرف',
    'superadmin': 'مشرف عام',
  };

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final ok = await Get.find<AdminAccountController>().create(
      username: _username.text.trim(),
      password: _password.text,
      role: _role,
      displayName: _displayName.text.trim(),
      email: _email.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: const Text('إضافة مشرف')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.s2),
              Text(
                'إنشاء حساب دخول لتطبيق الأدمن',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'سيتمكّن هذا الشخص من تسجيل الدخول إلى لوحة الإدارة باسم المستخدم وكلمة المرور.',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              PrimaryInput(
                label: 'اسم المستخدم',
                controller: _username,
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'أدخل اسم مستخدم (3 أحرف على الأقل)'
                    : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'الاسم الظاهر (اختياري)',
                controller: _displayName,
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'البريد الإلكتروني (اختياري)',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return GetUtils.isEmail(v.trim()) ? null : 'بريد إلكتروني غير صالح';
                },
              ),
              const SizedBox(height: AppSpacing.s3),
              PasswordInput(
                label: 'كلمة المرور',
                controller: _password,
                validator: (v) => (v == null || v.length < 6)
                    ? 'كلمة المرور 6 أحرف على الأقل'
                    : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: Text(
                  'الصلاحية',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: colors.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: colors.borderHairline),
                  ),
                ),
                items: _roles.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _role = v ?? 'admin'),
              ),
              const SizedBox(height: AppSpacing.s7),
              PrimaryButton(
                text: 'إنشاء الحساب',
                isLoading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
