import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../logic/controller/report/attendance_report_controller.dart';
import '../../../data/model/report_model.dart';

class AttendanceReportScreen extends StatelessWidget {
  const AttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AttendanceReportController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('attendance_report'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'export_pdf'.tr,
            onPressed: () {
              PdfExportService.exportReport(
                title: 'attendance_report'.tr,
                headers: [
                  'employee'.tr,
                  'branch'.tr,
                  'days_present'.tr,
                  'days_late'.tr,
                  'days_absent'.tr,
                  'days_leave'.tr,
                  'hours_worked'.tr,
                ],
                rows: ctrl.rows
                    .map((r) => [
                          r.employeeName,
                          r.branchName ?? '-',
                          '${r.daysPresent}',
                          '${r.daysLate}',
                          '${r.daysAbsent}',
                          '${r.daysLeave}',
                          '${r.hoursWorked}',
                        ])
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _DateRangeBar(ctrl: ctrl),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadReport,
              child: GetBuilder<AttendanceReportController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadReport,
                    widget: ctrl.rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assessment_outlined,
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
                                    child: _AttendanceRow(
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

class _DateRangeBar extends StatelessWidget {
  final AttendanceReportController ctrl;
  const _DateRangeBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024, 1, 1),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            ctrl.setDateRange(picked.start, picked.end);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 18, color: colors.brand),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  '${_fmtDate(ctrl.startDate)}  —  ${_fmtDate(ctrl.endDate)}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _SummaryCards extends StatelessWidget {
  final AttendanceReportSummary summary;
  final AppColorScheme colors;
  const _SummaryCards({required this.summary, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
                label: 'total_present'.tr,
                value: '${summary.totalPresent}',
                color: colors.success,
                colors: colors)),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
            child: _StatCard(
                label: 'total_late'.tr,
                value: '${summary.totalLate}',
                color: colors.warning,
                colors: colors)),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
            child: _StatCard(
                label: 'total_absent'.tr,
                value: '${summary.totalAbsent}',
                color: colors.error,
                colors: colors)),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
            child: _StatCard(
                label: 'total_leave'.tr,
                value: '${summary.totalLeave}',
                color: colors.brand,
                colors: colors)),
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
              fontSize: 22,
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

class _AttendanceRow extends StatelessWidget {
  final AttendanceReportRow row;
  final AppColorScheme colors;
  const _AttendanceRow({required this.row, required this.colors});

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
              if (row.branchName != null)
                Text(
                  row.branchName!,
                  style: AppTextStyles.xs(context),
                ),
            ],
          ),
          if (row.jobTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(row.jobTitle!, style: AppTextStyles.xs(context)),
            ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              _Badge(
                  label: '${row.daysPresent}',
                  color: colors.success,
                  colors: colors),
              const SizedBox(width: AppSpacing.s2),
              _Badge(
                  label: '${row.daysLate}',
                  color: colors.warning,
                  colors: colors),
              const SizedBox(width: AppSpacing.s2),
              _Badge(
                  label: '${row.daysAbsent}',
                  color: colors.error,
                  colors: colors),
              const SizedBox(width: AppSpacing.s2),
              _Badge(
                  label: '${row.daysLeave}',
                  color: colors.brand,
                  colors: colors),
              const Spacer(),
              Text(
                '${row.hoursWorked}h',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
