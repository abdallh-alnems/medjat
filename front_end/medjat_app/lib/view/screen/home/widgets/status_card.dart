import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../data/model/today_status_model.dart';
import '../../../widget/date_formatter.dart';

class StatusCard extends StatelessWidget {
  final AppColorScheme colors;
  final TodayStatusModel? todayStatus;
  final AttendanceStatus status;

  const StatusCard({
    super.key,
    required this.colors,
    required this.todayStatus,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isLate = todayStatus?.isLate ?? false;

    Color statusColor;
    IconData statusIcon;
    String statusText;
    String? timeText;
    String? subText;

    switch (status) {
      case AttendanceStatus.notCheckedIn:
        statusColor = colors.warning;
        statusIcon = Icons.schedule_outlined;
        statusText = 'not_checked_in'.tr;
        timeText = null;
        subText = null;
      case AttendanceStatus.checkedIn:
        statusColor = isLate ? colors.warning : colors.success;
        statusIcon = isLate ? Icons.warning_amber : Icons.check_circle_outline;
        statusText = 'checked_in'.tr;
        timeText = todayStatus?.checkInAt != null
            ? DateFormatter.formatTime(todayStatus!.checkInAt!)
            : null;
        subText = isLate
            ? 'late_minutes'.trParams({'minutes': '${todayStatus?.lateMinutes ?? 0}'})
            : 'not_checked_out'.tr;
      case AttendanceStatus.checkedOut:
        statusColor = colors.success;
        statusIcon = Icons.check_circle;
        statusText = 'day_done'.tr;
        timeText = todayStatus?.checkInAt != null
            ? '${DateFormatter.formatTime(todayStatus!.checkInAt!)} — ${todayStatus?.checkOutAt != null ? DateFormatter.formatTime(todayStatus!.checkOutAt!) : ''}'
            : null;
        subText = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderHairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.surface,
      ),
      child: Column(
        children: [
          Text('your_status_today'.tr, style: AppTextStyles.xs(context)),
          const SizedBox(height: AppSpacing.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, size: 20, color: statusColor),
              const SizedBox(width: AppSpacing.s2),
              Text(statusText, style: AppTextStyles.h3(context)),
            ],
          ),
          if (timeText != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(timeText, style: AppTextStyles.sm(context)),
          ],
          if (subText != null) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              subText,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 13,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
