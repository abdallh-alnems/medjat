import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/data_source/remote/tenant_data/tenant_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TenantData _tenantData;
  late final AuthController _auth;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<TenantData>()) {
      Get.put<TenantData>(TenantData());
    }
    _tenantData = Get.find<TenantData>();
    _auth = Get.find<AuthController>();
  }

  Future<String?> _firebaseToken() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return null;
    return fbUser.getIdToken();
  }

  Future<void> _onCreateCompany() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final submitted = await Get.bottomSheet<bool>(
      Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s5,
          right: AppSpacing.s5,
          top: AppSpacing.s5,
          bottom:
              MediaQuery.of(Get.context!).viewInsets.bottom + AppSpacing.s5,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أنشئ شركتك',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الشركة'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: phoneCtrl,
                decoration:
                    const InputDecoration(labelText: 'رقم الموبايل (اختياري)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Get.back(result: true);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s2),
                  child: Text('إنشاء'),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
    );

    if (submitted != true) return;

    setState(() => _loading = true);
    final token = await _firebaseToken();
    if (token == null) {
      setState(() => _loading = false);
      Get.snackbar('خطأ', 'لازم تسجل دخول الأول',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final resp = await _tenantData.createCompany(
      firebaseToken: token,
      companyName: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (resp['status'] == StatusRequest.success) {
      final data = (resp['data'] as Map?)?['data'] as Map?;
      if (data != null && data['success'] == true) {
        _auth.hasTenant.value = true;
        Get.snackbar('تم', 'تم إنشاء الشركة بنجاح',
            snackPosition: SnackPosition.BOTTOM);
        Get.offAllNamed(AppRoutes.home);
        return;
      }
    }
    final msg =
        (resp['data'] as Map?)?['message'] as String? ?? 'فشل إنشاء الشركة';
    Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _onJoinCompany() async {
    final formKey = GlobalKey<FormState>();
    final codeCtrl = TextEditingController();

    final submitted = await Get.bottomSheet<bool>(
      Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s5,
          right: AppSpacing.s5,
          top: AppSpacing.s5,
          bottom:
              MediaQuery.of(Get.context!).viewInsets.bottom + AppSpacing.s5,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('انضم لشركة',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'كود الدعوة'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Get.back(result: true);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s2),
                  child: Text('انضم'),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
    );

    if (submitted != true) return;

    setState(() => _loading = true);
    final token = await _firebaseToken();
    if (token == null) {
      setState(() => _loading = false);
      Get.snackbar('خطأ', 'لازم تسجل دخول الأول',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final resp = await _tenantData.joinCompany(
      firebaseToken: token,
      inviteCode: codeCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (resp['status'] == StatusRequest.success) {
      final data = (resp['data'] as Map?)?['data'] as Map?;
      if (data != null && data['success'] == true) {
        _auth.hasTenant.value = true;
        Get.snackbar('تم', 'تم الانضمام للشركة بنجاح',
            snackPosition: SnackPosition.BOTTOM);
        Get.offAllNamed(AppRoutes.home);
        return;
      }
    }
    final msg = (resp['data'] as Map?)?['message'] as String? ??
        'كود الدعوة غير صالح';
    Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = _auth.user?.name.split(' ').first ?? '';

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: colors.error),
            onPressed: () => _auth.logout(),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.business_center_outlined,
                  size: 80, color: colors.brand),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'أهلاً $name 👋',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2(context),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'لسه مش جزء من أي شركة. اختر إزاي تحب تبدأ:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s8),
              ElevatedButton.icon(
                onPressed: _loading ? null : _onCreateCompany,
                icon: const Icon(Icons.add_business),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Text('أنشئ شركتك', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              OutlinedButton.icon(
                onPressed: _loading ? null : _onJoinCompany,
                icon: const Icon(Icons.group_add_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Text('انضم لشركة بكود دعوة',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: AppSpacing.s5),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
