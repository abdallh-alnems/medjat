import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/services/locale_service.dart';
import '../../../data/model/compliance_item_model.dart';
import '../../../logic/controller/dashboard/expiring_compliance_controller.dart';

class ExpiringComplianceScreen extends StatelessWidget {
  const ExpiringComplianceScreen({super.key});

  IconData _icon(String credential) {
    switch (credential) {
      case 'iqama':
        return Icons.badge_outlined;
      case 'passport':
        return Icons.book_outlined;
      case 'work_permit':
        return Icons.work_outline;
      case 'contract':
        return Icons.description_outlined;
      case 'health_insurance':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.event_busy_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ExpiringComplianceController());

    return Scaffold(
      appBar: AppBar(title: Text('expiring_compliance'.tr)),
      body: RefreshIndicator(
        onRefresh: ctrl.load,
        child: GetBuilder<ExpiringComplianceController>(
          builder: (_) => HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.load,
            widget: ctrl.items.isEmpty
                ? _empty(context)
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    itemCount: ctrl.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.s2),
                    itemBuilder: (_, i) => _tile(context, ctrl.items[i]),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s9),
          child: Column(
            children: [
              Icon(Icons.verified_outlined, size: 48, color: colors.success),
              const SizedBox(height: AppSpacing.s3),
              Text('no_expiring_documents'.tr,
                  style: AppTextStyles.sm(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, ComplianceItem item) {
    final colors = AppColors.of(context);
    final locale = Get.find<LocaleService>().currentLocale.languageCode;
    final accent = item.isExpired
        ? colors.error
        : (item.daysLeft <= 7 ? colors.warning : colors.accentWarm);

    String dateLabel = item.expiresAt;
    final parsed = DateTime.tryParse(item.expiresAt);
    if (parsed != null) {
      dateLabel = DateFormat('d MMM yyyy', locale).format(parsed);
    }

    final statusText = item.isExpired
        ? 'expired'.tr
        : (item.daysLeft == 0
            ? 'expires_today'.tr
            : '${item.daysLeft} ${'day_unit'.tr}');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_icon(item.credential), size: 18, color: accent),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.branchName == null
                      ? item.credentialKey.tr
                      : '${item.credentialKey.tr} · ${item.branchName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.xs(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
