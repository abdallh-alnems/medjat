import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../logic/controller/report/employees_report_controller.dart';
import '../../../data/model/report_model.dart';

class EmployeesReportScreen extends StatelessWidget {
  const EmployeesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployeesReportController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('employees_report'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'export_pdf'.tr,
            onPressed: () {
              PdfExportService.exportReport(
                title: 'employees_report'.tr,
                headers: [
                  'employee'.tr,
                  'branch'.tr,
                  'base_salary'.tr,
                  'days_present'.tr,
                  'days_absent'.tr,
                  'days_late'.tr,
                ],
                rows: ctrl.rows
                    .map((r) => [
                          r.employeeName,
                          r.branchName ?? '-',
                          r.baseSalary.toStringAsFixed(0),
                          '${r.daysPresent}',
                          '${r.daysAbsent}',
                          '${r.daysLate}',
                        ])
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.loadReport,
        child: GetBuilder<EmployeesReportController>(
          builder: (_) {
            return HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadReport,
              widget: ctrl.rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined,
                              size: 48, color: colors.textTertiary),
                          const SizedBox(height: AppSpacing.s3),
                          Text('no_report_data'.tr,
                              style: AppTextStyles.bodySecondary(context)),
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
                        _SummaryCards(summary: ctrl.summary, colors: colors),
                        const SizedBox(height: AppSpacing.s4),
                        ...ctrl.rows.map((row) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.s2),
                              child: _EmployeeRow(row: row, colors: colors),
                            )),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final EmployeesReportSummary summary;
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
                    label: 'total_employees'.tr,
                    value: '${summary.totalEmployees}',
                    color: colors.brand,
                    colors: colors)),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
                child: _StatCard(
                    label: 'active_employees'.tr,
                    value: '${summary.activeCount}',
                    color: colors.success,
                    colors: colors)),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'total_salaries'.tr,
                    value: '${summary.totalSalaries.toStringAsFixed(0)} ج.م',
                    color: colors.accentWarm,
                    colors: colors)),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
                child: _StatCard(
                    label: 'branch_count'.tr,
                    value: '${summary.branchCount}',
                    color: colors.brand,
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

class _EmployeeRow extends StatelessWidget {
  final EmployeesReportRow row;
  final AppColorScheme colors;
  const _EmployeeRow({required this.row, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.employeeName,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(status: row.status, colors: colors),
            ],
          ),
          if (row.jobTitle != null || row.branchName != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  row.jobTitle,
                  row.branchName,
                ].whereType<String>().join(' · '),
                style: AppTextStyles.xs(context),
              ),
            ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Text(
                '${row.baseSalary.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.accentWarm,
                ),
              ),
              const Spacer(),
              _Badge(
                  label: '${row.daysPresent}',
                  color: colors.success,
                  colors: colors),
              const SizedBox(width: AppSpacing.s2),
              _Badge(
                  label: '${row.daysAbsent}',
                  color: colors.error,
                  colors: colors),
              const SizedBox(width: AppSpacing.s2),
              _Badge(
                  label: '${row.daysLate}',
                  color: colors.warning,
                  colors: colors),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final AppColorScheme colors;
  const _StatusBadge({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Color get _color {
    switch (status) {
      case 'active':
        return colors.success;
      case 'pending_activation':
        return colors.warning;
      case 'on_leave':
        return colors.brand;
      case 'suspended':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }

  String get _label {
    switch (status) {
      case 'active':
        return 'status_active'.tr;
      case 'pending_activation':
        return 'pending_activation'.tr;
      case 'on_leave':
        return 'employee_on_leave'.tr;
      case 'suspended':
        return 'status_suspended'.tr;
      default:
        return status;
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final AppColorScheme colors;
  const _Badge({
    required this.label,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
