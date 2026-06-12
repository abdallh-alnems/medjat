import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/break/break_controller.dart';
import '../../../widget/cancel_confirm_dialog.dart';
import '../../../widget/status_color.dart';

class BreakRequestCard extends StatelessWidget {
  final BreakController controller;
  final Map<String, dynamic> item;

  const BreakRequestCard({
    super.key,
    required this.controller,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] as String?) ?? 'pending';
    final date = item['date']?.toString() ?? '';
    final start = item['start_time']?.toString() ?? '';
    final end = item['end_time']?.toString() ?? '';
    final type = (item['type'] as String?) ?? '';
    final reason = item['reason']?.toString();
    final decisionNote = item['decision_note']?.toString();
    final minutes = item['duration_minutes']?.toString();
    final suggestedDate = item['suggested_date']?.toString();
    final suggestedStart = item['suggested_start_time']?.toString();
    final suggestedEnd = item['suggested_end_time']?.toString();

    final colors = AppColors.of(context);
    final statusClr = statusColor(colors, status);

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
                  color: statusClr.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'status_$status'.tr,
                  style: AppTextStyles.xs(context).copyWith(
                    color: statusClr,
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
          if (status == 'postponed') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: colors.warning),
                      const SizedBox(width: 6),
                      Text('break_suggested_time'.tr,
                          style: AppTextStyles.sm(context).copyWith(
                            color: colors.warning,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  if (suggestedDate != null && suggestedDate.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$suggestedDate   ${suggestedStart ?? ''} - ${suggestedEnd ?? ''}',
                      style: AppTextStyles.body(context),
                    ),
                  ],
                  if (decisionNote != null && decisionNote.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(decisionNote, style: AppTextStyles.sm(context)),
                  ],
                  if (suggestedDate != null && suggestedDate.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => controller.respondPostpone(
                                (item['id'] as num).toInt(), 'accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.success,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('break_accept_suggested'.tr),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _confirmRejectPostpone(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                            ),
                            child: Text('break_reject_suggested'.tr),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showCancelConfirmDialog(
                  context,
                  () => controller.cancelBreak((item['id'] as num).toInt()),
                ),
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

  void _confirmRejectPostpone(BuildContext context) {
    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('break_reject_suggested'.tr),
          content: Text('break_reject_suggested_confirm'.tr),
          actions: [
            TextButton(
                onPressed: () => Get.back<void>(), child: Text('no'.tr)),
            TextButton(
              onPressed: () {
                Get.back<void>();
                controller.respondPostpone(
                    (item['id'] as num).toInt(), 'reject');
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
}
