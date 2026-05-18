import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/today_status_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/home/home_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final isLight = Theme.of(context).brightness == Brightness.light;
        final colors = isLight ? AppColors.light : AppColors.dark;

        return Scaffold(
          backgroundColor: colors.canvas,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => controller.loadTodayStatus(),
              color: colors.brand,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                children: [
                  const SizedBox(height: AppSpacing.s4),
                  _buildAppBar(context, colors, controller),
                  const SizedBox(height: AppSpacing.s7),
                  _buildDate(context),
                  const SizedBox(height: AppSpacing.s6),
                  _buildStatusCard(context, colors, controller),
                  const SizedBox(height: AppSpacing.s7),
                  _buildAttendanceButton(context, colors, controller),
                  const SizedBox(height: AppSpacing.s7),
                  _buildBranchInfo(context, colors, controller),
                  if (controller.isOffline) ...[
                    const SizedBox(height: AppSpacing.s3),
                    _buildOfflineBanner(colors),
                  ],
                  const SizedBox(height: AppSpacing.s9),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(
      BuildContext context, AppColorScheme colors, HomeController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GetBuilder<AuthController>(
          builder: (c) => Text(
            'مرحباً، ${c.user?.name.split(' ').firstOrNull ?? ''}',
            style: AppTextStyles.h3(context),
          ),
        ),
        IconButton(
          onPressed: controller.goToNotifications,
          icon: Icon(
            Icons.notifications_outlined,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDate(BuildContext context) {
    final now = DateTime.now();
    final weekdays = [
      '',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ];
    final months = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    final dayName = weekdays[now.weekday];
    final monthName = months[now.month];

    return Text(
      '$dayName — ${now.day} $monthName ${now.year}',
      textAlign: TextAlign.center,
      style: AppTextStyles.sm(context),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, AppColorScheme colors, HomeController controller) {
    final todayStatus = controller.todayStatus;
    final status = controller.attendanceStatus;
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
        statusText = 'لم يتم تسجيل الحضور';
        timeText = null;
        subText = null;
        break;
      case AttendanceStatus.checkedIn:
        statusColor = isLate ? colors.warning : colors.success;
        statusIcon = isLate ? Icons.warning_amber : Icons.check_circle_outline;
        statusText = 'مسجل الحضور';
        timeText = _formatTime(todayStatus?.checkInAt);
        subText = isLate
            ? 'تأخرت ${todayStatus?.lateMinutes ?? 0} دقيقة'
            : 'لم تنصرف بعد';
        break;
      case AttendanceStatus.checkedOut:
        statusColor = colors.success;
        statusIcon = Icons.check_circle;
        statusText = 'تم اليوم';
        timeText =
            '${_formatTime(todayStatus?.checkInAt)} — ${_formatTime(todayStatus?.checkOutAt)}';
        subText = null;
        break;
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
          Text('حالتك اليوم', style: AppTextStyles.xs(context)),
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

  Widget _buildAttendanceButton(
      BuildContext context, AppColorScheme colors, HomeController controller) {
    final isDone = controller.isDayDone;
    final isCheckOut = controller.canCheckOut;

    Color bgColor;
    if (isDone) {
      bgColor = colors.sunken;
    } else if (isCheckOut) {
      bgColor = colors.accentWarm;
    } else {
      bgColor = colors.brand;
    }

    return Center(
      child: GestureDetector(
        onTap: isDone ? null : controller.startAttendanceFlow,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            boxShadow: isDone
                ? null
                : [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDone
                    ? Icons.check_rounded
                    : Icons.qr_code_scanner,
                size: 48,
                color: isDone ? colors.textTertiary : Colors.white,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                controller.attendanceButtonText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.arabicFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDone ? colors.textTertiary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchInfo(
      BuildContext context, AppColorScheme colors, HomeController controller) {
    final branchName = controller.todayStatus?.branchName;
    if (branchName == null) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          'فرعك: $branchName',
          textAlign: TextAlign.center,
          style: AppTextStyles.sm(context),
        ),
        if (controller.distanceFromBranch != null) ...[
          const SizedBox(height: AppSpacing.s1),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.s1),
              Text(
                _formatDistance(controller.distanceFromBranch!),
                style: AppTextStyles.xs(context),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOfflineBanner(AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: colors.warning),
          const SizedBox(width: AppSpacing.s2),
          Text(
            'بدون إنترنت',
            style: TextStyle(
              fontFamily: AppTextStyles.arabicFamily,
              fontSize: 13,
              color: colors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String? _formatTime(DateTime? dt) {
    if (dt == null) return null;
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}م من الفرع';
    }
    return '${(meters / 1000).toStringAsFixed(1)}كم من الفرع';
  }
}
