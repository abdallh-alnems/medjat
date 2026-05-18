import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/notification/notification_controller.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final titleCtl = TextEditingController();
    final bodyCtl = TextEditingController();
    final tenantIdCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(title: const Text('إرسال إشعارات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.s5),
              GetBuilder<NotificationController>(
                builder: (controller) {
                  return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'إرسال لشركة محددة',
                      style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 15),
                    ),
                    value: controller.isTenantSpecific.value,
                    onChanged: (v) {
                      controller.isTenantSpecific.value = v;
                      controller.update();
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s3),
              GetBuilder<NotificationController>(
                builder: (controller) {
                  if (controller.isTenantSpecific.value) {
                    return Column(
                      children: [
                        PrimaryInput(
                          label: 'رقم الشركة (Tenant ID)',
                          hint: '1',
                          controller: tenantIdCtl,
                          keyboardType: TextInputType.number,
                          validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                        ),
                        const SizedBox(height: AppSpacing.s3),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              PrimaryInput(
                label: 'عنوان الإشعار',
                controller: titleCtl,
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'نص الإشعار',
                controller: bodyCtl,
                maxLines: 3,
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s6),
              GetBuilder<NotificationController>(
                builder: (controller) {
                  return PrimaryButton(
                    text: 'إرسال الإشعار',
                    isLoading: controller.status.value.name == 'loading',
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        final ctrl = Get.find<NotificationController>();
                        if (ctrl.isTenantSpecific.value) {
                          ctrl.selectedTenantId.value = int.tryParse(tenantIdCtl.text) ?? 0;
                        }
                        ctrl.sendNotification(
                          title: titleCtl.text.trim(),
                          body: bodyCtl.text.trim(),
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s8),
            ],
          ),
        ),
      ),
    );
  }
}
