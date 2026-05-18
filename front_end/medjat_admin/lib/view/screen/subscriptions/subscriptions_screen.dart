import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/subscription_model.dart';
import '../../../logic/controller/subscription/subscription_controller.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراكات')),
      body: GetBuilder<SubscriptionController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status.value,
            onRetry: () => controller.loadSubscriptions(),
            widget: RefreshIndicator(
              onRefresh: () => controller.loadSubscriptions(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                itemCount: controller.subscriptions.length,
                itemBuilder: (context, index) {
                  return _SubscriptionCard(sub: controller.subscriptions[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final SubscriptionModel sub;

  const _SubscriptionCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    Color statusColor;
    switch (sub.status) {
      case 'active':
        statusColor = colors.success;
        break;
      case 'suspended':
        statusColor = colors.warning;
        break;
      case 'expired':
        statusColor = colors.error;
        break;
      default:
        statusColor = colors.textTertiary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderHairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sub.tenantName ?? 'شركة #${sub.tenantId}',
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  sub.statusLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          if (sub.planName != null)
            Text('الباقة: ${sub.planName}', style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, color: colors.textSecondary)),
          if (sub.startDate != null)
            Text('من: ${sub.startDate}', style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: colors.textTertiary)),
          if (sub.endDate != null)
            Text('إلى: ${sub.endDate}', style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: colors.textTertiary)),
        ],
      ),
    );
  }
}
