import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/bulk_adjustment_model.dart';
import '../../../logic/controller/bulk_adjustment/bulk_adjustment_controller.dart';

/// "Bulk deductions & bonuses" — reachable from the More page. Lists every
/// tracked batch; tap one to manage its members, FAB to create a new one.
class BulkAdjustmentsScreen extends StatelessWidget {
  const BulkAdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<BulkAdjustmentController>(BulkAdjustmentController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('bulk_adjustments'.tr)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_bulk_adjust',
        onPressed: () async {
          await Get.toNamed<void>(AppRoutes.bulkAdjustmentCreate);
        },
        backgroundColor: colors.brand,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('bulk_adjustment_new'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.loadBatches,
        child: GetBuilder<BulkAdjustmentController>(
          builder: (_) => HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadBatches,
            widget: ctrl.batches.isEmpty
                ? _EmptyState(colors: colors)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s7),
                    itemCount: ctrl.batches.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.s2),
                    itemBuilder: (_, i) => _BatchTile(batch: ctrl.batches[i]),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Human label for a batch scope, e.g. "كل الموظفين" or "فرع · القاهرة".
String scopeLabel(BulkAdjustmentModel b) {
  switch (b.scopeType) {
    case 'all':
      return 'bulk_scope_all'.tr;
    case 'branch':
      return '${'bulk_scope_branch'.tr} · ${b.scopeName ?? ''}';
    case 'category':
      return '${'bulk_scope_category'.tr} · ${b.scopeName ?? ''}';
    case 'employee':
      return '${'bulk_scope_employee'.tr} · ${b.scopeName ?? ''}';
    default:
      return b.scopeName ?? b.scopeType;
  }
}

class _EmptyState extends StatelessWidget {
  final AppColorScheme colors;
  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.tune_outlined, size: 48, color: colors.textTertiary),
        const SizedBox(height: AppSpacing.s3),
        Center(
          child: Text('bulk_adjustments_empty'.tr,
              style: AppTextStyles.bodySecondary(context)),
        ),
      ],
    );
  }
}

class _BatchTile extends StatelessWidget {
  final BulkAdjustmentModel batch;
  const _BatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = batch.isBonus ? colors.success : colors.error;
    final amountText = batch.isPercent
        ? '${_trimNum(batch.amount)}%'
        : _trimNum(batch.amount);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => Get.toNamed<void>(
        AppRoutes.bulkAdjustmentDetail,
        arguments: batch.id,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    batch.isBonus
                        ? 'bulk_kind_bonus'.tr
                        : 'bulk_kind_deduction'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  amountText,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              scopeLabel(batch),
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (batch.reason.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(batch.reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sm(context)),
            ],
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.people_outline, size: 15, color: colors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'bulk_member_count'.trParams({'count': '${batch.memberCount}'}),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  'bulk_total'.trParams(
                      {'total': _trimNum(batch.totalAmount)}),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _trimNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}
