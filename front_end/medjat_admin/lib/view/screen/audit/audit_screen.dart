import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/audit_log_model.dart';
import '../../../logic/controller/audit/audit_controller.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل العمليات')),
      body: GetBuilder<AuditController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status.value,
            onRetry: () => controller.loadLogs(),
            widget: RefreshIndicator(
              onRefresh: () => controller.loadLogs(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                itemCount: controller.logs.length,
                itemBuilder: (context, index) {
                  return _AuditCard(log: controller.logs[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditLogModel log;

  const _AuditCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderHairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.surface,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.actionLabel,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (log.targetTypeLabel != null)
                  Text(
                    '${log.targetTypeLabel}: ${log.targetId ?? ''}',
                    style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12, color: colors.textSecondary),
                  ),
                if (log.ip != null)
                  Text(
                    log.ip!,
                    style: TextStyle(fontFamily: 'Geist', fontSize: 11, color: colors.textTertiary),
                  ),
              ],
            ),
          ),
          if (log.createdAt != null)
            Text(
              log.createdAt!.substring(0, log.createdAt!.length > 16 ? 16 : log.createdAt!.length),
              style: TextStyle(fontFamily: 'Geist', fontSize: 11, color: colors.textTertiary),
            ),
        ],
      ),
    );
  }
}
