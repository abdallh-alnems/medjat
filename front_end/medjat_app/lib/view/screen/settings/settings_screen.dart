import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/services/dark_light_service.dart';
import '../../../../logic/controller/auth/auth_controller.dart';
import '../../../../logic/controller/notification/notification_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<DarkLightService>();

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(context, 'المظهر'),
          const SizedBox(height: 8),
          Obx(() => SwitchListTile(
                title: const Text('الوضع الداكن'),
                secondary: Icon(
                  themeService.isDark ? Icons.dark_mode : Icons.light_mode,
                ),
                value: themeService.isDark,
                onChanged: (v) => themeService.toggleTheme(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              )),
          const SizedBox(height: 24),
          _sectionTitle(context, 'الإشعارات'),
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
          _sectionTitle(context, 'عن التطبيق'),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('الإصدار'),
            subtitle: const Text('1.0.0'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'الحساب'),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red.shade700),
            title: Text('تسجيل الخروج',
                style: TextStyle(color: Colors.red.shade700)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            onTap: () {
              Get.dialog<void>(
                AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل تريد تسجيل الخروج؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () {
                        Get.back<void>();
                        Get.find<AuthController>().logout();
                      },
                      child: Text('خروج',
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'ملاحظة: تغيير الجهاز يتطلب كود تفعيل جديد من الإدارة',
            style: AppTextStyles.xs(context).copyWith(
              color: AppColors.textTertiary(context),
            ),
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
        return 'تأخر / غياب';
      case 'missing_checkout':
        return 'نسيان انصراف';
      case 'document_expiry':
        return 'انتهاء مستندات';
      case 'leave_events':
        return 'أحداث الإجازات';
      case 'payroll_events':
        return 'أحداث الرواتب';
      default:
        return key;
    }
  }
}
