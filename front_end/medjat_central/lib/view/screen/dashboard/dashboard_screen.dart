import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/dashboard_model.dart';
import '../../../logic/controller/dashboard/dashboard_controller.dart';
import '../../../logic/controller/auth/auth_controller.dart';
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
          'مرحباً، ${auth.user?.name.split(' ').first ?? 'مدير'}',
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
    final now = DateFormat('EEEE، d MMMM yyyy', 'ar').format(DateTime.now());

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
            'ملخص اليوم',
            style: AppTextStyles.h2(context),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'الحاضرون',
                  value: '${d?.presentToday ?? 0}',
                  icon: Icons.check_circle_outline,
                  color: colors.success,
                  subtitle: 'من ${d?.totalEmployees ?? 0} موظف',
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: StatCard(
                  title: 'الغائبون',
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
                  title: 'المتأخرون',
                  value: '${d?.lateToday ?? 0}',
                  icon: Icons.access_time,
                  color: colors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: StatCard(
                  title: 'في إجازة',
                  value: '${d?.onLeaveToday ?? 0}',
                  icon: Icons.beach_access_outlined,
                  color: colors.accentWarm,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          StatCard(
            title: 'نسبة الحضور',
            value: '${d?.attendanceRate.toStringAsFixed(1) ?? '0'}%',
            icon: Icons.pie_chart_outline,
            color: colors.brand,
            isFullWidth: true,
          ),
          if (d?.branchStats.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.s6),
            Text('أداء الفروع', style: AppTextStyles.h2(context)),
            const SizedBox(height: AppSpacing.s4),
            ...d!.branchStats.map((b) => _BranchStatTile(stats: b)),
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
                  '${stats.present} حاضر من ${stats.totalEmployees}',
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
