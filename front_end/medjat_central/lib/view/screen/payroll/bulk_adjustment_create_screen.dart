import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constant/theme/theme.dart';
import '../../../logic/controller/bulk_adjustment/bulk_adjustment_controller.dart';

/// Create a new bulk deduction/bonus: pick kind, target scope (all / branch /
/// category / one employee), fixed-vs-percent, amount and reason.
class BulkAdjustmentCreateScreen extends StatefulWidget {
  const BulkAdjustmentCreateScreen({super.key});

  @override
  State<BulkAdjustmentCreateScreen> createState() =>
      _BulkAdjustmentCreateScreenState();
}

class _BulkAdjustmentCreateScreenState
    extends State<BulkAdjustmentCreateScreen> {
  late final BulkAdjustmentController _ctrl =
      Get.isRegistered<BulkAdjustmentController>()
          ? Get.find<BulkAdjustmentController>()
          : Get.put(BulkAdjustmentController());
  final _amountCtl = TextEditingController();
  final _reasonCtl = TextEditingController();

  String _kind = 'deduction'; // 'deduction' | 'bonus'
  String _scopeType = 'all'; // 'all' | 'branch' | 'category' | 'employee'
  String _amountType = 'fixed'; // 'fixed' | 'percent'
  int? _scopeId;
  String? _scopeName; // display name of the picked target
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _submitting = false;

  String get _monthStr =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  bool get _isPercent => _amountType == 'percent';
  bool get _needsTarget => _scopeType != 'all';

  @override
  void initState() {
    super.initState();
    // Defer until after the first frame: loadOptions() calls update() on the
    // shared controller, which would otherwise fire during this build phase.
    if (!_ctrl.optionsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.loadOptions());
    }
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _reasonCtl.dispose();
    super.dispose();
  }

  List<ScopeOption> get _targetOptions {
    switch (_scopeType) {
      case 'branch':
        return _ctrl.branches;
      case 'category':
        return _ctrl.categories;
      case 'employee':
        return _ctrl.employees;
      default:
        return const [];
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
    if (_needsTarget && _scopeId == null) {
      Get.snackbar('error'.tr, 'bulk_target_required'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Preview first: resolve how many employees are affected and surface any
    // warnings (locked month / zero base / duplicate) before writing.
    setState(() => _submitting = true);
    final preview = await _ctrl.preview(
      kind: _kind,
      scopeType: _scopeType,
      scopeId: _needsTarget ? _scopeId : null,
      amount: amount,
      amountType: _amountType,
      month: _monthStr,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (preview == null) {
      Get.snackbar('error'.tr, 'bulk_apply_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final eligible = (preview['eligible_count'] as num?)?.toInt() ?? 0;
    if (eligible <= 0) {
      Get.snackbar('error'.tr, 'bulk_none_eligible'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final confirmed = await _confirm(amount, preview);
    if (confirmed != true) return;

    setState(() => _submitting = true);
    final payload = await _ctrl.create(
      kind: _kind,
      scopeType: _scopeType,
      scopeId: _needsTarget ? _scopeId : null,
      amount: amount,
      amountType: _amountType,
      reason: _reasonCtl.text.trim(),
      month: _monthStr,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (payload != null) {
      final count = (payload['count'] as num?)?.toInt() ?? 0;
      Get.back<void>();
      Get.snackbar(
        'done'.tr,
        (_kind == 'deduction' ? 'bulk_deduction_applied' : 'bulk_bonus_applied')
            .trParams({'count': '$count'}),
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar('error'.tr, 'bulk_apply_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool?> _confirm(num amount, Map<String, dynamic> preview) {
    final colors = AppColors.of(context);
    final isDeduction = _kind == 'deduction';
    final scopeText = _scopeType == 'all'
        ? 'bulk_scope_all'.tr
        : (_targetOptions.firstWhereOrNull((o) => o.id == _scopeId)?.name ?? '');
    final amountText = _isPercent ? '$amount%' : '$amount';

    final eligible = (preview['eligible_count'] as num?)?.toInt() ?? 0;
    final locked = (preview['locked_count'] as num?)?.toInt() ?? 0;
    final zero = (preview['zero_count'] as num?)?.toInt() ?? 0;
    final duplicate = preview['duplicate'] == true;

    final lines = <Widget>[
      Text('bulk_confirm_generic'
          .trParams({'amount': amountText, 'scope': scopeText})),
      const SizedBox(height: AppSpacing.s2),
      Text('bulk_confirm_eligible'.trParams({'count': '$eligible'}),
          style: const TextStyle(fontWeight: FontWeight.w700)),
    ];
    if (locked > 0) {
      lines.add(const SizedBox(height: AppSpacing.s2));
      lines.add(_warnLine(
          colors, 'bulk_warn_locked'.trParams({'count': '$locked'})));
    }
    if (zero > 0) {
      lines.add(const SizedBox(height: AppSpacing.s2));
      lines.add(_warnLine(
          colors, 'bulk_warn_zero'.trParams({'count': '$zero'})));
    }
    if (duplicate) {
      lines.add(const SizedBox(height: AppSpacing.s2));
      lines.add(_warnLine(colors, 'bulk_warn_duplicate'.tr));
    }

    return Get.dialog<bool>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('bulk_confirm_title'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines,
          ),
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
      ),
    );
  }

  Widget _warnLine(AppColorScheme colors, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: colors.warning),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('bulk_adjustment_new'.tr)),
      body: GetBuilder<BulkAdjustmentController>(
        builder: (_) => ListView(
          padding: const EdgeInsets.all(AppSpacing.s4),
          children: [
            _SectionLabel('bulk_kind_label'.tr),
            _segmented(
              colors: colors,
              value: _kind,
              options: [
                _Seg('deduction', 'bulk_kind_deduction'.tr, colors.error),
                _Seg('bonus', 'bulk_kind_bonus'.tr, colors.success),
              ],
              onChanged: (v) => setState(() => _kind = v),
            ),
            const SizedBox(height: AppSpacing.s4),
            _SectionLabel('bulk_scope_label'.tr),
            _segmented(
              colors: colors,
              value: _scopeType,
              options: [
                _Seg('all', 'bulk_scope_all'.tr, colors.brand),
                _Seg('branch', 'bulk_scope_branch'.tr, colors.brand),
                _Seg('category', 'bulk_scope_category'.tr, colors.brand),
                _Seg('employee', 'bulk_scope_employee'.tr, colors.brand),
              ],
              onChanged: (v) => setState(() {
                _scopeType = v;
                _scopeId = null;
                _scopeName = null;
              }),
            ),
            if (_needsTarget) ...[
              const SizedBox(height: AppSpacing.s3),
              if (_ctrl.loadingOptions)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.s3),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                )
              else if (_scopeType == 'employee')
                _employeePicker(colors)
              else
                _targetDropdown(colors),
            ],
            const SizedBox(height: AppSpacing.s4),
            _SectionLabel('bulk_month_label'.tr),
            _monthPicker(colors),
            const SizedBox(height: AppSpacing.s4),
            _SectionLabel('bulk_value_label'.tr),
            _segmented(
              colors: colors,
              value: _amountType,
              options: [
                _Seg('fixed', 'bulk_type_fixed'.tr, colors.brand),
                _Seg('percent', 'bulk_type_percent'.tr, colors.brand),
              ],
              onChanged: (v) => setState(() => _amountType = v),
            ),
            const SizedBox(height: AppSpacing.s3),
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
          ],
        ),
      ),
    );
  }

  Widget _targetDropdown(AppColorScheme colors) {
    final options = _targetOptions;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          hint: Text('bulk_select_target'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textTertiary,
              )),
          value: _scopeId,
          items: options
              .map((o) => DropdownMenuItem<int>(
                    value: o.id,
                    child: Text(o.name,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                        )),
                  ))
              .toList(),
          onChanged: (v) => setState(() {
            _scopeId = v;
            _scopeName =
                options.firstWhereOrNull((o) => o.id == v)?.name;
          }),
        ),
      ),
    );
  }

  Widget _monthPicker(AppColorScheme colors) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: _submitting
          ? null
          : () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _month,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 1, 12),
                helpText: 'bulk_month_label'.tr,
              );
              if (picked != null) {
                setState(() => _month = DateTime(picked.year, picked.month));
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: colors.brand),
            const SizedBox(width: AppSpacing.s2),
            Text(
              _monthStr,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tappable field for the 'employee' scope that opens a searchable picker.
  Widget _employeePicker(AppColorScheme colors) {
    final selected = _scopeId != null;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: _submitting ? null : _pickEmployee,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(Icons.person_search_outlined,
                size: 18, color: colors.brand),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                selected ? (_scopeName ?? '') : 'bulk_select_target'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: selected ? colors.textPrimary : colors.textTertiary,
                ),
              ),
            ),
            Icon(Icons.expand_more, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEmployee() async {
    final all = _ctrl.employees;
    final picked = await Get.bottomSheet<ScopeOption>(
      _EmployeeSearchSheet(employees: all),
      isScrollControlled: true,
    );
    if (picked != null) {
      setState(() {
        _scopeId = picked.id;
        _scopeName = picked.name;
      });
    }
  }

  Widget _segmented({
    required AppColorScheme colors,
    required String value,
    required List<_Seg> options,
    required void Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: options.map((o) {
          final active = value == o.value;
          return Expanded(
            child: GestureDetector(
              onTap: _submitting ? null : () => onChanged(o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                decoration: BoxDecoration(
                  color: active ? o.activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  o.label,
                  textAlign: TextAlign.center,
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
        }).toList(),
      ),
    );
  }
}

class _Seg {
  final String value;
  final String label;
  final Color activeColor;
  const _Seg(this.value, this.label, this.activeColor);
}

/// Bottom sheet that lets the admin search and pick one employee.
class _EmployeeSearchSheet extends StatefulWidget {
  final List<ScopeOption> employees;
  const _EmployeeSearchSheet({required this.employees});

  @override
  State<_EmployeeSearchSheet> createState() => _EmployeeSearchSheetState();
}

class _EmployeeSearchSheetState extends State<_EmployeeSearchSheet> {
  final _searchCtl = TextEditingController();
  late List<ScopeOption> _filtered = widget.employees;

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? widget.employees
          : widget.employees
              .where((e) => e.name.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.s2),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: TextField(
                controller: _searchCtl,
                autofocus: true,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'search'.tr,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Flexible(
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.s5),
                      child: Text('no_results'.tr,
                          style: AppTextStyles.bodySecondary(context)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final e = _filtered[i];
                        return ListTile(
                          title: Text(e.name,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                              )),
                          onTap: () => Get.back<ScopeOption>(result: e),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Text(text,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          )),
    );
  }
}
