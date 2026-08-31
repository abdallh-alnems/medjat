import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../logic/controller/notification/notification_controller.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('notifications'.tr)),
      body: Obx(() {
        if (controller.isLoading.value && controller.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (controller.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 48, color: colors.textTertiary),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'no_notifications'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadNotifications(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s4),
            itemCount: controller.notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
            itemBuilder: (context, index) {
              final notif = controller.notifications[index];
              final isRead = notif['read_at'] != null;
              final type = (notif['type'] ?? 'general') as String;
              final notifId = notif['id'] as int;

              return _NotificationTile(
                notification: notif,
                isRead: isRead,
                icon: _iconForType(type),
                colors: colors,
                onTap: () {
                  if (!isRead) {
                    controller.markAsRead(notifId);
                  }
                },
              );
            },
          ),
        );
      }),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'attendance':
        return Icons.access_time;
      case 'payroll':
        return Icons.payments_outlined;
      case 'leave':
        return Icons.event_note_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      case 'invite':
        return Icons.group_add_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isRead;
  final IconData icon;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isRead,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale?.languageCode ?? 'ar';
    final title = (locale == 'ar'
            ? (notification['title_ar'] ?? notification['title'] ?? '')
            : (notification['title'] ?? notification['title_ar'] ?? ''))
        as String;
    final body = (locale == 'ar'
            ? (notification['body_ar'] ?? notification['body'] ?? '')
            : (notification['body'] ?? notification['body_ar'] ?? ''))
        as String;
    final createdAt = (notification['created_at'] ?? '') as String;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: isRead ? colors.surface : colors.brandSubtle,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isRead
                ? colors.borderHairline
                : colors.brand.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s2),
              decoration: BoxDecoration(
                color: isRead
                    ? colors.sunken
                    : colors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon,
                  size: 20,
                  color: isRead ? colors.textTertiary : colors.brand),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: colors.brand,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'just_now'.tr;
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} ${'minutes_ago'.tr}';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours} ${'hours_ago'.tr}';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays} ${'days_ago'.tr}';
      }
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
