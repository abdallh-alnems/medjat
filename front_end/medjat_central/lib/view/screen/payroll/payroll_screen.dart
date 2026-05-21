import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/payroll/payroll_controller.dart';
import '../../../data/model/payroll_model.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PayrollController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('payroll'.tr)),
      body: Column(
        children: [
          _MonthPicker(ctrl: ctrl),
          if (ctrl.canManagePayroll && ctrl.hasApprovedPayrolls)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s1,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ctrl.showBankFileDialog(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text('export_bank_file'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.brand,
                    side: BorderSide(color: colors.brand),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadPayrolls,
              child: GetBuilder<PayrollController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadPayrolls,
                    widget: ctrl.payrolls.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_payrolls'.tr,
                                    style:
                                        AppTextStyles.bodySecondary(context)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              0,
                              AppSpacing.s4,
                              AppSpacing.s7,
                            ),
                            itemCount: ctrl.payrolls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _PayrollTile(
                              payroll: ctrl.payrolls[i],
                              onApprove: () =>
                                  ctrl.approvePayroll(ctrl.payrolls[i].id),
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthPicker extends StatelessWidget {
  final PayrollController ctrl;
  const _MonthPicker({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        children: [
          IconButton.outlined(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () {
              int m = ctrl.selectedMonth - 1;
              int y = ctrl.selectedYear;
              if (m < 1) {
                m = 12;
                y--;
              }
              ctrl.changeMonth(m, y);
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                '${'month_${ctrl.selectedMonth}'.tr} ${ctrl.selectedYear}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).brand,
                ),
              ),
            ),
          ),
          IconButton.outlined(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () {
              int m = ctrl.selectedMonth + 1;
              int y = ctrl.selectedYear;
              if (m > 12) {
                m = 1;
                y++;
              }
              ctrl.changeMonth(m, y);
            },
          ),
        ],
      ),
    );
  }
}

class _PayrollTile extends StatelessWidget {
  final PayrollModel payroll;
  final VoidCallback onApprove;

  const _PayrollTile({
    required this.payroll,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(payroll.status, colors);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payroll.employeeName ?? 'employee'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${'net'.tr} ${payroll.netSalary.toStringAsFixed(0)} ج.م',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    if (payroll.totalDeductions > 0)
                      Text(
                        '${'deduction'.tr} ${payroll.totalDeductions.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.error,
                        ),
                      ),
                    if (payroll.totalOvertime > 0) ...[
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        '+${payroll.totalOvertime.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (payroll.status == 'draft')
            TextButton(
              onPressed: onApprove,
              child: Text('approve'.tr),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: AppSpacing.s1,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                payroll.statusLabel,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'draft':
        return colors.textTertiary;
      case 'approved':
        return colors.success;
      case 'paid':
        return colors.brand;
      default:
        return colors.textTertiary;
    }
  }
}
