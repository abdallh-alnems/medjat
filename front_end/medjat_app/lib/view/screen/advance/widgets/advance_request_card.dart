import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/advance/advance_controller.dart';
import '../../../widget/cancel_confirm_dialog.dart';
import '../../../widget/status_color.dart';

class AdvanceRequestCard extends StatelessWidget {
  final AdvanceController controller;
  final Map<String, dynamic> item;

  const AdvanceRequestCard({
    super.key,
    required this.controller,
    required this.item,
  });

  double _toDouble(dynamic v) => double.tryParse('$v') ?? 0;
  int _toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] as String?) ?? 'pending';
    final total = _toDouble(item['total_amount']);
    final installmentAmount = _toDouble(item['installment_amount']);
    final installmentsCount = _toInt(item['installments_count']);
    final installmentsPaid = _toInt(item['installments_paid']);
    final startMonth = item['start_month']?.toString() ?? '';
    final reason = item['reason']?.toString();

    final colors = AppColors.of(context);
    final statusClr = statusColor(colors, status);
    final progress =
        installmentsCount == 0 ? 0.0 : installmentsPaid / installmentsCount;

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
                child: Text(total.toStringAsFixed(0),
                    style: AppTextStyles.body(context)
                        .copyWith(fontWeight: FontWeight.w600)),
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
            'advance_installment_line'.trParams({
              'amount': installmentAmount.toStringAsFixed(0),
              'count': installmentsCount.toString(),
            }),
            style: AppTextStyles.bodySecondary(context),
          ),
          // Hide the "deduction starts from …" line once the request is no
          // longer going to be deducted, so a cancelled/rejected advance can't
          // be mistaken for an upcoming deduction.
          if (startMonth.isNotEmpty &&
              status != 'cancelled' &&
              status != 'rejected') ...[
            const SizedBox(height: 4),
            Text('advance_start_month_line'.trParams({'month': startMonth}),
                style: AppTextStyles.sm(context)),
          ],
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(reason, style: AppTextStyles.sm(context)),
          ],
          if (status == 'active' || status == 'completed') ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colors.borderHairline,
                valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'advance_progress_line'.trParams({
                'paid': installmentsPaid.toString(),
                'total': installmentsCount.toString(),
              }),
              style: AppTextStyles.sm(context),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showCancelConfirmDialog(
                  context,
                  () =>
                      controller.cancelAdvance((item['id'] as num).toInt()),
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
}
