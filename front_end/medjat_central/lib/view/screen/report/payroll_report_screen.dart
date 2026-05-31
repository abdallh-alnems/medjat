import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../logic/controller/report/payroll_report_controller.dart';
import '../../../data/model/report_model.dart';

class PayrollReportScreen extends StatelessWidget {
  const PayrollReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PayrollReportController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('payroll_report'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'export_pdf'.tr,
            onPressed: () {
              PdfExportService.exportReport(
                title: 'payroll_report'.tr,
                headers: [
                  'employee'.tr,
                  'net'.tr,
                  'deduction'.tr,
                  'status'.tr,
                ],
                rows: ctrl.rows
                    .map((r) => [
                          r.employeeName,
                          r.netSalary.toStringAsFixed(0),
                          r.totalDeductions.toStringAsFixed(0),
                          r.status,
                        ])
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthPicker(ctrl: ctrl),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadReport,
              child: GetBuilder<PayrollReportController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadReport,
                    widget: ctrl.rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_report_data'.tr,
                                    style:
                                        AppTextStyles.bodySecondary(context)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              0,
                              AppSpacing.s4,
                              AppSpacing.s7,
                            ),
                            children: [
                              _SummaryCards(
                                  summary: ctrl.summary, colors: colors),
                              const SizedBox(height: AppSpacing.s4),
                              ...ctrl.rows.map((row) => Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.s2),
                                    child: _PayrollRow(
                                        row: row, colors: colors),
                                  )),
                            ],
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
  final PayrollReportController ctrl;
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

class _SummaryCards extends StatelessWidget {
  final PayrollReportSummary summary;
  final AppColorScheme colors;
  const _SummaryCards({required this.summary, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'total_payroll'.tr,
                    value: '${summary.totalNet.toStringAsFixed(0)} ج.م',
                    color: colors.brand,
                    colors: colors)),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
                child: _StatCard(
                    label: 'total_deductions'.tr,
                    value: summary.totalDeductions.toStringAsFixed(0),
                    color: colors.error,
                    colors: colors)),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'total_bonuses'.tr,
                    value: summary.totalBonuses.toStringAsFixed(0),
                    color: colors.success,
                    colors: colors)),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
                child: _StatCard(
                    label: 'employee_count'.tr,
                    value: '${summary.employeeCount}',
                    color: colors.accentWarm,
                    colors: colors)),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final AppColorScheme colors;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.xs(context),
          ),
        ],
      ),
    );
  }
}

class _PayrollRow extends StatelessWidget {
  final PayrollReportRow row;
  final AppColorScheme colors;
  const _PayrollRow({required this.row, required this.colors});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(row.status);
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
                  row.employeeName,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${'net'.tr} ${row.netSalary.toStringAsFixed(0)} ج.م',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    if (row.totalDeductions > 0)
                      Text(
                        '${'deduction'.tr} ${row.totalDeductions.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.error,
                        ),
                      ),
                    if (row.totalBonuses > 0) ...[
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        '+${row.totalBonuses.toStringAsFixed(0)}',
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
              _statusLabel(row.status),
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

  Color _statusColor(String status) {
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

  String _statusLabel(String status) {
    switch (status) {
      case 'draft':
        return 'status_draft'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'paid':
        return 'status_paid'.tr;
      default:
        return status;
    }
  }
}
