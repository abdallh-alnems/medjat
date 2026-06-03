import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/locale_service.dart';

class AttendanceSuccessScreen extends StatefulWidget {
  const AttendanceSuccessScreen({super.key});

  @override
  State<AttendanceSuccessScreen> createState() =>
      _AttendanceSuccessScreenState();
}

class _AttendanceSuccessScreenState extends State<AttendanceSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  Timer? _autoDismissTimer;

  final Map<String, dynamic>? args = Get.arguments as Map<String, dynamic>?;
  bool get isCheckOut => args?['is_check_out'] == true;
  bool get isOffline => args?['offline'] == true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _autoDismissTimer = Timer(const Duration(seconds: 3), _goHome);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goHome() {
    if (mounted) {
      Get.offAllNamed<void>('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;
    final now = DateTime.now();
    final localeSvc = Get.find<LocaleService>();
    final isAr = localeSvc.isArabic;

    String dayName;
    String monthName;

    if (isAr) {
      final weekdays = [
        '', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
        'الجمعة', 'السبت', 'الأحد'
      ];
      final months = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو',
        'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر',
        'نوفمبر', 'ديسمبر'
      ];
      dayName = weekdays[now.weekday];
      monthName = months[now.month];
    } else {
      final weekdays = [
        '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      final months = [
        '', 'January', 'February', 'March', 'April', 'May',
        'June', 'July', 'August', 'September', 'October',
        'November', 'December'
      ];
      dayName = weekdays[now.weekday];
      monthName = months[now.month];
    }

    final hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm'.tr : 'am'.tr;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr = '$displayHour:$minute $period';
    final dateStr = '$dayName ${now.day} $monthName ${now.year}';

    final title = isCheckOut ? 'check_out_registered'.tr : 'check_in_registered'.tr;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.success.withValues(alpha: 0.12),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: CustomPaint(
                                painter: _CheckPainter(
                                  progress: _checkAnimation.value,
                                  color: colors.success,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Text(
                    title,
                    style: AppTextStyles.h2(context),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    timeStr,
                    style: AppTextStyles.tabular(context),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    dateStr,
                    style: AppTextStyles.sm(context),
                  ),
                  if (isOffline) ...[
                    const SizedBox(height: AppSpacing.s5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                        vertical: AppSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_sync_outlined,
                              size: 18, color: colors.warning),
                          const SizedBox(width: AppSpacing.s2),
                          Text(
                            'will_sync_online'.tr,
                            style: TextStyle(
                              fontFamily: AppTextStyles.arabicFamily,
                              fontSize: 13,
                              color: colors.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s7),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _goHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: Text('done'.tr),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height * 0.5);
    path.lineTo(size.width * 0.42, size.height * 0.72);
    path.lineTo(size.width * 0.8, size.height * 0.28);

    final metrics = path.computeMetrics().first;
    final end = metrics.length * progress.clamp(0.0, 1.0);

    canvas.drawPath(
      metrics.extractPath(0, end),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
