import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/dashboard_model.dart';
import '../../../logic/controller/dashboard/dashboard_controller.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../core/services/locale_service.dart';
import '../../widget/dashboard/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DashboardController>();
    final auth = Get.find<AuthController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${'welcome_greeting'.tr} ${auth.user?.name.split(' ').first ?? 'admin'.tr}',
          style: AppTextStyles.h3(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: colors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: ctrl.loadDashboard,
          child: GetBuilder<DashboardController>(
            builder: (_) {
              return HandlingDataRequest(
                statusRequest: ctrl.status,
                onRetry: ctrl.loadDashboard,
                widget: _DashboardContent(ctrl: ctrl),
              );
            },
          ),
        ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardController ctrl;
  const _DashboardContent({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final d = ctrl.dashboard;
    final colors = AppColors.of(context);
    final locale = Get.find<LocaleService>().currentLocale.languageCode;
    final now = DateFormat('EEEE، d MMMM yyyy', locale).format(DateTime.now());
    final auth = Get.find<AuthController>();
    final canCompare = (auth.user?.isOwner == true || auth.user?.canViewReports == true) &&
        (d?.branchStats.length ?? 0) > 1;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            now,
            style: AppTextStyles.sm(context),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text(
            'today_summary'.tr,
            style: AppTextStyles.h2(context),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'present'.tr,
                  value: '${d?.presentToday ?? 0}',
                  icon: Icons.check_circle_outline,
                  color: colors.success,
                  subtitle: '${'of'.tr} ${d?.totalEmployees ?? 0} ${'employees_count'.tr}',
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: StatCard(
                  title: 'absent'.tr,
                  value: '${d?.absentToday ?? 0}',
                  icon: Icons.cancel_outlined,
                  color: colors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'late'.tr,
                  value: '${d?.lateToday ?? 0}',
                  icon: Icons.access_time,
                  color: colors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: StatCard(
                  title: 'on_leave'.tr,
                  value: '${d?.onLeaveToday ?? 0}',
                  icon: Icons.beach_access_outlined,
                  color: colors.accentWarm,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          StatCard(
            title: 'attendance_rate'.tr,
            value: '${d?.attendanceRate.toStringAsFixed(1) ?? '0'}%',
            icon: Icons.pie_chart_outline,
            color: colors.brand,
            isFullWidth: true,
          ),
          if (d?.branchStats.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.s6),
            Text('branch_performance'.tr, style: AppTextStyles.h2(context)),
            const SizedBox(height: AppSpacing.s4),
            ...d!.branchStats.map((b) => _BranchStatTile(stats: b)),
          ],
          if (canCompare) ...[
            const SizedBox(height: AppSpacing.s6),
            _BranchComparisonSection(ctrl: ctrl),
          ],
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

class _BranchStatTile extends StatelessWidget {
  final BranchStats stats;
  const _BranchStatTile({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
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
                  stats.branchName,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '${stats.present} ${'present_of'.tr} ${stats.totalEmployees}',
                  style: AppTextStyles.sm(context),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.attendanceRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: stats.attendanceRate >= 80
                      ? colors.success
                      : stats.attendanceRate >= 50
                          ? colors.warning
                          : colors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchComparisonSection extends StatelessWidget {
  final DashboardController ctrl;
  const _BranchComparisonSection({required this.ctrl});

  static const _metricKeys = <BranchMetric, String>{
    BranchMetric.attendanceRate: 'metric_attendance_rate',
    BranchMetric.totalPayroll: 'metric_total_payroll',
    BranchMetric.lateRate: 'metric_late_rate',
    BranchMetric.employeesCount: 'metric_employees_count',
  };

  @override
  Widget build(BuildContext context) {
    final branches = ctrl.dashboard?.branchStats ?? [];
    if (branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Text(
            'no_branches_to_compare'.tr,
            style: AppTextStyles.sm(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('branch_comparison'.tr, style: AppTextStyles.h2(context)),
        const SizedBox(height: AppSpacing.s2),
        Text('branch_comparison_hint'.tr, style: AppTextStyles.sm(context)),
        const SizedBox(height: AppSpacing.s4),
        _MetricSelector(ctrl: ctrl),
        const SizedBox(height: AppSpacing.s5),
        _BarChart(ctrl: ctrl),
        const SizedBox(height: AppSpacing.s5),
        Text('branch_performance'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: AppSpacing.s3),
        _BranchSummaryTable(branches: branches),
      ],
    );
  }
}

class _MetricSelector extends StatelessWidget {
  final DashboardController ctrl;
  const _MetricSelector({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: GetBuilder<DashboardController>(
          builder: (_) {
            return Row(
              children: BranchMetric.values.map((m) {
                final selected = ctrl.selectedMetric == m;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.s2),
                  child: ChoiceChip(
                    label: Text(
                      _BranchComparisonSection._metricKeys[m]!.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? colors.canvas : colors.textSecondary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: colors.brand,
                    backgroundColor: colors.surface,
                    side: BorderSide(
                      color: selected ? colors.brand : colors.borderHairline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    onSelected: (_) => ctrl.selectMetric(m),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final DashboardController ctrl;
  const _BarChart({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final branches = List<BranchStats>.from(ctrl.dashboard?.branchStats ?? []);
    final metric = ctrl.selectedMetric;

    if (branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Text('no_branches_to_compare'.tr, style: AppTextStyles.sm(context)),
        ),
      );
    }

    branches.sort((a, b) => b.valueForMetric(metric).compareTo(a.valueForMetric(metric)));

    final maxVal = branches
        .map((b) => b.valueForMetric(metric))
        .reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal > 0 ? maxVal : 1.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        children: branches.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          final val = b.valueForMetric(metric);
          final fraction = val / safeMax;
          final isHighest = i == 0;
          final isLowest = i == branches.length - 1 && branches.length > 1;
          final barColor = isHighest
              ? colors.success
              : isLowest
                  ? colors.error
                  : colors.brand;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: _BarRow(
              name: b.branchName,
              fraction: fraction,
              label: _formatValue(val, metric),
              barColor: barColor,
              badge: isHighest
                  ? 'highest'.tr
                  : isLowest
                      ? 'lowest'.tr
                      : null,
              badgeColor: isHighest
                  ? colors.success
                  : isLowest
                      ? colors.error
                      : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatValue(double val, BranchMetric metric) {
    switch (metric) {
      case BranchMetric.attendanceRate:
      case BranchMetric.lateRate:
        return '${val.toStringAsFixed(1)}%';
      case BranchMetric.totalPayroll:
        return '${val.toStringAsFixed(0)} ${'currency_egp'.tr}';
      case BranchMetric.employeesCount:
        return '${val.toInt()} ${'employees_label'.tr}';
    }
  }
}

class _BarRow extends StatelessWidget {
  final String name;
  final double fraction;
  final String label;
  final Color barColor;
  final String? badge;
  final Color? badgeColor;

  const _BarRow({
    required this.name,
    required this.fraction,
    required this.label,
    required this.barColor,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: (badgeColor ?? colors.brand).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor ?? colors.brand,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.sunken,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.02, 1.0),
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsetsDirectional.only(end: AppSpacing.s2),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BranchSummaryTable extends StatelessWidget {
  final List<BranchStats> branches;
  const _BranchSummaryTable({required this.branches});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(colors.sunken),
            headingTextStyle: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
            dataTextStyle: TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              color: colors.textPrimary,
            ),
            columnSpacing: AppSpacing.s5,
            horizontalMargin: AppSpacing.s4,
            columns: [
              DataColumn(label: Text('branch_name'.tr)),
              DataColumn(label: Text('metric_attendance_rate'.tr), numeric: true),
              DataColumn(label: Text('metric_total_payroll'.tr), numeric: true),
              DataColumn(label: Text('metric_late_rate'.tr), numeric: true),
              DataColumn(label: Text('metric_employees_count'.tr), numeric: true),
            ],
            rows: branches.map((b) {
              return DataRow(cells: [
                DataCell(Text(
                  b.branchName,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontWeight: FontWeight.w500,
                  ),
                )),
                DataCell(Text('${b.attendanceRate.toStringAsFixed(1)}%')),
                DataCell(Text('${b.totalPayroll.toStringAsFixed(0)} ${'currency_egp'.tr}')),
                DataCell(Text('${b.effectiveLateRate.toStringAsFixed(1)}%')),
                DataCell(Text('${b.totalEmployees}')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
