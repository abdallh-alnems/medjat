import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/home/home_controller.dart';
import '../../widget/ad/native_ad_widget.dart';
import '../../widget/date_formatter.dart';
import 'widgets/attendance_button.dart';
import 'widgets/status_card.dart';

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
                  StatusCard(
                    colors: colors,
                    todayStatus: controller.todayStatus,
                    status: controller.attendanceStatus,
                    scheduledTimeText: controller.scheduledTimeText,
                    isRestDay: controller.isRestDay,
                  ),
                  const SizedBox(height: AppSpacing.s7),
                  AttendanceButton(
                    colors: colors,
                    isDayDone: controller.isDayDone,
                    canCheckOut: controller.canCheckOut,
                    buttonText: controller.attendanceButtonText,
                    icon: controller.attendanceButtonIcon,
                    onTap: controller.startAttendanceFlow,
                  ),
                  const SizedBox(height: AppSpacing.s7),
                  _buildBranchInfo(context, colors, controller),
                  if (controller.isOffline) ...[
                    const SizedBox(height: AppSpacing.s3),
                    _buildOfflineBanner(colors),
                  ],
                  const SizedBox(height: AppSpacing.s7),
                  const NativeAdWidget(),
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
            'welcome'.trParams({'name': c.user?.name.split(' ').firstOrNull ?? ''}),
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
    final formatted = DateFormatter.format(now);

    return Text(
      '${formatted.dayName} — ${now.day} ${formatted.monthName} ${now.year}',
      textAlign: TextAlign.center,
      style: AppTextStyles.sm(context),
    );
  }

  Widget _buildBranchInfo(
      BuildContext context, AppColorScheme colors, HomeController controller) {
    final branchName = controller.todayStatus?.branchName;
    if (branchName == null) return const SizedBox.shrink();

    return Column(
      children: [
        Text(
          'your_branch'.trParams({'name': branchName}),
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
            'no_internet'.tr,
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return 'm_from_branch'.trParams({'distance': '${meters.round()}'});
    }
    return 'km_from_branch'.trParams({'distance': (meters / 1000).toStringAsFixed(1)});
  }
}
