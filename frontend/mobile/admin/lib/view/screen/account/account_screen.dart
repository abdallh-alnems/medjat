import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../logic/controller/account/account_controller.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../shared/panel_widgets.dart';

/// Our own account. Small on purpose — but it holds the one thing whose absence
/// meant editing the production database by hand: changing the password.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: GetBuilder<AccountController>(
        builder: (controller) {
          return GetBuilder<AuthController>(
            builder: (auth) {
              final admin = auth.admin;

              return RefreshIndicator(
                onRefresh: controller.loadProfile,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    AppSpacing.s4,
                    AppSpacing.s4,
                    AppSpacing.s8,
                  ),
                  children: [
                    PanelCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin?.displayNameOrUsername ?? '—',
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s2),
                          StatusPill(
                            text: admin?.roleLabelAr ?? '—',
                            tone: PillTone.brand,
                          ),
                        ],
                      ),
                    ),
                    PanelCard(
                      title: 'الجلسة',
                      child: Column(
                        children: [
                          InfoRow(label: 'اسم المستخدم', value: admin?.username ?? '—'),
                          InfoRow(label: 'البريد', value: admin?.email ?? '—', numeric: true),
                          InfoRow(
                            label: 'آخر دخول',
                            value: relativeAge(admin?.lastLoginAt, never: '—'),
                          ),
                          InfoRow(
                            label: 'آخر IP',
                            value: admin?.lastLoginIp ?? '—',
                            numeric: true,
                          ),
                          InfoRow(
                            label: 'أجهزة مسجّل دخولها',
                            value: '${admin?.activeSessions ?? 0}',
                            numeric: true,
                          ),
                        ],
                      ),
                    ),
                    PanelCard(
                      title: 'الأمان',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تغيير كلمة المرور يسجّل خروج بقية الأجهزة تلقائيًا.',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 12,
                              color: panelColors(context).textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s3),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: OutlinedButton.icon(
                              onPressed: () => _showPasswordSheet(context, controller),
                              icon: const Icon(Icons.lock_outline, size: 18),
                              label: const Text('تغيير كلمة المرور'),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _AppVersionCard(),
                    const SizedBox(height: AppSpacing.s2),
                    TextButton.icon(
                      onPressed: () => Get.find<AuthController>().logout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج'),
                      style: TextButton.styleFrom(
                        foregroundColor: panelColors(context).error,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

void _showPasswordSheet(BuildContext context, AccountController controller) {
  final currentCtl = TextEditingController();
  final newCtl = TextEditingController();
  final confirmCtl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  Get.bottomSheet<void>(
    SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.s4,
          right: AppSpacing.s4,
          top: AppSpacing.s4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تغيير كلمة المرور',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: currentCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
                validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: newCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
                validator: (v) =>
                    (v == null || v.length < 8) ? '8 أحرف على الأقل' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: confirmCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
                validator: (v) => v != newCtl.text ? 'غير متطابقة' : null,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final changed = await controller.changePassword(
                    currentPassword: currentCtl.text,
                    newPassword: newCtl.text,
                  );
                  if (changed) Get.back<void>();
                },
                child: const Text('حفظ'),
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
          ),
        ),
      ),
    ),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    isScrollControlled: true,
  );
}

class _AppVersionCard extends StatelessWidget {
  const _AppVersionCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return PanelCard(
          title: 'التطبيق',
          child: InfoRow(
            label: 'الإصدار',
            value: info == null ? '—' : '${info.version} (${info.buildNumber})',
            numeric: true,
          ),
        );
      },
    );
  }
}
