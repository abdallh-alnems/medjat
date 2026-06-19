import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../data/data_source/remote/tenant_data/tenant_data.dart';
import '../../../data/model/user_model.dart';
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
              Text('create_your_company'.tr,
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: 'company_name'.tr),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'required'.tr : null,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Get.back(result: true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                  child: Text('create'.tr),
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
      Get.snackbar('error'.tr, 'must_login_first'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final resp = await _tenantData.createCompany(
      firebaseToken: token,
      companyName: nameCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (resp['status'] == StatusRequest.success) {
      final data = (resp['data'] as Map?)?['data'] as Map?;
      if (data != null && data['success'] == true) {
        final userJson = _auth.user?.toJson() ?? {};
        final userResp = data['user'] as Map?;
        final tenantResp = data['tenant'] as Map?;
        if (userResp != null) {
          userJson['tenant_id'] = userResp['tenant_id'];
          userJson['role_key'] = userResp['role_key'] ?? userResp['role'];
        } else if (tenantResp != null) {
          userJson['tenant_id'] = tenantResp['id'];
        }
        _auth.user = UserModel.fromJson(userJson);
        await TokenStorageService.saveUserData(jsonEncode(_auth.user!.toJson()));
        _auth.hasTenant.value = true;
        _auth.isLoggedIn.value = true;
        Get.snackbar('done'.tr, 'company_created_success'.tr,
            snackPosition: SnackPosition.BOTTOM);
        unawaited(Get.offAllNamed<void>(AppRoutes.home));
        return;
      }
    }
    final msg =
        (resp['data'] as Map?)?['message'] as String? ?? 'company_creation_failed'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
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
              Text('join_company'.tr,
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: codeCtrl,
                decoration: InputDecoration(labelText: 'invite_code'.tr),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'required'.tr : null,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Get.back(result: true);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                  child: Text('join'.tr),
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
      Get.snackbar('error'.tr, 'must_login_first'.tr,
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
        // Persist the tenant/role returned by the backend onto the cached
        // user. Without this the local user still has tenant_id = 0 and an
        // empty role, so the home page errors out ("حدث خطأ") and only works
        // after a full app restart re-fetches the user. Mirrors create flow.
        final userJson = _auth.user?.toJson() ?? <String, dynamic>{};
        final userResp = data['user'] as Map?;
        final tenantResp = data['tenant'] as Map?;
        if (userResp != null) {
          userJson['tenant_id'] = userResp['tenant_id'];
          userJson['role_key'] = userResp['role_key'] ?? userResp['role'];
          if (userResp['branch_id'] != null) {
            userJson['branch_id'] = userResp['branch_id'];
          }
        } else if (tenantResp != null) {
          userJson['tenant_id'] = tenantResp['id'];
        }
        _auth.user = UserModel.fromJson(userJson);
        await TokenStorageService.saveUserData(jsonEncode(_auth.user!.toJson()));
        _auth.hasTenant.value = true;
        _auth.isLoggedIn.value = true;
        Get.snackbar('done'.tr, 'company_joined_success'.tr,
            snackPosition: SnackPosition.BOTTOM);
        unawaited(Get.offAllNamed<void>(AppRoutes.home));
        return;
      }
    }
    final msg = (resp['data'] as Map?)?['message'] as String? ??
        'invalid_invite_code'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
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
            onPressed: () {
              Get.dialog<void>(AlertDialog(
                title: Text('logout'.tr),
                content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                actions: [
                  TextButton(
                    onPressed: () => Get.back<void>(),
                    child: const Text('إلغاء'),
                  ),
                  TextButton(
                    onPressed: () {
                      Get.back<void>();
                      _auth.logout();
                    },
                    style: TextButton.styleFrom(foregroundColor: colors.error),
                    child: Text('logout'.tr),
                  ),
                ],
              ));
            },
            tooltip: 'logout'.tr,
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
                '${'welcome'.tr} $name 👋',
                textAlign: TextAlign.center,
                style: AppTextStyles.h2(context),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'not_part_of_company'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s8),
              ElevatedButton.icon(
                onPressed: _loading ? null : _onCreateCompany,
                icon: const Icon(Icons.add_business),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Text('create_your_company'.tr, style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              OutlinedButton.icon(
                onPressed: _loading ? null : _onJoinCompany,
                icon: const Icon(Icons.group_add_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  child: Text('join_company_with_code'.tr,
                      style: const TextStyle(fontSize: 16)),
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
