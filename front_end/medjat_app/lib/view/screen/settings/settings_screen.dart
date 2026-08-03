import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/services/dark_light_service.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../logic/controller/auth/auth_controller.dart';
import '../../../../logic/controller/notification/notification_controller.dart';
import '../../widget/ad/top_native_ad.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<DarkLightService>();

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TopNativeAd(tabIndex: 3, horizontalMargin: 0),
          _sectionTitle(context, 'language'.tr),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text('language'.tr),
            trailing: Obx(() {
              final localeSvc = Get.find<LocaleService>();
              return Text(
                localeSvc.isArabic ? 'العربية' : 'English',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                ),
              );
            }),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onTap: () => _showLanguageSheet(context),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'appearance'.tr),
          const SizedBox(height: 8),
          Obx(
            () => SwitchListTile(
              title: Text('dark_mode'.tr),
              secondary: Icon(
                themeService.isDark ? Icons.dark_mode : Icons.light_mode,
              ),
              value: themeService.isDark,
              onChanged: (v) => themeService.toggleTheme(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'notification_prefs'.tr),
          const SizedBox(height: 8),
          GetBuilder<NotificationController>(
            init: NotificationController(),
            builder: (controller) {
              return Column(
                children: controller.prefs.entries.map((entry) {
                  return SwitchListTile(
                    title: Text(_prefLabel(entry.key)),
                    value: entry.value,
                    onChanged: (v) => controller.updatePref(entry.key, v),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'about_app'.tr),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('version'.tr),
            subtitle: const Text('1.0.0'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'account'.tr),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade700),
            title: Text(
              'logout'.tr,
              style: TextStyle(color: Colors.red.shade700),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onTap: () {
              Get.dialog<void>(
                AlertDialog(
                  title: Text('logout'.tr),
                  content: Text('logout_confirm'.tr),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      child: Text('cancel'.tr),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.back<void>();
                        Get.find<AuthController>().logout();
                      },
                      child: Text(
                        'exit'.tr,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'device_change_note'.tr,
            style: AppTextStyles.xs(
              context,
            ).copyWith(color: AppColors.textTertiary(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(title, style: AppTextStyles.h3(context)),
    );
  }

  String _prefLabel(String key) {
    switch (key) {
      case 'late_absence':
        return 'late_absence'.tr;
      case 'missing_checkout':
        return 'missing_checkout'.tr;
      case 'document_expiry':
        return 'document_expiry'.tr;
      case 'leave_events':
        return 'leave_events'.tr;
      case 'payroll_events':
        return 'payroll_events'.tr;
      default:
        return key;
    }
  }

  void _showLanguageSheet(BuildContext context) {
    final localeSvc = Get.find<LocaleService>();
    final colors = AppColors.of(context);

    Get.bottomSheet<void>(
      // A Material — not a coloured Container — paints the sheet background.
      // ListTile draws its selected tint and ink splashes onto the nearest
      // Material ancestor, so a coloured box in between would cover them (and
      // Flutter asserts about it in debug).
      Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s4),
                decoration: BoxDecoration(
                  color: colors.borderStrong,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              Text('language'.tr, style: AppTextStyles.h3(context)),
              const SizedBox(height: AppSpacing.s4),
              _LanguageOption(
                label: 'العربية',
                code: 'ar',
                localeSvc: localeSvc,
                colors: colors,
              ),
              const SizedBox(height: AppSpacing.s2),
              _LanguageOption(
                label: 'English',
                code: 'en',
                localeSvc: localeSvc,
                colors: colors,
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String code;
  final LocaleService localeSvc;
  final AppColorScheme colors;

  const _LanguageOption({
    required this.label,
    required this.code,
    required this.localeSvc,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = localeSvc.locale.value.languageCode == code;
      return ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        tileColor: isSelected ? colors.brand.withValues(alpha: 0.08) : null,
        leading: Icon(
          isSelected
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: isSelected ? colors.brand : colors.textTertiary,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {
          Get.back<void>();
          if (isSelected) return;
          localeSvc.setLocale(code);
        },
      );
    });
  }
}
