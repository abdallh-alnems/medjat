import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/leave/leave_controller.dart';
import '../../../widget/cancel_confirm_dialog.dart';
import '../../../widget/status_color.dart';
import 'leave_edit_sheet.dart';

class LeaveRequestCard extends StatelessWidget {
  final LeaveController controller;
  final Map<String, dynamic> leave;

  const LeaveRequestCard({
    super.key,
    required this.controller,
    required this.leave,
  });

  @override
  Widget build(BuildContext context) {
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
    final isEnded = isPast && status != 'rejected';
    final chipColor = isEnded ? colors.textTertiary : statusColor(colors, status);
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
                  onPressed: () => showCancelConfirmDialog(
                    context,
                    () => controller.cancelLeave((leave['id'] as num).toInt()),
                  ),
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

  bool _isPast(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today);
  }
}
