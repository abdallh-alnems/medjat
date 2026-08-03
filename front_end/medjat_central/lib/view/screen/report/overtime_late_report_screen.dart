import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/report_model.dart';
import '../../../logic/controller/branch/branch_controller.dart';
import '../../../logic/controller/report/overtime_late_report_controller.dart';
import '../../widget/report/report_export.dart';
import '../../widget/report/report_period_selector.dart';

/// Formats a minute count as "2س 30د" / "45د" using the short unit labels.
String _fmtMinutes(int minutes) {
  if (minutes <= 0) return '0${'minutes_short'.tr}';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m${'minutes_short'.tr}';
  if (m == 0) return '$h${'hours_short'.tr}';
  return '$h${'hours_short'.tr} $m${'minutes_short'.tr}';
}

/// Overtime & lateness per employee for a period, with a per-employee
/// day-by-day drill-down.
class OvertimeLateReportScreen extends StatelessWidget {
  const OvertimeLateReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<OvertimeLateReportController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('overtime_late_report'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'export_as'.tr,
            onPressed: () {
              exportReportWithFormat(
                context,
                title: 'overtime_late_report'.tr,
                subtitle: ctrl.periodLabel,
                headers: [
                  'employee'.tr,
                  'branch'.tr,
                  'total_overtime'.tr,
                  'overtime_days'.tr,
                  'total_late_minutes'.tr,
                  'late_days'.tr,
                  'worst_late'.tr,
                ],
                rows: ctrl.rows
                    .map((r) => [
                          r.employeeName,
                          r.branchName ?? '-',
                          _fmtMinutes(r.overtimeMinutes),
                          '${r.overtimeDays}',
                          _fmtMinutes(r.lateMinutes),
                          '${r.lateDays}',
                          _fmtMinutes(r.worstLateMinutes),
                        ])
                    .toList(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ReportPeriodSelector(
            startDate: ctrl.startDate,
            endDate: ctrl.endDate,
            onChanged: ctrl.setDateRange,
          ),
          const _Filters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadReport,
              child: GetBuilder<OvertimeLateReportController>(
                builder: (_) => HandlingDataRequest(
                  statusRequest: ctrl.status,
                  onRetry: ctrl.loadReport,
                  widget: ctrl.rows.isEmpty
                      ? ListView(
                          // Keeps pull-to-refresh usable on the empty state.
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.timelapse_outlined,
                                size: 48, color: colors.textTertiary),
                            const SizedBox(height: AppSpacing.s3),
                            Text(
                              'no_overtime_late_data'.tr,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodySecondary(context),
                            ),
                          ],
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
                            ...ctrl.rows.map(
                              (row) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.s2),
                                child: _EmployeeRow(row: row, colors: colors),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branch filter + sort chips.
class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<OvertimeLateReportController>();
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s3),
      child: Row(
        children: [
          Expanded(
            child: GetBuilder<BranchController>(
              builder: (branchCtrl) => Container(
                height: 40,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.sunken,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.borderHairline),
                ),
                child: DropdownButtonHideUnderline(
                  child: GetBuilder<OvertimeLateReportController>(
                    builder: (_) => DropdownButton<int?>(
                      value: ctrl.branchFilter,
                      isExpanded: true,
                      icon: Icon(Icons.arrow_drop_down,
                          color: colors.textTertiary),
                      dropdownColor: colors.surface,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          child: Text('all_branches'.tr),
                        ),
                        ...branchCtrl.branches.map(
                          (b) => DropdownMenuItem<int?>(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        ),
                      ],
                      onChanged: ctrl.setBranch,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          GetBuilder<OvertimeLateReportController>(
            builder: (_) => Row(
              children: [
                _SortChip(
                  label: 'sort_most_overtime'.tr,
                  selected: ctrl.sort == 'overtime',
                  colors: colors,
                  onTap: () => ctrl.setSort('overtime'),
                ),
                const SizedBox(width: AppSpacing.s2),
                _SortChip(
                  label: 'sort_most_late'.tr,
                  selected: ctrl.sort == 'late',
                  colors: colors,
                  onTap: () => ctrl.setSort('late'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.brand : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// The two headline totals: overtime and lateness for the whole period.
class _SummaryCards extends StatelessWidget {
  final OvertimeLateSummary summary;
  final AppColorScheme colors;
  const _SummaryCards({required this.summary, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _TotalCard(
            icon: Icons.trending_up,
            label: 'total_overtime'.tr,
            value: _fmtMinutes(summary.totalOvertimeMinutes),
            caption: '${summary.overtimeDays} ${'days'.tr}'
                ' • ${summary.employeesWithOvertime} ${'employee'.tr}',
            color: colors.success,
            colors: colors,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: _TotalCard(
            icon: Icons.schedule,
            label: 'total_late_minutes'.tr,
            value: _fmtMinutes(summary.totalLateMinutes),
            caption: '${summary.lateDays} ${'days'.tr}'
                ' • ${summary.employeesLate} ${'employee'.tr}',
            color: colors.warning,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;
  final AppColorScheme colors;

  const _TotalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.colors,
  });

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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.xs(context),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
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
          Text(caption, style: AppTextStyles.xs(context)),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final OvertimeLateRow row;
  final AppColorScheme colors;
  const _EmployeeRow({required this.row, required this.colors});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showDaysSheet(context, row),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
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
                  Text(row.branchName!, style: AppTextStyles.xs(context)),
                Icon(Icons.chevron_left, size: 18, color: colors.textTertiary),
              ],
            ),
            if (row.jobTitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(row.jobTitle!, style: AppTextStyles.xs(context)),
              ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                if (row.overtimeMinutes > 0)
                  _MetricPill(
                    icon: Icons.trending_up,
                    value: _fmtMinutes(row.overtimeMinutes),
                    caption: '${row.overtimeDays} ${'days'.tr}',
                    color: colors.success,
                    colors: colors,
                  ),
                if (row.overtimeMinutes > 0 && row.lateMinutes > 0)
                  const SizedBox(width: AppSpacing.s2),
                if (row.lateMinutes > 0)
                  _MetricPill(
                    icon: Icons.schedule,
                    value: _fmtMinutes(row.lateMinutes),
                    caption: '${row.lateDays} ${'days'.tr}',
                    color: colors.warning,
                    colors: colors,
                  ),
                const Spacer(),
                if (row.lateDays > 0)
                  Text(
                    '${'avg_late_minutes'.tr} ${_fmtMinutes(row.avgLateMinutes)}',
                    style: AppTextStyles.xs(context),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String caption;
  final Color color;
  final AppColorScheme colors;

  const _MetricPill({
    required this.icon,
    required this.value,
    required this.caption,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.s1),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.s1),
          Text(
            '($caption)',
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the day-by-day breakdown behind one employee's totals.
void _showDaysSheet(BuildContext context, OvertimeLateRow row) {
  final ctrl = Get.find<OvertimeLateReportController>();
  ctrl.loadDays(row.employeeId);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DaysSheet(row: row),
  );
}

class _DaysSheet extends StatelessWidget {
  final OvertimeLateRow row;
  const _DaysSheet({required this.row});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(
              row.employeeName,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            Text('details'.tr, style: AppTextStyles.xs(context)),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              child: GetBuilder<OvertimeLateReportController>(
                id: 'days',
                builder: (ctrl) => HandlingDataRequest(
                  statusRequest: ctrl.daysStatus,
                  onRetry: () => ctrl.loadDays(row.employeeId),
                  widget: ctrl.days.isEmpty
                      ? Center(
                          child: Text('no_report_data'.tr,
                              style: AppTextStyles.bodySecondary(context)),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: ctrl.days.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.s2),
                          itemBuilder: (_, i) =>
                              _DayTile(day: ctrl.days[i], colors: colors),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final OvertimeLateDay day;
  final AppColorScheme colors;
  const _DayTile({required this.day, required this.colors});

  /// "09:00 → 18:30", trimming the seconds the API sends.
  String get _times {
    String cut(String? t) => t == null || t.length < 5 ? '—' : t.substring(0, 5);
    return '${cut(day.checkInTime)} → ${cut(day.checkOutTime)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
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
                  day.date,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_times, style: AppTextStyles.xs(context)),
              ],
            ),
          ),
          if (day.overtimeMinutes > 0)
            _MetricPill(
              icon: Icons.trending_up,
              value: _fmtMinutes(day.overtimeMinutes),
              caption: 'overtime_by'.tr,
              color: colors.success,
              colors: colors,
            ),
          if (day.overtimeMinutes > 0 && day.lateMinutes > 0)
            const SizedBox(width: AppSpacing.s2),
          if (day.lateMinutes > 0)
            _MetricPill(
              icon: Icons.schedule,
              value: _fmtMinutes(day.lateMinutes),
              caption: 'late_by'.tr,
              color: colors.warning,
              colors: colors,
            ),
        ],
      ),
    );
  }
}
