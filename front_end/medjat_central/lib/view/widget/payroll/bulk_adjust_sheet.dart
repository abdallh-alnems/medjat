import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';

/// Opens the reusable bulk bonus/deduction sheet. Call it from any screen
/// that owns a scope entity (branch / shift / category):
///
/// ```dart
/// showBulkAdjustSheet(
///   context,
///   scopeType: 'category',
///   scopeId: cat.id,
///   scopeName: cat.name,
/// );
/// ```
///
/// The sheet lets the admin pick deduction vs bonus, enter an amount + reason,
/// then fans the value out to every employee in the scope via the
/// `payroll/bulk_adjust.php` endpoint.
Future<void> showBulkAdjustSheet(
  BuildContext context, {
  required String scopeType,
  required int scopeId,
  required String scopeName,
  String initialKind = 'deduction',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BulkAdjustSheet(
      scopeType: scopeType,
      scopeId: scopeId,
      scopeName: scopeName,
      initialKind: initialKind,
    ),
  );
}

class _BulkAdjustSheet extends StatefulWidget {
  final String scopeType;
  final int scopeId;
  final String scopeName;
  final String initialKind;

  const _BulkAdjustSheet({
    required this.scopeType,
    required this.scopeId,
    required this.scopeName,
    required this.initialKind,
  });

  @override
  State<_BulkAdjustSheet> createState() => _BulkAdjustSheetState();
}

class _BulkAdjustSheetState extends State<_BulkAdjustSheet> {
  final _payrollData = PayrollData();
  final _amountCtl = TextEditingController();
  final _reasonCtl = TextEditingController();

  late String _kind = widget.initialKind; // 'deduction' | 'bonus'
  String _amountType = 'fixed'; // 'fixed' | 'percent'
  bool _submitting = false;

  bool get _isPercent => _amountType == 'percent';

  @override
  void dispose() {
    _amountCtl.dispose();
    _reasonCtl.dispose();
    super.dispose();
  }

  String get _scopeLabel {
    switch (widget.scopeType) {
      case 'branch':
        return 'bulk_scope_branch'.tr;
      case 'shift':
        return 'bulk_scope_shift'.tr;
      case 'category':
        return 'bulk_scope_category'.tr;
      default:
        return widget.scopeType;
    }
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      Get.snackbar('error'.tr, 'bulk_amount_required'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_isPercent && amount > 100) {
      Get.snackbar('error'.tr, 'bulk_percent_range'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final reason = _reasonCtl.text.trim();

    final isDeduction = _kind == 'deduction';
    final confirmed = await _confirm(amount, isDeduction);
    if (confirmed != true) return;

    setState(() => _submitting = true);

    final response = await _payrollData.bulkAdjust(
      kind: _kind,
      scopeType: widget.scopeType,
      scopeId: widget.scopeId,
      amount: amount,
      amountType: _amountType,
      reason: reason,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] as Map<String, dynamic>?;
      final count = (data?['count'] as int?) ?? 0;
      final skipped = (data?['skipped'] as int?) ?? 0;
      Navigator.of(context).pop();
      var msg = (isDeduction ? 'bulk_deduction_applied' : 'bulk_bonus_applied')
          .trParams({'count': '$count'});
      if (skipped > 0) {
        msg += ' ${'bulk_skipped_note'.trParams({'skipped': '$skipped'})}';
      }
      Get.snackbar('done'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr, 'bulk_apply_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool?> _confirm(num amount, bool isDeduction) {
    final colors = AppColors.of(context);
    final String key = _isPercent
        ? (isDeduction ? 'bulk_confirm_deduction_pct' : 'bulk_confirm_bonus_pct')
        : (isDeduction ? 'bulk_confirm_deduction' : 'bulk_confirm_bonus');
    final msg = key.trParams({
      'amount': amount.toString(),
      'scope': '$_scopeLabel ${widget.scopeName}',
    });
    return Get.dialog<bool>(
      AlertDialog(
        title: Text('bulk_confirm_title'.tr),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('bulk_apply'.tr,
                style: TextStyle(
                    color: isDeduction ? colors.error : colors.success)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'bulk_adjust_for'.tr,
              style: AppTextStyles.bodySecondary(context),
            ),
            const SizedBox(height: 2),
            Text(
              '$_scopeLabel · ${widget.scopeName}',
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            _kindToggle(colors),
            const SizedBox(height: AppSpacing.s3),
            _amountTypeToggle(colors),
            const SizedBox(height: AppSpacing.s4),
            TextField(
              controller: _amountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: _isPercent ? 'bulk_percent'.tr : 'amount'.tr,
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                    _isPercent ? Icons.percent : Icons.payments_outlined),
                suffixText: _isPercent ? '%' : null,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextField(
              controller: _reasonCtl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'reason_optional'.tr,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _kind == 'deduction' ? colors.error : colors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('bulk_apply'.tr,
                        style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ),
      ),
    );
  }

  Widget _kindToggle(AppColorScheme colors) {
    Widget seg(String value, String label, Color activeColor) {
      final active = _kind == value;
      return Expanded(
        child: GestureDetector(
          onTap: _submitting ? null : () => setState(() => _kind = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            decoration: BoxDecoration(
              color: active ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          seg('deduction', 'bulk_kind_deduction'.tr, colors.error),
          seg('bonus', 'bulk_kind_bonus'.tr, colors.success),
        ],
      ),
    );
  }

  Widget _amountTypeToggle(AppColorScheme colors) {
    Widget seg(String value, String label) {
      final active = _amountType == value;
      return Expanded(
        child: GestureDetector(
          onTap:
              _submitting ? null : () => setState(() => _amountType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
            decoration: BoxDecoration(
              color: active ? colors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : colors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          seg('fixed', 'bulk_type_fixed'.tr),
          seg('percent', 'bulk_type_percent'.tr),
        ],
      ),
    );
  }
}
