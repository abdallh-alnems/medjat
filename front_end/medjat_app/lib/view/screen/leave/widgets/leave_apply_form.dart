import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/leave/leave_controller.dart';

class LeaveApplyForm extends StatelessWidget {
  final LeaveController controller;

  const LeaveApplyForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final reasonController = TextEditingController();
    String selectedType = 'annual';
    bool rangeMode = false;
    DateTime? singleDate;
    DateTimeRange? range;

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('apply_leave'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: InputDecoration(
                labelText: 'leave_type'.tr,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'annual', child: Text('annual'.tr)),
                DropdownMenuItem(value: 'sick', child: Text('sick'.tr)),
                DropdownMenuItem(value: 'personal', child: Text('personal'.tr)),
                DropdownMenuItem(value: 'unpaid', child: Text('unpaid'.tr)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => selectedType = v);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ChoiceChip(
                  label: Text('leave_single_day'.tr),
                  selected: !rangeMode,
                  onSelected: (_) => setState(() => rangeMode = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('leave_period_mode'.tr),
                  selected: rangeMode,
                  onSelected: (_) => setState(() => rangeMode = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final now = DateTime.now();
                final firstDate = DateTime(now.year, now.month, now.day);
                final lastDate = now.add(const Duration(days: 365));
                if (rangeMode) {
                  final picked = await showDateRangePicker(
                    context: context,
                    initialDateRange: range,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (picked != null) setState(() => range = picked);
                } else {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: singleDate ?? now,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (picked != null) setState(() => singleDate = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: rangeMode ? 'leave_period'.tr : 'date'.tr,
                  border: const OutlineInputBorder(),
                  suffixIcon: Icon(
                      rangeMode ? Icons.date_range : Icons.calendar_today),
                ),
                child: Text(
                  rangeMode
                      ? (range == null
                          ? 'choose_period'.tr
                          : '${fmt(range!.start)}  →  ${fmt(range!.end)}'
                              '   (${'leave_days_count'.trParams({'count': '${range!.duration.inDays + 1}'})})')
                      : (singleDate == null
                          ? 'choose_date'.tr
                          : fmt(singleDate!)),
                  style: (rangeMode ? range == null : singleDate == null)
                      ? AppTextStyles.bodySecondary(context)
                      : AppTextStyles.body(context),
                ),
              ),
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
            GetBuilder<LeaveController>(
              builder: (ctrl) {
                if (!ctrl.canApply) {
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
                          child: Text(
                            'leave_pending_limit_msg'.tr,
                            style: AppTextStyles.sm(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return PrimaryButton(
                  text: 'submit_request'.tr,
                  isLoading: ctrl.applyStatus == StatusRequest.loading,
                  onPressed: () async {
                    final String start;
                    final String end;
                    if (rangeMode) {
                      if (range == null) {
                        Get.snackbar('error'.tr, 'choose_date'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      start = fmt(range!.start);
                      end = fmt(range!.end);
                    } else {
                      if (singleDate == null) {
                        Get.snackbar('error'.tr, 'choose_date'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      start = fmt(singleDate!);
                      end = start;
                    }
                    if (selectedType == 'annual') {
                      final remaining = int.tryParse(
                          ctrl.balance?['remaining_days']?.toString() ?? '');
                      final days = DateTime.parse(end)
                              .difference(DateTime.parse(start))
                              .inDays +
                          1;
                      if (remaining != null && days > remaining) {
                        Get.snackbar(
                          'error'.tr,
                          'leave_balance_insufficient'.trParams({
                            'remaining': '$remaining',
                            'days': '$days',
                          }),
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        return;
                      }
                    }
                    final ok = await ctrl.applyLeave(
                      date: start,
                      type: selectedType,
                      reason: reasonController.text.isEmpty
                          ? null
                          : reasonController.text,
                      startDate: start,
                      endDate: end,
                    );
                    if (ok) {
                      reasonController.clear();
                      setState(() {
                        range = null;
                        singleDate = null;
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
}
