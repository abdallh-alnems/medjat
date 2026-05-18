import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/settings/settings_controller.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = Get.put<SettingsController>(SettingsController());
    final auth = Get.find<AuthController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          if (auth.user?.canManageBranches == true) ...[
            const _SectionHeader(title: 'الشركة'),
            _SettingTile(
              icon: Icons.tune_outlined,
              title: 'قواعد الخصم والإضافي',
              subtitle: 'تحديد قواعد التأخير والغياب',
              onTap: () {},
            ),
            _SettingTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'إدارة الصلاحيات',
              subtitle: 'الأدوار والمستخدمين',
              onTap: () {},
            ),
            _SettingTile(
              icon: Icons.business_outlined,
              title: 'بيانات الشركة',
              subtitle: 'تعديل معلومات الشركة',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.s5),
          ],
          const _SectionHeader(title: 'التطبيق'),
          _SettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'الوضع الداكن',
            subtitle: 'تفعيل الوضع الداكن',
            trailing: Obx(() => Switch.adaptive(
                  value: settingsCtrl.isDark,
                  onChanged: (_) => settingsCtrl.toggleTheme(),
                )),
            onTap: () => settingsCtrl.toggleTheme(),
          ),
          _SettingTile(
            icon: Icons.lock_outline,
            title: 'تغيير كلمة السر',
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.s5),
          const _SectionHeader(title: 'الحساب'),
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s3),
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.brandSubtle,
                  child: Text(
                    (auth.user?.name.isNotEmpty ?? false)
                        ? auth.user!.name[0]
                        : '?',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.brand,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.user?.name ?? 'مدير',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        auth.user?.email ?? '',
                        style: AppTextStyles.sm(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Center(
            child: TextButton(
              onPressed: settingsCtrl.logout,
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.04,
          color: AppColors.of(context).textTertiary,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s2),
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.sm(context),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(Icons.chevron_left, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
