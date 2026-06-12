import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/asset/asset_controller.dart';

class MyAssetsScreen extends StatelessWidget {
  const MyAssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => AssetController());
    return Scaffold(
      appBar: AppBar(title: Text('my_assets'.tr)),
      body: GetBuilder<AssetController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: controller.loadMyAssets,
            child: _body(context, controller),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, AssetController controller) {
    if (controller.myAssetsStatus == StatusRequest.loading &&
        controller.myAssets.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
              child: Text('loading'.tr,
                  style: AppTextStyles.bodySecondary(context))),
        ],
      );
    }
    if (controller.myAssets.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.inventory_2_outlined,
              size: 48, color: AppColors.of(context).textTertiary),
          const SizedBox(height: 12),
          Center(
              child: Text('no_assets'.tr,
                  style: AppTextStyles.bodySecondary(context))),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: controller.myAssets.length,
      itemBuilder: (_, i) =>
          _AssetCard(controller: controller, item: controller.myAssets[i]),
    );
  }
}

class _AssetCard extends StatelessWidget {
  final AssetController controller;
  final Map<String, dynamic> item;

  const _AssetCard({required this.controller, required this.item});

  double _toDouble(dynamic v) => double.tryParse('$v') ?? 0;
  int _toInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final status = (item['status'] as String?) ?? 'assigned';
    final type = (item['type'] as String?) ?? 'other';
    final name = item['name']?.toString() ?? '';
    final value = _toDouble(item['value']);
    final currency = item['currency']?.toString() ?? 'SAR';
    final serialNo = item['serial_no']?.toString();
    final quantity = _toInt(item['quantity']);
    final assignedAt = item['assigned_at']?.toString() ?? '';
    final rejectionReason = item['rejection_reason']?.toString();
    final statusClr = _statusColor(colors, status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: AppTextStyles.body(context)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusClr.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'asset_status_$status'.tr,
                  style: AppTextStyles.xs(context).copyWith(
                    color: statusClr,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Pill(label: 'asset_type_$type'.tr, colors: colors),
              if (quantity > 1) ...[
                const SizedBox(width: 8),
                Text('${'asset_quantity'.tr}: $quantity',
                    style: AppTextStyles.sm(context)),
              ],
            ],
          ),
          if (value > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${type == 'money' ? 'asset_amount'.tr : 'asset_value'.tr}: ${value.toStringAsFixed(0)} $currency',
              style: AppTextStyles.sm(context),
            ),
          ],
          if (serialNo != null && serialNo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${'asset_serial'.tr}: $serialNo',
                style: AppTextStyles.sm(context)),
          ],
          if (assignedAt.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('${'asset_assigned_at'.tr}: ${assignedAt.split(' ').first}',
                style: AppTextStyles.sm(context)),
          ],
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block, size: 16, color: colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(rejectionReason,
                      style: AppTextStyles.sm(context)
                          .copyWith(color: colors.error)),
                ),
              ],
            ),
          ],
          if (status == 'assigned') ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => _confirmReturn(context),
                icon: const Icon(Icons.assignment_return_outlined, size: 18),
                style: OutlinedButton.styleFrom(foregroundColor: colors.brand),
                label: Text('asset_request_return'.tr),
              ),
            ),
          ],
          if (status == 'return_requested') ...[
            const SizedBox(height: 6),
            Text('asset_return_pending'.tr,
                style: AppTextStyles.sm(context)
                    .copyWith(color: colors.warning)),
          ],
        ],
      ),
    );
  }

  void _confirmReturn(BuildContext context) {
    final noteCtrl = TextEditingController();
    final colors = AppColors.of(context);
    Get.dialog<void>(
      AlertDialog(
        title: Text('asset_request_return'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('asset_request_return_confirm'.tr,
                style: AppTextStyles.sm(context)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '${'asset_notes'.tr} (${'optional'.tr})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              Get.back<void>();
              controller.requestReturn(
                _toInt(item['id']),
                note: noteCtrl.text,
              );
            },
            style: TextButton.styleFrom(foregroundColor: colors.brand),
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
  }

  Color _statusColor(AppColorScheme colors, String status) {
    switch (status) {
      case 'returned':
        return colors.success;
      case 'return_requested':
        return colors.warning;
      case 'assigned':
        return colors.brand;
      default:
        return colors.textTertiary;
    }
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final AppColorScheme colors;

  const _Pill({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Text(label,
          style:
              AppTextStyles.xs(context).copyWith(color: colors.textSecondary)),
    );
  }
}
