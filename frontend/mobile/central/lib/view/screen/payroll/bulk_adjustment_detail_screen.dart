import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/data_source/remote/bulk_adjustment_data/bulk_adjustment_data.dart';
import '../../../data/model/bulk_adjustment_model.dart';
import '../../../logic/controller/bulk_adjustment/bulk_adjustment_controller.dart';
import 'bulk_adjustments_screen.dart' show scopeLabel;

/// Detail of one bulk batch: edit its amount/percent, remove a single employee,
/// or delete the whole batch.
class BulkAdjustmentDetailScreen extends StatefulWidget {
  const BulkAdjustmentDetailScreen({super.key});

  @override
  State<BulkAdjustmentDetailScreen> createState() =>
      _BulkAdjustmentDetailScreenState();
}

class _BulkAdjustmentDetailScreenState
    extends State<BulkAdjustmentDetailScreen> {
  final BulkAdjustmentData _data = Get.find<BulkAdjustmentData>();
  late final int _id = Get.arguments as int;

  StatusRequest _status = StatusRequest.loading;
  BulkAdjustmentModel? _batch;
  List<BulkAdjustmentMember> _members = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = StatusRequest.loading);
    final response = await _data.getOne(_id);
    if (response['status'] != StatusRequest.success) {
      setState(() => _status =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure);
      return;
    }
    dynamic payload = response['data'];
    if (payload is Map && payload['data'] is Map) payload = payload['data'];
    final batchJson = (payload as Map)['batch'] as Map<String, dynamic>?;
    final membersJson = (payload['members'] as List?) ?? [];
    setState(() {
      _batch = batchJson != null
          ? BulkAdjustmentModel.fromJson(batchJson)
          : null;
      _members = membersJson
          .whereType<Map<String, dynamic>>()
          .map(BulkAdjustmentMember.fromJson)
          .toList();
      _status = _batch == null ? StatusRequest.failure : StatusRequest.success;
    });
  }

  void _refreshList() {
    if (Get.isRegistered<BulkAdjustmentController>()) {
      Get.find<BulkAdjustmentController>().loadBatches();
    }
  }

  Future<void> _removeMember(BulkAdjustmentMember m) async {
    final ok = await _confirm(
      title: 'bulk_remove_member_title'.tr,
      message: 'bulk_remove_member_confirm'.trParams({'name': m.employeeName}),
      danger: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final res = await _data.removeMember(_id, m.id);
    setState(() => _busy = false);
    if (res['status'] == StatusRequest.success) {
      setState(() => _members.removeWhere((x) => x.id == m.id));
      _refreshList();
      Get.snackbar('done'.tr, 'bulk_member_removed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr, 'bulk_action_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _deleteBatch() async {
    final ok = await _confirm(
      title: 'bulk_delete_title'.tr,
      message: 'bulk_delete_confirm'.tr,
      danger: true,
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final res = await _data.delete(_id);
    setState(() => _busy = false);
    if (res['status'] == StatusRequest.success) {
      _refreshList();
      Get.back<void>();
      Get.snackbar('done'.tr, 'bulk_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr, 'bulk_action_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _editBatch() async {
    final batch = _batch;
    if (batch == null) return;
    final amountCtl =
        TextEditingController(text: _trimNum(batch.amount));
    final reasonCtl = TextEditingController(text: batch.reason);
    String amountType = batch.amountType;

    final saved = await Get.bottomSheet<bool>(
      StatefulBuilder(
        builder: (context, setSheet) {
          final colors = AppColors.of(context);
          final isPercent = amountType == 'percent';
          return Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s4,
              AppSpacing.s4 + MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('bulk_edit_title'.tr, style: AppTextStyles.h3(context)),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  children: [
                    _typeChip(colors, 'fixed', 'bulk_type_fixed'.tr,
                        amountType, (v) => setSheet(() => amountType = v)),
                    const SizedBox(width: AppSpacing.s2),
                    _typeChip(colors, 'percent', 'bulk_type_percent'.tr,
                        amountType, (v) => setSheet(() => amountType = v)),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                TextField(
                  controller: amountCtl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: isPercent ? 'bulk_percent'.tr : 'amount'.tr,
                    border: const OutlineInputBorder(),
                    suffixText: isPercent ? '%' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.s3),
                TextField(
                  controller: reasonCtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'reason_optional'.tr,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Get.back<bool>(result: true),
                    child: Text('save'.tr),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (saved != true) return;
    final amount = num.tryParse(amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      Get.snackbar('error'.tr, 'bulk_amount_required'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (amountType == 'percent' && amount > 100) {
      Get.snackbar('error'.tr, 'bulk_percent_range'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _busy = true);
    final res = await _data.update(
      id: _id,
      amount: amount,
      amountType: amountType,
      reason: reasonCtl.text.trim(),
    );
    setState(() => _busy = false);
    if (res['status'] == StatusRequest.success) {
      await _load();
      _refreshList();
      Get.snackbar('done'.tr, 'bulk_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr, 'bulk_action_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Widget _typeChip(AppColorScheme colors, String value, String label,
      String current, void Function(String) onTap) {
    final active = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.brand : colors.sunken,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
                color: active ? colors.brand : colors.borderHairline),
          ),
          child: Text(label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : colors.textSecondary,
              )),
        ),
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    bool danger = false,
  }) {
    final colors = AppColors.of(context);
    return Get.dialog<bool>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title,
              style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          content: Text(message,
              style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic', fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: danger
                  ? TextButton.styleFrom(foregroundColor: colors.error)
                  : null,
              child: Text('confirm'.tr),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final batch = _batch;

    return Scaffold(
      appBar: AppBar(
        title: Text('bulk_adjustment_detail'.tr),
        actions: [
          if (batch != null) ...[
            IconButton(
              tooltip: 'edit'.tr,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _editBatch,
            ),
            IconButton(
              tooltip: 'delete'.tr,
              icon: Icon(Icons.delete_outline, color: colors.error),
              onPressed: _busy ? null : _deleteBatch,
            ),
          ],
        ],
      ),
      body: _status == StatusRequest.loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _status != StatusRequest.success || batch == null
              ? Center(child: Text('bulk_action_failed'.tr))
              : Column(
                  children: [
                    _header(colors, batch),
                    Expanded(
                      child: _members.isEmpty
                          ? Center(
                              child: Text('bulk_no_members'.tr,
                                  style: AppTextStyles.bodySecondary(context)))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.s4,
                                  AppSpacing.s2, AppSpacing.s4, AppSpacing.s7),
                              itemCount: _members.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.s2),
                              itemBuilder: (_, i) =>
                                  _memberTile(colors, _members[i]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _header(AppColorScheme colors, BulkAdjustmentModel batch) {
    final accent = batch.isBonus ? colors.success : colors.error;
    final amountText =
        batch.isPercent ? '${_trimNum(batch.amount)}%' : _trimNum(batch.amount);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.s4),
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
              Text(amountText,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(scopeLabel(batch),
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              )),
          if (batch.reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(batch.reason, style: AppTextStyles.sm(context)),
          ],
          const SizedBox(height: AppSpacing.s2),
          Text(
            'bulk_member_count'.trParams({'count': '${_members.length}'}),
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(AppColorScheme colors, BulkAdjustmentMember m) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(m.employeeName,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                )),
          ),
          Text(_trimNum(m.amount),
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              )),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: colors.error),
            onPressed: _busy ? null : () => _removeMember(m),
          ),
        ],
      ),
    );
  }
}

String _trimNum(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}
