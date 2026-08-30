import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/attendance/attendance_history_controller.dart';
import '../../widget/ad/top_native_ad.dart';
import '../../widget/date_formatter.dart';
import '../../widget/stat_item.dart';

/// Read-only monthly attendance log for the employee: a month selector, a
/// summary header (present/late/overtime), and one card per recorded day.
class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => AttendanceHistoryController());
    return Scaffold(
      appBar: AppBar(title: Text('attendance_history'.tr)),
      body: GetBuilder<AttendanceHistoryController>(
        builder: (controller) {
          return Column(
            children: [
              const TopNativeAd(),
              _monthSelector(context, controller),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: controller.status,
                  widget: _buildBody(context, controller),
                  onRetry: () => controller.loadMonth(controller.selectedMonth),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _monthSelector(
      BuildContext context, AttendanceHistoryController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: controller.goPrevMonth,
            icon: const Icon(Icons.chevron_right),
          ),
          Text(controller.selectedMonth, style: AppTextStyles.h3(context)),
          IconButton(
            onPressed: controller.canGoNext ? controller.goNextMonth : null,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, AttendanceHistoryController controller) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _summary(context, controller),
        const SizedBox(height: 20),
        if (controller.records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text('no_attendance_records'.tr,
                  style: AppTextStyles.bodySecondary(context)),
            ),
          )
        else
          ...controller.records.map((r) => _dayCard(context, r)),
      ],
    );
  }

  Widget _summary(BuildContext context, AttendanceHistoryController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatItem(
              label: 'present_days'.tr, value: '${controller.presentDays}'),
          StatItem(label: 'late_days'.tr, value: '${controller.lateDays}'),
          StatItem(
            label: 'overtime'.tr,
            value: _formatMinutes(controller.totalOvertimeMinutes),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(BuildContext context, Map<String, dynamic> r) {
    final scheme = AppColors.of(context);
    final date = DateTime.tryParse(r['date']?.toString() ?? '');
    final names = date != null ? DateFormatter.format(date) : null;
    final late = int.tryParse('${r['late_minutes'] ?? 0}') ?? 0;
    final overtime = int.tryParse('${r['overtime_minutes'] ?? 0}') ?? 0;
    final status = r['status']?.toString() ?? 'present';
    final hasCheckIn = r['check_in_time'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date != null
                      ? '${names!.dayName} — ${date.day} ${names.monthName}'
                      : (r['date']?.toString() ?? ''),
                  style: AppTextStyles.body(context)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _statusChip(context, status, hasCheckIn),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _timeCell(
                  context,
                  icon: Icons.login,
                  label: 'check_in'.tr,
                  value: _time(r['check_in_time']),
                  color: _green,
                ),
              ),
              Expanded(
                child: _timeCell(
                  context,
                  icon: Icons.logout,
                  label: 'check_out'.tr,
                  value: _time(r['check_out_time']),
                  color: Colors.red,
                ),
              ),
            ],
          ),
          if (late > 0 || overtime > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (late > 0)
                  _badge(context, '${'late'.tr}: ${_formatMinutes(late)}',
                      Colors.orange),
                if (overtime > 0)
                  _badge(context,
                      '${'overtime'.tr}: ${_formatMinutes(overtime)}', _green),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _timeCell(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.xs(context)),
            Text(value,
                style: AppTextStyles.sm(context)
                    .copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  Widget _statusChip(BuildContext context, String status, bool hasCheckIn) {
    final Color color;
    final String label;
    switch (status) {
      case 'leave':
        color = const Color(0xFF1565C0);
        label = 'status_leave'.tr;
        break;
      case 'absent':
        color = Colors.red;
        label = 'status_absent'.tr;
        break;
      case 'holiday':
        color = const Color(0xFF6A1B9A);
        label = 'status_holiday'.tr;
        break;
      case 'weekly_off':
        color = AppColors.of(context).textTertiary;
        label = 'status_weekly_off'.tr;
        break;
      default:
        color = hasCheckIn ? _green : AppColors.of(context).textTertiary;
        label = hasCheckIn ? 'status_present'.tr : 'status_no_record'.tr;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyles.xs(context)
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _badge(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(text,
          style: AppTextStyles.xs(context)
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  /// Formats a `HH:MM:SS` backend time into a short `H:MM am/pm` string.
  String _time(dynamic raw) {
    final s = raw?.toString();
    if (s == null || s.isEmpty) return '—';
    final parts = s.split(':');
    if (parts.length < 2) return s;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, hour, minute);
    return DateFormatter.formatTime(dt);
  }

  /// Renders a minute count as `Xh Ym` (or just minutes when under an hour).
  String _formatMinutes(int minutes) {
    if (minutes <= 0) return '0';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m${'minute_short'.tr}';
    if (m == 0) return '$h${'hour_short'.tr}';
    return '$h${'hour_short'.tr} $m${'minute_short'.tr}';
  }
}
