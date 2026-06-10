import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/break/break_controller.dart';

class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => BreakController());
    return Scaffold(
      appBar: AppBar(title: Text('break_requests'.tr)),
      body: GetBuilder<BreakController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: controller.loadMyBreaks,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _applyForm(context, controller),
                  const SizedBox(height: 28),
                  _myRequestsSection(context, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _myRequestsSection(BuildContext context, BreakController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('my_break_requests'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: 12),
        if (controller.myBreaksStatus == StatusRequest.loading &&
            controller.myBreaks.isEmpty)
          Text('loading'.tr, style: AppTextStyles.bodySecondary(context))
        else if (controller.myBreaks.isEmpty)
          Text('no_break_requests'.tr,
              style: AppTextStyles.bodySecondary(context))
        else
          ...controller.myBreaks
              .map((b) => _requestCard(context, controller, b)),
      ],
    );
  }

  Widget _requestCard(BuildContext context, BreakController controller,
      Map<String, dynamic> item) {
    final status = (item['status'] as String?) ?? 'pending';
    final date = item['date']?.toString() ?? '';
    final start = item['start_time']?.toString() ?? '';
    final end = item['end_time']?.toString() ?? '';
    final type = (item['type'] as String?) ?? '';
    final reason = item['reason']?.toString();
    final decisionNote = item['decision_note']?.toString();
    final minutes = item['duration_minutes']?.toString();

    final colors = AppColors.of(context);
    final statusColor = _statusColor(colors, status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(type.isEmpty ? 'break_requests'.tr : type,
                    style: AppTextStyles.body(context)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'status_$status'.tr,
                  style: AppTextStyles.xs(context).copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$date   $start - $end'
            '${minutes != null ? '   ($minutes ${'minutes'.tr})' : ''}',
            style: AppTextStyles.bodySecondary(context),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason, style: AppTextStyles.sm(context)),
          ],
          if (status == 'rejected' &&
              decisionNote != null &&
              decisionNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(decisionNote,
                      style: AppTextStyles.sm(context)
                          .copyWith(color: colors.error)),
                ),
              ],
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _confirmCancel(
                    context, controller, (item['id'] as num).toInt()),
                icon: const Icon(Icons.close, size: 18),
                style: TextButton.styleFrom(foregroundColor: colors.error),
                label: Text('cancel_request'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmCancel(
      BuildContext context, BreakController controller, int id) {
    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('cancel_request'.tr),
          content: Text('cancel_request_confirm'.tr),
          actions: [
            TextButton(
                onPressed: () => Get.back<void>(), child: Text('no'.tr)),
            TextButton(
              onPressed: () {
                Get.back<void>();
                controller.cancelBreak(id);
              },
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.of(context).error),
              child: Text('yes'.tr),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AppColorScheme colors, String status) {
    switch (status) {
      case 'approved':
        return colors.success;
      case 'rejected':
        return colors.error;
      case 'cancelled':
        return colors.textTertiary;
      default:
        return colors.warning;
    }
  }

  Widget _applyForm(BuildContext context, BreakController controller) {
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
