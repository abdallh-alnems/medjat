import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/break/break_controller.dart';

class BreakApplyForm extends StatelessWidget {
  final BreakController controller;

  const BreakApplyForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final typeController = TextEditingController();
    final reasonController = TextEditingController();
    DateTime? date;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return StatefulBuilder(
      builder: (context, setState) {
        Future<void> pickTime(bool isStart) async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (picked != null) {
            setState(() {
              if (isStart) {
                startTime = picked;
              } else {
                endTime = picked;
              }
            });
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('request_break'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: 16),
            TextField(
              controller: typeController,
              decoration: InputDecoration(
                labelText: 'break_type'.tr,
                hintText: 'break_type_hint'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? now,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => date = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'date'.tr,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  date == null ? 'choose_date'.tr : fmtDate(date!),
                  style: date == null
                      ? AppTextStyles.bodySecondary(context)
                      : AppTextStyles.body(context),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _timeField(context, 'break_start_time'.tr,
                      startTime == null ? null : fmtTime(startTime!),
                      () => pickTime(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _timeField(context, 'break_end_time'.tr,
                      endTime == null ? null : fmtTime(endTime!),
                      () => pickTime(false)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'reason_optional'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GetBuilder<BreakController>(
              builder: (ctrl) {
                if (!ctrl.canRequest) {
                  final colors = AppColors.of(context);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: colors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: colors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('break_pending_limit_msg'.tr,
                              style: AppTextStyles.sm(context)),
                        ),
                      ],
                    ),
                  );
                }
                return PrimaryButton(
                  text: 'submit_request'.tr,
                  isLoading: ctrl.requestStatus == StatusRequest.loading,
                  onPressed: () async {
                    if (date == null) {
                      Get.snackbar('error'.tr, 'choose_date'.tr,
                          snackPosition: SnackPosition.BOTTOM);
                      return;
                    }
                    if (startTime == null || endTime == null) {
                      Get.snackbar('error'.tr, 'break_select_time'.tr,
                          snackPosition: SnackPosition.BOTTOM);
                      return;
                    }
                    final ok = await ctrl.requestBreak(
                      date: fmtDate(date!),
                      startTime: fmtTime(startTime!),
                      endTime: fmtTime(endTime!),
                      type: typeController.text.trim(),
                      reason: reasonController.text.isEmpty
                          ? null
                          : reasonController.text,
                    );
                    if (ok) {
                      typeController.clear();
                      reasonController.clear();
                      setState(() {
                        date = null;
                        startTime = null;
                        endTime = null;
                      });
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _timeField(
      BuildContext context, String label, String? value, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          value ?? 'choose_time'.tr,
          style: value == null
              ? AppTextStyles.bodySecondary(context)
              : AppTextStyles.body(context),
        ),
      ),
    );
  }
}
