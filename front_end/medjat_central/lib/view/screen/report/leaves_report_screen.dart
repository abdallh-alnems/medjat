import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/pdf_export_service.dart';
import '../../../logic/controller/report/leaves_report_controller.dart';
import '../../../data/model/report_model.dart';

class LeavesReportScreen extends StatelessWidget {
  const LeavesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<LeavesReportController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('leaves_report'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'export_pdf'.tr,
            onPressed: () {
              PdfExportService.exportReport(
                title: 'leaves_report'.tr,
                headers: [
                  'employee'.tr,
                  'type'.tr,
                  'date'.tr,
                  'reason'.tr,
                  'status'.tr,
                ],
                rows: ctrl.rows
                    .map((r) => [
                          r.employeeName,
                          r.type,
                          '${r.startDate} → ${r.endDate}',
                          r.reason ?? '-',
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
          _DateRangeBar(ctrl: ctrl),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadReport,
              child: GetBuilder<LeavesReportController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadReport,
                    widget: ctrl.rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.beach_access_outlined,
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
                                    child:
                                        _LeaveRow(row: row, colors: colors),
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
  final LeavesReportController ctrl;
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
  final LeavesReportSummary summary;
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
                    label: 'total_leaves'.tr,
                    value: '${summary.totalLeaves}',
                    color: colors.brand,
                    colors: colors)),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
                child: _StatCard(
                    label: 'approved_count'.tr,
                    value: '${summary.approvedCount}',
                    color: colors.success,
                    colors: colors)),
          ],
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            Expanded(
                child: _StatCard(
                    label: 'pending_count'.tr,
                    value: '${summary.pendingCount}',
                    color: colors.warning,
                    colors: colors)),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
                child: _StatCard(
                    label: 'employees_on_leave'.tr,
                    value: '${summary.employeesOnLeave}',
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

class _LeaveRow extends StatelessWidget {
  final LeavesReportRow row;
  final AppColorScheme colors;
  const _LeaveRow({required this.row, required this.colors});

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
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _typeLabel(row.type),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.brand,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                '${row.startDate}  →  ${row.endDate}',
                style: AppTextStyles.xs(context),
              ),
            ],
          ),
          if (row.reason != null && row.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              row.reason!,
              style: AppTextStyles.xs(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return colors.success;
      case 'rejected':
        return colors.error;
      case 'pending':
        return colors.warning;
      default:
        return colors.textTertiary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'status_approved'.tr;
      case 'rejected':
        return 'status_rejected'.tr;
      case 'pending':
        return 'status_pending'.tr;
      default:
        return status;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'annual':
        return 'leave_type_annual'.tr;
      case 'sick':
        return 'leave_type_sick'.tr;
      case 'personal':
        return 'leave_type_personal'.tr;
      case 'unpaid':
        return 'leave_type_unpaid'.tr;
      case 'weekly_off':
        return 'leave_type_weekly_off'.tr;
      case 'converted_from_absence':
        return 'leave_absence_conversion'.tr;
      default:
        return type;
    }
  }
}
