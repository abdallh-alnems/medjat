import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/force_update/force_update_controller.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final versionCtl = TextEditingController();
    final messageCtl = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('تحديث إجباري')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.s5),
            Text(
              'إرسال تحديث إجباري يمنع النسخ القديمة من العمل حتى يتم التحديث.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.light
                    ? AppColors.light.textSecondary
                    : AppColors.dark.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            GetBuilder<ForceUpdateController>(
              builder: (controller) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: controller.platform.value,
                      decoration: const InputDecoration(labelText: 'المنصة'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('الكل')),
                        DropdownMenuItem(value: 'android', child: Text('Android')),
                        DropdownMenuItem(value: 'ios', child: Text('iOS')),
                      ],
                      onChanged: (v) {
                        if (v != null) controller.platform.value = v;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'أقل إصدار مسموح',
                      hint: '2.5.0',
                      controller: versionCtl,
                      validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'رسالة التحديث (اختياري)',
                      hint: 'يرجى تحديث التطبيق للمتابعة',
                      controller: messageCtl,
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    PrimaryButton(
                      text: 'إرسال التحديث الإجباري',
                      isLoading: controller.status.value.name == 'loading',
                      onPressed: () {
                        if (versionCtl.text.isEmpty) {
                          Get.snackbar('خطأ', 'يرجى إدخال رقم الإصدار', snackPosition: SnackPosition.BOTTOM);
                          return;
                        }
                        controller.minVersion.value = versionCtl.text.trim();
                        controller.message.value = messageCtl.text.trim();
                        controller.trigger();
                      },
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
