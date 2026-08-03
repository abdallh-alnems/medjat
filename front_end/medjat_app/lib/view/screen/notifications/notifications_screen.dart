import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/notification/notification_controller.dart';
import '../../widget/ad/top_native_ad.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => NotificationController());
    return Scaffold(
      appBar: AppBar(title: Text('notifications'.tr)),
      body: GetBuilder<NotificationController>(
        builder: (controller) {
          return Column(
            children: [
              const TopNativeAd(),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: controller.status,
                  widget: _buildList(context, controller),
                  onRetry: () => controller.loadNotifications(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BuildContext context, NotificationController controller) {
    if (controller.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 48, color: AppColors.textTertiary(context)),
            const SizedBox(height: 16),
            Text('no_notifications'.tr, style: AppTextStyles.bodySecondary(context)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.loadNotifications(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: controller.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final notif = controller.notifications[index];
          final isUnread = notif['read_at'] == null;
          final createdAt = notif['created_at']?.toString() ?? '';
          // The backend stores each notification twice — `title`/`body` in
          // English and `title_ar`/`body_ar` in Arabic. Pick the pair that
          // matches the language the user chose, and fall back to the other
          // one when a row only has the single translation.
          final title = _localized(notif, 'title');
          final body = _localized(notif, 'body');

          return GestureDetector(
            onTap: () {
              if (isUnread && notif['id'] != null) {
                controller.markAsRead(notif['id'] as int);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUnread
                    ? AppColors.brand(context).withValues(alpha: 0.06)
                    : null,
                border: Border.all(
                  color: isUnread
                      ? AppColors.brand(context).withValues(alpha: 0.2)
                      : Theme.of(context).dividerColor,
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.body(context).copyWith(
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.brand(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(body, style: AppTextStyles.sm(context)),
                  ],
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: AppTextStyles.xs(context).copyWith(
                        color: AppColors.textTertiary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Reads [field] from a notification row in the app's current language,
  /// falling back to the other translation when one side is missing.
  String _localized(Map<String, dynamic> notif, String field) {
    final isArabic = Get.locale?.languageCode == 'ar';
    final preferred = isArabic ? '${field}_ar' : field;
    final other = isArabic ? field : '${field}_ar';

    final value = notif[preferred]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
    return notif[other]?.toString().trim() ?? '';
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}
