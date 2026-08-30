import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../data/model/support_model.dart';
import '../../../logic/controller/support/support_controller.dart';

class SupportTicketsScreen extends StatelessWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SupportController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('support_tickets'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_support',
        onPressed: () => Get.toNamed<void>(AppRoutes.supportNew),
        backgroundColor: colors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.tickets.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (controller.tickets.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent_outlined,
                    size: 48, color: colors.textTertiary),
                const SizedBox(height: AppSpacing.s3),
                Text(
                  'no_support_tickets'.tr,
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
          onRefresh: () => controller.loadTickets(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s4),
            itemCount: controller.tickets.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
            itemBuilder: (context, index) {
              final ticket = controller.tickets[index];
              return _TicketTile(
                ticket: ticket,
                colors: colors,
                onTap: () {
                  Get.toNamed<void>(
                    AppRoutes.supportChat,
                    arguments: {'ticket_id': ticket.id},
                  );
                },
              );
            },
          ),
        );
      }),
    );
  }
}

class _TicketTile extends StatelessWidget {
  final SupportTicketModel ticket;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _TicketTile({
    required this.ticket,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = ticket.unreadForUser;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: isUnread ? colors.brandSubtle : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isUnread
                ? colors.brand.withValues(alpha: 0.2)
                : colors.borderHairline,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s2),
              decoration: BoxDecoration(
                color: isUnread
                    ? colors.brand.withValues(alpha: 0.1)
                    : colors.sunken,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.support_agent_outlined,
                size: 20,
                color: isUnread ? colors.brand : colors.textTertiary,
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.subject,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight:
                                isUnread ? FontWeight.w600 : FontWeight.w400,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _StatusChip(status: ticket.status, colors: colors),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (ticket.lastMessagePreview != null &&
                      ticket.lastMessagePreview!.isNotEmpty)
                    Text(
                      ticket.lastMessagePreview!,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.categoryLabel.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: AppSpacing.s2),
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
}

class _StatusChip extends StatelessWidget {
  final String status;
  final AppColorScheme colors;

  const _StatusChip({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = _colors();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        _label().tr,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _label() {
    const map = {
      'open': 'ticket_status_open',
      'pending_support': 'ticket_status_pending_support',
      'pending_user': 'ticket_status_pending_user',
      'resolved': 'ticket_status_resolved',
      'closed': 'ticket_status_closed',
    };
    return map[status] ?? status;
  }

  (Color, Color) _colors() {
    switch (status) {
      case 'open':
        return (colors.brandSubtle, colors.brand);
      case 'pending_support':
        return (colors.warning.withValues(alpha: 0.1), colors.warning);
      case 'pending_user':
        return (colors.accentWarm.withValues(alpha: 0.1), colors.accentWarm);
      case 'resolved':
        return (colors.success.withValues(alpha: 0.1), colors.success);
      case 'closed':
        return (colors.sunken, colors.textTertiary);
      default:
        return (colors.sunken, colors.textTertiary);
    }
  }
}
