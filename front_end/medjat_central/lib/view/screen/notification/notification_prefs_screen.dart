import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../logic/controller/notification/notification_controller.dart';

class NotificationPrefsScreen extends StatelessWidget {
  const NotificationPrefsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    final colors = AppColors.of(context);

    controller.loadPrefs();

    return Scaffold(
      appBar: AppBar(title: Text('notification_settings'.tr)),
      body: Obx(() {
        if (controller.prefsLoading.value && controller.prefs.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            _SectionHeader(title: 'attendance_group'.tr),
            const SizedBox(height: AppSpacing.s2),
            _PrefSwitch(
              title: 'pref_late_absence'.tr,
              subtitle: 'pref_late_absence_desc'.tr,
              icon: Icons.access_time,
              value: controller.prefs['late_absence'] ?? true,
              onChanged: (v) => controller.prefs['late_absence'] = v,
              colors: colors,
            ),
            const SizedBox(height: AppSpacing.s2),
            _PrefSwitch(
              title: 'pref_missing_checkout'.tr,
              subtitle: 'pref_missing_checkout_desc'.tr,
              icon: Icons.logout_outlined,
              value: controller.prefs['missing_checkout'] ?? true,
              onChanged: (v) => controller.prefs['missing_checkout'] = v,
              colors: colors,
            ),
            const SizedBox(height: AppSpacing.s5),
            _SectionHeader(title: 'documents_group'.tr),
            const SizedBox(height: AppSpacing.s2),
            _PrefSwitch(
              title: 'pref_document_expiry'.tr,
              subtitle: 'pref_document_expiry_desc'.tr,
              icon: Icons.description_outlined,
              value: controller.prefs['document_expiry'] ?? true,
              onChanged: (v) => controller.prefs['document_expiry'] = v,
              colors: colors,
            ),
            const SizedBox(height: AppSpacing.s5),
            _SectionHeader(title: 'leave_payroll_group'.tr),
            const SizedBox(height: AppSpacing.s2),
            _PrefSwitch(
              title: 'pref_leave_events'.tr,
              subtitle: 'pref_leave_events_desc'.tr,
              icon: Icons.event_note_outlined,
              value: controller.prefs['leave_events'] ?? true,
              onChanged: (v) => controller.prefs['leave_events'] = v,
              colors: colors,
            ),
            const SizedBox(height: AppSpacing.s2),
            _PrefSwitch(
              title: 'pref_payroll_events'.tr,
              subtitle: 'pref_payroll_events_desc'.tr,
              icon: Icons.payments_outlined,
              value: controller.prefs['payroll_events'] ?? true,
              onChanged: (v) => controller.prefs['payroll_events'] = v,
              colors: colors,
            ),
            const SizedBox(height: AppSpacing.s5),
            Obx(() => SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: controller.prefsLoading.value
                        ? null
                        : () => controller.savePrefs(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: controller.prefsLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'save'.tr,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                )),
            const SizedBox(height: AppSpacing.s5),
          ],
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s1),
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

class _PrefSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColorScheme colors;

  const _PrefSwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.brand,
          ),
        ],
      ),
    );
  }
}
