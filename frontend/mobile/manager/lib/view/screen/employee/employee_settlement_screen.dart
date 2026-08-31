import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../logic/controller/settlement/settlement_controller.dart';
import '../../../data/model/settlement_model.dart';

/// End-of-service settlement page ("تسوية نهاية الخدمة"). Auto-computes the
/// final dues and lets HR edit every line, then save the draft, approve (which
/// ends the employee's service) and mark it paid.
class EmployeeSettlementScreen extends StatelessWidget {
  const EmployeeSettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? {};
    final employeeId = (args['employee_id'] as int?) ?? 0;
    final employeeName = (args['employee_name'] as String?) ?? '';

    final ctrl = Get.put<SettlementController>(
      SettlementController(employeeId: employeeId, employeeName: employeeName),
      tag: 'settlement_$employeeId',
    );
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('settlement_title'.tr)),
      body: GetBuilder<SettlementController>(
        init: ctrl,
        tag: 'settlement_$employeeId',
        builder: (c) => HandlingDataRequest(
          statusRequest: c.status,
          onRetry: c.load,
          widget: _Body(ctrl: c, colors: colors, employeeName: employeeName),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final SettlementController ctrl;
  final AppColorScheme colors;
  final String employeeName;
  const _Body(
      {required this.ctrl, required this.colors, required this.employeeName});

  @override
  Widget build(BuildContext context) {
    final s = ctrl.settlement;
    final locked = ctrl.isLocked;
    final editable = !locked;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            _headerCard(context, s),
            const SizedBox(height: AppSpacing.s4),
            _reasonAndDate(context, s, editable),
            const SizedBox(height: AppSpacing.s4),
            _sectionTitle('settlement_earnings'.tr, Icons.add_circle_outline,
                colors.success),
            _earningsCard(s, editable),
            const SizedBox(height: AppSpacing.s4),
            _sectionTitle('settlement_deductions'.tr,
                Icons.remove_circle_outline, colors.error),
            _deductionsCard(s, editable),
            const SizedBox(height: AppSpacing.s4),
            _customItemsCard(context, s, editable),
            const SizedBox(height: AppSpacing.s4),
            _notesCard(s, editable),
            const SizedBox(height: AppSpacing.s4),
            _summaryCard(context, s),
            const SizedBox(height: AppSpacing.s8),
            const SizedBox(height: AppSpacing.s8),
          ],
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: _actionBar(context),
        ),
      ],
    );
  }

  // ── Header ──────────────────────────────────────────────
  Widget _headerCard(BuildContext context, SettlementModel s) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.brandSubtle,
                child: Icon(Icons.badge_outlined, color: colors.brand),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employeeName,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                    Text(
                      ctrl.isAlreadyTerminated
                          ? 'settlement_emp_terminated'.tr
                          : 'settlement_emp_active'.tr,
                      style: TextStyle(
                          fontSize: 12, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusChip(s),
            ],
          ),
          const Divider(height: AppSpacing.s5),
          Row(
            children: [
              _infoCell('settlement_base_salary'.tr,
                  s.baseSalary.toStringAsFixed(2)),
              _infoCell('settlement_daily_rate'.tr,
                  s.dailyRate.toStringAsFixed(2)),
              _infoCell('settlement_years'.tr,
                  s.yearsOfService.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(SettlementModel s) {
    Color c;
    switch (s.status) {
      case 'approved':
        c = colors.warning;
        break;
      case 'paid':
        c = colors.success;
        break;
      default:
        c = colors.textSecondary;
    }
    final label = s.status == 'new' ? 'settlement_status_new'.tr : s.statusLabel;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }

  Widget _infoCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
        ],
      ),
    );
  }

  // ── Reason + last working day ───────────────────────────
  Widget _reasonAndDate(
      BuildContext context, SettlementModel s, bool editable) {
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('settlement_reason'.tr,
                        style: TextStyle(
                            fontSize: 12, color: colors.textSecondary)),
                    const SizedBox(height: AppSpacing.s1),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: s.reason,
                        isExpanded: true,
                        items: SettlementController.reasons
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text('settlement_reason_$r'.tr),
                                ))
                            .toList(),
                        onChanged: editable
                            ? (v) {
                                if (v != null) ctrl.setReason(v);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          InkWell(
            onTap: editable ? () => _pickDate(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 18, color: colors.textSecondary),
                  const SizedBox(width: AppSpacing.s2),
                  Text('settlement_last_working_day'.tr,
                      style: TextStyle(
                          fontSize: 13, color: colors.textSecondary)),
                  const Spacer(),
                  Text(
                    s.lastWorkingDay.isEmpty ? '—' : s.lastWorkingDay,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary),
                  ),
                  if (editable) ...[
                    const SizedBox(width: AppSpacing.s1),
                    Icon(Icons.edit_outlined,
                        size: 16, color: colors.brand),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = DateTime.tryParse(ctrl.settlement.lastWorkingDay) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final d = picked.toIso8601String().substring(0, 10);
      await ctrl.changeLastWorkingDay(d);
    }
  }

  // ── Earnings ────────────────────────────────────────────
  Widget _earningsCard(SettlementModel s, bool editable) {
    return _card(
      child: Column(
        children: [
          _MoneyField(
            label: 'settlement_pending_salary'.tr,
            value: s.pendingSalary,
            enabled: editable,
            onChanged: (v) => ctrl.editField((m) => m.pendingSalary = v),
          ),
          _twoFields(
            left: _MoneyField(
              label: 'settlement_gratuity_days'.tr,
              value: s.gratuityDays,
              enabled: editable,
              onChanged: (v) => ctrl.editField((m) {
                m.gratuityDays = v;
                m.gratuityAmount = double.parse(
                    (v * m.dailyRate).toStringAsFixed(2));
              }),
            ),
            right: _MoneyField(
              label: 'settlement_gratuity_amount'.tr,
              value: s.gratuityAmount,
              enabled: editable,
              onChanged: (v) => ctrl.editField((m) => m.gratuityAmount = v),
            ),
          ),
          _twoFields(
            left: _MoneyField(
              label: 'settlement_leave_days'.tr,
              value: s.leaveBalanceDays,
              enabled: editable,
              onChanged: (v) => ctrl.editField((m) {
                m.leaveBalanceDays = v;
                m.leaveEncashment = double.parse(
                    (v * m.dailyRate).toStringAsFixed(2));
              }),
            ),
            right: _MoneyField(
              label: 'settlement_leave_encashment'.tr,
              value: s.leaveEncashment,
              enabled: editable,
              onChanged: (v) => ctrl.editField((m) => m.leaveEncashment = v),
            ),
          ),
          _MoneyField(
            label: 'settlement_other_additions'.tr,
            value: s.otherAdditions,
            enabled: editable,
            onChanged: (v) => ctrl.editField((m) => m.otherAdditions = v),
          ),
        ],
      ),
    );
  }

  // ── Deductions ──────────────────────────────────────────
  Widget _deductionsCard(SettlementModel s, bool editable) {
    return _card(
      child: Column(
        children: [
          _MoneyField(
            label: 'settlement_outstanding_loans'.tr,
            value: s.outstandingLoans,
            enabled: editable,
            onChanged: (v) => ctrl.editField((m) => m.outstandingLoans = v),
          ),
          _MoneyField(
            label: 'settlement_other_deductions'.tr,
            value: s.otherDeductions,
            enabled: editable,
            onChanged: (v) => ctrl.editField((m) => m.otherDeductions = v),
          ),
        ],
      ),
    );
  }

  // ── Custom line items ───────────────────────────────────
  Widget _customItemsCard(
      BuildContext context, SettlementModel s, bool editable) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_outlined,
                  size: 18, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Text('settlement_custom_items'.tr,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary)),
              const Spacer(),
              if (editable)
                TextButton.icon(
                  onPressed: ctrl.addLineItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('settlement_add_item'.tr),
                ),
            ],
          ),
          if (s.lineItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Text('settlement_no_custom_items'.tr,
                  style:
                      TextStyle(fontSize: 12, color: colors.textTertiary)),
            ),
          ...List.generate(s.lineItems.length, (i) {
            final item = s.lineItems[i];
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _PlainTextField(
                      key: ValueKey('li_label_${i}_${item.label}'),
                      hint: 'settlement_item_label'.tr,
                      value: item.label,
                      enabled: editable,
                      onChanged: (v) => ctrl.editField((_) => item.label = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    flex: 3,
                    child: _MoneyField(
                      label: '',
                      compact: true,
                      value: item.amount,
                      enabled: editable,
                      onChanged: (v) => ctrl.editField((_) => item.amount = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s1),
                  _kindToggle(item, editable),
                  if (editable)
                    IconButton(
                      icon: Icon(Icons.close,
                          size: 18, color: colors.error),
                      onPressed: () => ctrl.removeLineItem(i),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _kindToggle(SettlementLineItem item, bool editable) {
    final isDed = item.isDeduction;
    return InkWell(
      onTap: editable
          ? () => ctrl.editField(
              (_) => item.kind = isDed ? 'earning' : 'deduction')
          : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (isDed ? colors.error : colors.success)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(isDed ? Icons.remove : Icons.add,
            size: 16, color: isDed ? colors.error : colors.success),
      ),
    );
  }

  Widget _notesCard(SettlementModel s, bool editable) {
    return _card(
      child: _PlainTextField(
        key: ValueKey('notes_${s.id ?? 'new'}'),
        hint: 'settlement_notes'.tr,
        value: s.notes ?? '',
        enabled: editable,
        maxLines: 3,
        onChanged: (v) => ctrl.editField((m) => m.notes = v),
      ),
    );
  }

  // ── Summary ─────────────────────────────────────────────
  Widget _summaryCard(BuildContext context, SettlementModel s) {
    return _card(
      bg: colors.brandSubtle,
      child: Column(
        children: [
          _summaryRow('settlement_total_earnings'.tr,
              s.totalEarnings.toStringAsFixed(2), colors.success),
          const SizedBox(height: AppSpacing.s2),
          _summaryRow('settlement_total_deductions'.tr,
              '- ${s.totalDeductions.toStringAsFixed(2)}', colors.error),
          const Divider(height: AppSpacing.s5),
          _summaryRow(
            'settlement_net'.tr,
            s.netAmount.toStringAsFixed(2),
            colors.brand,
            big: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color,
      {bool big = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: big ? 15 : 13,
                fontWeight: big ? FontWeight.w700 : FontWeight.w500,
                color: colors.textPrimary)),
        Text(value,
            style: TextStyle(
                fontSize: big ? 18 : 14,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  // ── Action bar ──────────────────────────────────────────
  Widget _actionBar(BuildContext context) {
    final s = ctrl.settlement;
    final busy = ctrl.actionStatus == StatusRequest.loading;
    final List<Widget> buttons = [];

    if (s.isDraft && !ctrl.isAlreadyTerminated) {
      buttons.add(Expanded(
        child: OutlinedButton.icon(
          onPressed: busy ? null : ctrl.save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text('settlement_save'.tr),
        ),
      ));
      buttons.add(const SizedBox(width: AppSpacing.s2));
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          onPressed: busy ? null : () => _confirmApprove(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand, foregroundColor: Colors.white),
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: Text('settlement_approve'.tr),
        ),
      ));
    } else if (s.status == 'approved') {
      buttons.add(Expanded(
        child: ElevatedButton.icon(
          onPressed: busy ? null : ctrl.markPaid,
          style: ElevatedButton.styleFrom(
              backgroundColor: colors.success, foregroundColor: Colors.white),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: Text('settlement_mark_paid'.tr),
        ),
      ));
    } else if (s.status == 'paid') {
      buttons.add(Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('settlement_paid_done'.tr,
              style: TextStyle(
                  color: colors.success, fontWeight: FontWeight.w700)),
        ),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ...buttons,
            if (busy) ...[
              const SizedBox(width: AppSpacing.s3),
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmApprove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('settlement_approve_title'.tr),
        content: Text('settlement_approve_confirm'.trParams({
          'amount': ctrl.settlement.netAmount.toStringAsFixed(2),
        })),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('cancel'.tr)),
          ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: Text('settlement_approve'.tr)),
        ],
      ),
    );
    if (ok == true) {
      // Persist any pending edits first, then approve.
      final saved = await ctrl.save();
      if (saved) await ctrl.approve();
    }
  }

  // ── Shared bits ─────────────────────────────────────────
  Widget _sectionTitle(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.s2),
          Text(text,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _twoFields({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppSpacing.s3),
        Expanded(child: right),
      ],
    );
  }

  Widget _card({required Widget child, Color? bg}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: bg ?? colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderHairline),
      ),
      child: child,
    );
  }
}

/// A numeric input that keeps its own controller and reflects external value
/// changes (e.g. when the last working day is changed and figures recompute).
class _MoneyField extends StatefulWidget {
  final String label;
  final double value;
  final bool enabled;
  final bool compact;
  final ValueChanged<double> onChanged;

  const _MoneyField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _c;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(covariant _MoneyField old) {
    super.didUpdateWidget(old);
    // Refresh the text from the model only when the field is not being edited,
    // so recomputed suggestions land but typing isn't interrupted.
    if (!_focus.hasFocus && widget.value != _parse(_c.text)) {
      _c.text = _fmt(widget.value);
    }
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  double _parse(String t) => double.tryParse(t.trim()) ?? 0;

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final field = TextField(
      controller: _c,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: !widget.enabled,
        fillColor: colors.sunken,
      ),
      onChanged: (v) => widget.onChanged(_parse(v)),
    );

    if (widget.compact || widget.label.isEmpty) return field;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: AppSpacing.s1),
          field,
        ],
      ),
    );
  }
}

/// A plain text input that initializes once from [value]; used for custom
/// line-item labels and notes.
class _PlainTextField extends StatefulWidget {
  final String hint;
  final String value;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _PlainTextField({
    super.key,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  State<_PlainTextField> createState() => _PlainTextFieldState();
}

class _PlainTextFieldState extends State<_PlainTextField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TextField(
      controller: _c,
      enabled: widget.enabled,
      maxLines: widget.maxLines,
      style: TextStyle(fontSize: 14, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: widget.hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: widget.onChanged,
    );
  }
}
