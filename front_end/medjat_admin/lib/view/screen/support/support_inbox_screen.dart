import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/support_ticket_model.dart';
import '../../../logic/controller/support/support_controller.dart';

class SupportInboxScreen extends StatelessWidget {
  const SupportInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('الدعم الفني'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              final controller = Get.find<SupportController>();
              if (value == 'all') {
                controller.setStatusFilter(null);
              } else {
                controller.setStatusFilter(value);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'open', child: Text('مفتوح')),
              const PopupMenuItem(value: 'pending_support', child: Text('بانتظار الدعم')),
              const PopupMenuItem(value: 'pending_user', child: Text('بانتظار المستخدم')),
              const PopupMenuItem(value: 'resolved', child: Text('تم الحل')),
              const PopupMenuItem(value: 'closed', child: Text('مغلق')),
            ],
          ),
        ],
      ),
      body: GetBuilder<SupportController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: () => controller.loadInbox(),
            color: colors.brand,
            child: HandlingDataRequest(
              statusRequest: controller.status.value,
              onRetry: () => controller.loadInbox(),
              widget: controller.filteredTickets.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('لا توجد تذاكر')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      itemCount: controller.filteredTickets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s2),
                      itemBuilder: (context, index) =>
                          _TicketCard(ticket: controller.filteredTickets[index]),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicketModel ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Card(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: colors.borderHairline),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () {
          final controller = Get.find<SupportController>();
          controller.openThread(ticket.id);
          Get.toNamed(
            AppRoutes.supportThread,
            arguments: {'ticket_id': ticket.id},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: AppTextStyles.h3(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ticket.unreadForSupport)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Row(
                children: [
                  Icon(Icons.business, size: 14, color: colors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    ticket.tenantName,
                    style: AppTextStyles.xs(context),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  _StatusChip(status: ticket.status),
                ],
              ),
              if (ticket.lastMessagePreview != null &&
                  ticket.lastMessagePreview!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(
                  ticket.lastMessagePreview!,
                  style: AppTextStyles.sm(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'open':
        bgColor = colors.brandSubtle;
        textColor = colors.brand;
        label = 'مفتوح';
        break;
      case 'pending_support':
        bgColor = colors.warning.withValues(alpha: 0.15);
        textColor = colors.warning;
        label = 'بانتظار الدعم';
        break;
      case 'pending_user':
        bgColor = colors.success.withValues(alpha: 0.15);
        textColor = colors.success;
        label = 'بانتظار المستخدم';
        break;
      case 'resolved':
        bgColor = colors.success.withValues(alpha: 0.15);
        textColor = colors.success;
        label = 'تم الحل';
        break;
      case 'closed':
        bgColor = colors.borderHairline;
        textColor = colors.textTertiary;
        label = 'مغلق';
        break;
      default:
        bgColor = colors.sunken;
        textColor = colors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
