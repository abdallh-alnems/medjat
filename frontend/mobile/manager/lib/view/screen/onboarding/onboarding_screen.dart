import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/services/locale_defaults.dart';
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

    // A code arrived via the email's "open the app and join" deep link — join
    // automatically now that we're on the onboarding screen and signed in.
    final code = _auth.pendingInviteCode;
    if (code != null && code.isNotEmpty) {
      _auth.pendingInviteCode = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _joinWithCode(code);
      });
    }
  }

  static const String _supportEmail = 'support@permedjat.com';

  Future<String?> _firebaseToken() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return null;
    return fbUser.getIdToken();
  }

  Future<void> _onContactSupport() async {
    final email = _auth.user?.email ?? '';
    final body = email.isEmpty ? '' : '\n\n---\n$email';
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('support_email_subject'.tr)}'
          '&body=${Uri.encodeComponent(body)}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar('error'.tr, 'cannot_open_email'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _onCreateCompany() async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();

    // Captured here rather than left to the backend defaults: attendance is
    // stamped on the company's clock, so a company that never picks a timezone
    // records every check-in against a guess. Seeded from the device so the
    // usual case is a glance, not four decisions.
    final detectedZone = await LocaleDefaults.detectTimezone();
    final zoneOptions = <String>{
      detectedZone,
      ...LocaleDefaults.commonTimezones,
    }.toList();

    var timezone = detectedZone;
    var currency = LocaleDefaults.currencyForZone(detectedZone);
    var cycleStartDay = 1;
    var weekStartDay = LocaleDefaults.weekStartForZone(detectedZone);

    if (!mounted) return;

    final submitted = await Get.bottomSheet<bool>(
      StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.s5,
            right: AppSpacing.s5,
            top: AppSpacing.s5,
            bottom:
                MediaQuery.of(Get.context!).viewInsets.bottom + AppSpacing.s5,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('create_your_company'.tr,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.s4),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: 'company_name'.tr),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'required'.tr : null,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text('onboarding_locale_hint'.tr,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Theme.of(context).hintColor)),
                  const SizedBox(height: AppSpacing.s3),
                  DropdownButtonFormField<String>(
                    initialValue: timezone,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: 'timezone_label'.tr),
                    items: [
                      for (final z in zoneOptions)
                        DropdownMenuItem(
                            value: z, child: Text(z.replaceAll('_', ' '))),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setSheetState(() {
                        timezone = v;
                        currency = LocaleDefaults.currencyForZone(v);
                        weekStartDay = LocaleDefaults.weekStartForZone(v);
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: 'currency_label'.tr),
                    items: [
                      for (final c in LocaleDefaults.currencies)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => currency = v ?? currency),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DropdownButtonFormField<int>(
                    initialValue: cycleStartDay,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: 'cycle_start_day_label'.tr),
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => cycleStartDay = v ?? cycleStartDay),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DropdownButtonFormField<int>(
                    initialValue: weekStartDay,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: 'week_start_day_label'.tr),
                    items: [
                      for (final e in LocaleDefaults.weekdays.entries)
                        DropdownMenuItem(
                            value: e.key, child: Text(e.value.tr)),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => weekStartDay = v ?? weekStartDay),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Get.back(result: true);
                      }
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                      child: Text('create'.tr),
                    ),
                  ),
                ],
              ),
            ),
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
      timezone: timezone,
      currency: currency,
      cycleStartDay: cycleStartDay,
      weekStartDay: weekStartDay,
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
    await _joinWithCode(codeCtrl.text.trim());
  }

  /// Joins a company with an invite [code] — shared by the manual "enter code"
  /// sheet and the email deep-link hand-off.
  Future<void> _joinWithCode(String code) async {
    if (code.isEmpty) return;
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
      inviteCode: code,
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
        _auth.pendingInvitation = null;
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

  String _roleLabel(String role) {
    switch (role) {
      case 'general_manager':
        return 'role_general_manager'.tr;
      case 'hr':
        return 'role_hr'.tr;
      case 'branch_manager':
        return 'role_branch_manager'.tr;
      case 'attendance':
        return 'role_attendance'.tr;
      case 'viewer':
        return 'role_viewer'.tr;
      default:
        return role;
    }
  }

  /// One-tap accept of an invitation already addressed to this email (no code).
  Future<void> _onAcceptInvitation() async {
    setState(() => _loading = true);
    final token = await _firebaseToken();
    if (token == null) {
      setState(() => _loading = false);
      Get.snackbar('error'.tr, 'must_login_first'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final invId =
        (_auth.pendingInvitation?['invitation_id'] as num?)?.toInt();
    final resp = await _tenantData.acceptInvitation(
      firebaseToken: token,
      invitationId: invId,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (resp['status'] == StatusRequest.success) {
      final data = (resp['data'] as Map?)?['data'] as Map?;
      if (data != null && data['success'] == true) {
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
        _auth.pendingInvitation = null;
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
    final invite = _auth.pendingInvitation;

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
              if (invite != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  decoration: BoxDecoration(
                    color: colors.brandSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border:
                        Border.all(color: colors.brand.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mark_email_read_outlined,
                              color: colors.brand),
                          const SizedBox(width: AppSpacing.s2),
                          Expanded(
                            child: Text('pending_invitation_title'.tr,
                                style: AppTextStyles.h3(context)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Text(
                        '${invite['company_name'] ?? ''} · '
                        '${_roleLabel(invite['role']?.toString() ?? '')}',
                        style: AppTextStyles.bodySecondary(context),
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _onAcceptInvitation,
                          icon: const Icon(Icons.check),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s2),
                            child: Text('accept_and_join'.tr,
                                style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
              ],
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
              const SizedBox(height: AppSpacing.s8),
              Text(
                'need_help_question'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textTertiary),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _onContactSupport,
                icon: const Icon(Icons.support_agent_outlined, size: 20),
                label: Text('contact_support'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
