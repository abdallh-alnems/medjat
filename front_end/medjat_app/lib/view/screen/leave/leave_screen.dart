import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/leave/leave_controller.dart';
import 'widgets/leave_edit_sheet.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => LeaveController());
    return Scaffold(
      appBar: AppBar(title: Text('leaves'.tr)),
      body: GetBuilder<LeaveController>(
        builder: (controller) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _balanceSection(context, controller),
                const SizedBox(height: 24),
                _applyForm(context, controller),
                const SizedBox(height: 28),
                _myRequestsSection(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _balanceSection(BuildContext context, LeaveController controller) {
    final balance = controller.balance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('leave_balance'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: 12),
          if (balance != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(context, 'balance'.tr, balance['total_days']?.toString() ?? '0'),
                _statItem(context, 'used'.tr, balance['used_days']?.toString() ?? '0'),
                _statItem(context, 'remaining'.tr, balance['remaining_days']?.toString() ?? '0'),
              ],
            )
          else
            Text('loading'.tr, style: AppTextStyles.bodySecondary(context)),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.h2(context)),
        Text(label, style: AppTextStyles.xs(context)),
      ],
    );
  }

  /// 0 = current (active), 1 = ended (date passed), 2 = rejected.
  int _leaveCategory(Map<String, dynamic> leave) {
    final status = (leave['status'] as String?) ?? 'pending';
    if (status == 'rejected') return 2;
    final start = leave['start_date']?.toString() ?? '';
    final end = leave['end_date']?.toString() ?? '';
    if (_isPast(end.isEmpty ? start : end)) return 1;
    return 0;
  }

  Widget _myRequestsSection(BuildContext context, LeaveController controller) {
    final colors = AppColors.of(context);
    final current =
        controller.myLeaves.where((l) => _leaveCategory(l) == 0).toList();
    final ended =
        controller.myLeaves.where((l) => _leaveCategory(l) == 1).toList();
    final rejected =
        controller.myLeaves.where((l) => _leaveCategory(l) == 2).toList();
    final tab = controller.requestsTab;
    final list = tab == 0 ? current : (tab == 1 ? ended : rejected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('my_leave_requests'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tabButton(context, colors,
                  label: 'leave_tab_current'.tr,
                  count: current.length,
                  selected: tab == 0,
                  onTap: () => controller.setRequestsTab(0)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tabButton(context, colors,
                  label: 'leave_tab_ended'.tr,
                  count: ended.length,
                  selected: tab == 1,
                  onTap: () => controller.setRequestsTab(1)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tabButton(context, colors,
                  label: 'leave_tab_rejected'.tr,
                  count: rejected.length,
                  selected: tab == 2,
                  onTap: () => controller.setRequestsTab(2)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.myLeavesStatus == StatusRequest.loading &&
            controller.myLeaves.isEmpty)
          Text('loading'.tr, style: AppTextStyles.bodySecondary(context))
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('no_leave_requests'.tr,
                style: AppTextStyles.bodySecondary(context)),
          )
        else
          ...list.map((l) => _requestCard(context, controller, l)),
      ],
    );
  }

  Widget _tabButton(BuildContext context, AppColorScheme colors,
      {required String label,
      required int count,
      required bool selected,
      required VoidCallback onTap}) {
    final brand = AppColors.brand(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? brand.withValues(alpha: 0.12) : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? brand : colors.borderHairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sm(context).copyWith(
                  color: selected ? brand : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? brand
                      : colors.textTertiary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.xs(context).copyWith(
                    color: selected ? Colors.white : colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _requestCard(
      BuildContext context, LeaveController controller, Map<String, dynamic> leave) {
    final status = (leave['status'] as String?) ?? 'pending';
    final start = leave['start_date']?.toString() ?? '';
    final end = leave['end_date']?.toString() ?? '';
    final days = leave['days']?.toString() ?? '1';
    final type = (leave['type'] as String?) ?? 'annual';
    final reason = leave['reason']?.toString();
    final rejectionReason = leave['rejection_reason']?.toString();

    final dateLabel = (end.isEmpty || end == start)
        ? start
        : '$start  →  $end  (${'leave_days_count'.trParams({'count': days})})';

    final colors = AppColors.of(context);
    final isPast = _isPast(end.isEmpty ? start : end);
    // A finished leave (date passed) shows "انتهت" instead of its status,
    // except a rejected one which keeps its meaningful outcome.
    final isEnded = isPast && status != 'rejected';
    final chipColor = isEnded ? colors.textTertiary : _statusColor(colors, status);
    final chipLabel = isEnded ? 'leave_ended'.tr : 'status_$status'.tr;

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
                child: Text(type.tr, style: AppTextStyles.body(context)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEnded) ...[
                      Icon(Icons.history_toggle_off,
                          size: 12, color: chipColor),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      chipLabel,
                      style: AppTextStyles.xs(context).copyWith(
                        color: chipColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dateLabel,
            style: AppTextStyles.bodySecondary(context).copyWith(
              decoration: isPast ? TextDecoration.lineThrough : null,
              color: isPast ? colors.textTertiary : null,
            ),
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason, style: AppTextStyles.sm(context)),
          ],
          if (status == 'rejected' &&
              rejectionReason != null &&
              rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(rejectionReason,
                      style: AppTextStyles.sm(context)
                          .copyWith(color: colors.error)),
                ),
              ],
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      showLeaveEditSheet(context, controller, leave),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text('edit'.tr),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _confirmCancel(context, controller,
                      (leave['id'] as num).toInt()),
                  icon: const Icon(Icons.close, size: 18),
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  label: Text('cancel_request'.tr),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// True when the given yyyy-MM-dd date is strictly before today.
  bool _isPast(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today);
  }

  void _confirmCancel(
      BuildContext context, LeaveController controller, int id) {
    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('cancel_request'.tr),
          content: Text('cancel_request_confirm'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: Text('no'.tr),
            ),
            TextButton(
              onPressed: () {
                Get.back<void>();
                controller.cancelLeave(id);
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
      default:
        return colors.warning;
    }
  }

  Widget _applyForm(BuildContext context, LeaveController controller) {
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
              value: selectedType,
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
                    // Annual leave can't exceed the remaining balance.
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
