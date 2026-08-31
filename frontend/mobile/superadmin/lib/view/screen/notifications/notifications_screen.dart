import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/notification/notification_controller.dart';
import '../shared/panel_widgets.dart';

/// Composing an announcement: pick the company from a list (not by typing a
/// raw id), and pick who receives it — managers, employees, or both.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _titleCtl = TextEditingController();
  final _bodyCtl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleCtl.dispose();
    _bodyCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إرسال إشعارات')),
      body: GetBuilder<NotificationController>(
        builder: (controller) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.s4),
                  PanelCard(
                    title: 'من يستقبل الإشعار؟',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.s2,
                          children: NotificationController.audienceLabels.entries
                              .map(
                                (e) => _Choice(
                                  label: e.value,
                                  selected: controller.audience.value == e.key,
                                  onTap: () => controller.setAudience(e.key),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          controller.audience.value == 'admins'
                              ? 'مديرو الشركات على تطبيق الإدارة فقط — لن يصل للموظفين.'
                              : controller.audience.value == 'employees'
                                  ? 'موظفو الشركات على تطبيق الموظف فقط.'
                                  : 'المديرون والموظفون معًا.',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PanelCard(
                    title: 'النطاق',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'شركة محددة',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 14,
                            ),
                          ),
                          value: controller.isTenantSpecific.value,
                          onChanged: (v) {
                            controller.isTenantSpecific.value = v;
                            if (v) controller.loadTenants();
                            controller.update();
                          },
                        ),
                        if (controller.isTenantSpecific.value)
                          InkWell(
                            onTap: () => _pickTenant(controller),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.s3),
                              decoration: BoxDecoration(
                                border: Border.all(color: colors.borderHairline),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.business, size: 18, color: colors.brand),
                                  const SizedBox(width: AppSpacing.s2),
                                  Expanded(
                                    child: Text(
                                      controller.selectedTenantName.value.isEmpty
                                          ? 'اختر الشركة'
                                          : controller.selectedTenantName.value,
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 14,
                                        color: controller.selectedTenantName.value.isEmpty
                                            ? colors.textTertiary
                                            : colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.expand_more, color: colors.textTertiary),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  PrimaryInput(
                    label: 'عنوان الإشعار',
                    controller: _titleCtl,
                    validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'نص الإشعار',
                    controller: _bodyCtl,
                    maxLines: 3,
                    validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  PrimaryButton(
                    text: 'إرسال الإشعار',
                    isLoading: controller.status.value.name == 'loading',
                    onPressed: () async {
                      if (!_formKey.currentState!.validate()) return;
                      final sent = await controller.sendNotification(
                        title: _titleCtl.text.trim(),
                        body: _bodyCtl.text.trim(),
                      );
                      if (sent) {
                        _titleCtl.clear();
                        _bodyCtl.clear();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void _pickTenant(NotificationController controller) {
  Get.bottomSheet<void>(
    SafeArea(
      child: Container(
        color: Get.theme.scaffoldBackgroundColor,
        constraints: BoxConstraints(maxHeight: Get.height * 0.7),
        child: Obx(
          () => controller.tenantsLoading.value
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.s7),
                  child: Center(child: CircularProgressIndicator()),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  itemCount: controller.tenants.length,
                  itemBuilder: (context, index) {
                    final tenant = controller.tenants[index];
                    return ListTile(
                      title: Text(
                        tenant.name,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '${tenant.employeeCount} موظف',
                        style: const TextStyle(fontFamily: 'Geist', fontSize: 12),
                      ),
                      trailing: tenant.isActiveTenant
                          ? null
                          : const StatusPill(text: 'متوقفة', tone: PillTone.error),
                      onTap: () {
                        controller.selectTenant(tenant);
                        Get.back<void>();
                      },
                    );
                  },
                ),
        ),
      ),
    ),
    backgroundColor: Get.theme.scaffoldBackgroundColor,
  );
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : Colors.transparent,
          border: Border.all(color: selected ? colors.brand : colors.borderHairline),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
