import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../core/shared/input_fields/primary_input.dart';
import '../../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../../data/model/employee_model.dart';
import '../../../../logic/controller/leave/leave_controller.dart';

/// Opens the rebuilt "add leave" sheet for a single employee.
///
/// Flow: pick employee → pick leave type → pick a start/end date range →
/// (optional) reason, auto-approve, and over-balance handling → save.
Future<void> showAddLeaveSheet(LeaveController controller) {
  return Get.bottomSheet<void>(
    AddLeaveSheet(controller: controller),
    isScrollControlled: true,
  );
}

/// Leave types selectable from the sheet, each paired with its label and a
/// short description shown when selected.
const List<(String, String, String)> _leaveTypes = [
  ('annual', 'leave_type_annual', 'leave_type_annual_desc'),
  ('sick', 'leave_type_sick', 'leave_type_sick_desc'),
  ('personal', 'leave_type_personal', 'leave_type_personal_desc'),
  ('unpaid', 'leave_type_unpaid', 'leave_type_unpaid_desc'),
];

class AddLeaveSheet extends StatefulWidget {
  final LeaveController controller;

  const AddLeaveSheet({super.key, required this.controller});

  @override
  State<AddLeaveSheet> createState() => _AddLeaveSheetState();
}

class _AddLeaveSheetState extends State<AddLeaveSheet> {
  final TextEditingController _reasonCtrl = TextEditingController();

  bool _loadingEmployees = true;
  String? _employeesError;
  List<EmployeeModel> _employees = [];

  EmployeeModel? _employee;
  String _type = 'annual';
  DateTimeRange? _range;
  String _onExceed = 'split';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final response = await Get.find<EmployeeData>().getEmployees();
      final list = _parseEmployees(response['data']);
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loadingEmployees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _employeesError = 'leave_created_failed'.tr;
        _loadingEmployees = false;
      });
    }
  }

  List<EmployeeModel> _parseEmployees(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    return items
            ?.whereType<Map<String, dynamic>>()
            .map(EmployeeModel.fromJson)
            .toList() ??
        [];
  }

  int get _requestedDays =>
      _range == null ? 0 : _range!.duration.inDays + 1;

  int get _remainingBalance =>
      (widget.controller.balanceInfo?['remaining_days'] as num?)?.toInt() ?? 0;

  bool get _exceedsBalance =>
      _type == 'annual' &&
      widget.controller.balanceInfo != null &&
      _range != null &&
      _requestedDays > _remainingBalance;

  void _onEmployeePicked(EmployeeModel employee) {
    setState(() => _employee = employee);
    _maybeLoadBalance();
  }

  void _onTypePicked(String type) {
    setState(() => _type = type);
    _maybeLoadBalance();
  }

  void _maybeLoadBalance() {
    if (_type == 'annual' && _employee != null) {
      widget.controller.loadBalance(_employee!.id);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'leave_period'.tr,
      saveText: 'save'.tr,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _pickEmployee() async {
    final selected = await Get.bottomSheet<EmployeeModel>(
      _EmployeePicker(employees: _employees),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    if (selected != null) _onEmployeePicked(selected);
  }

  Future<void> _submit() async {
    if (_employee == null) {
      Get.snackbar('error'.tr, 'select_employee'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_range == null) {
      Get.snackbar('error'.tr, 'select_start_date'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _submitting = true);
    final ok = await widget.controller.createLeave(
      employeeId: _employee!.id,
      type: _type,
      startDate: _range!.start,
      endDate: _range!.end,
      reason: _reasonCtrl.text,
      // The manager creating the leave is granting it, so it is approved at once.
      autoApprove: true,
      onExceed: _onExceed,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(colors),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s2,
                  AppSpacing.s4,
                  AppSpacing.s4 + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('leave_employee_section'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    _buildEmployeeField(colors),
                    const SizedBox(height: AppSpacing.s4),
                    _sectionLabel('leave_type'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    _buildTypePicker(colors),
                    const SizedBox(height: AppSpacing.s4),
                    _sectionLabel('leave_period'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    _buildPeriodField(colors),
                    _buildBalanceArea(colors),
                    const SizedBox(height: AppSpacing.s4),
                    PrimaryInput(
                      label: 'leave_reason'.tr,
                      controller: _reasonCtrl,
                      hint: 'leave_reason'.tr,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    PrimaryButton(
                      text: 'save'.tr,
                      isLoading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, AppSpacing.s3, AppSpacing.s2, AppSpacing.s2),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderStrong,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('add_leave'.tr, style: AppTextStyles.h3(context)),
                    const SizedBox(height: 2),
                    Text('add_leave_subtitle'.tr,
                        style: AppTextStyles.sm(context)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Get.back<void>(),
                icon: Icon(Icons.close, color: colors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeField(AppColorScheme colors) {
    if (_loadingEmployees) {
      return Container(
        height: 58,
        alignment: Alignment.center,
        decoration: _fieldDecoration(colors),
        child: const CircularProgressIndicator.adaptive(),
      );
    }
    if (_employeesError != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: _fieldDecoration(colors),
        child: Row(
          children: [
            Expanded(
              child: Text(_employeesError!,
                  style: AppTextStyles.sm(context)
                      .copyWith(color: colors.error)),
            ),
            TextButton(onPressed: _loadEmployees, child: Text('retry'.tr)),
          ],
        ),
      );
    }

    final employee = _employee;
    return InkWell(
      onTap: _pickEmployee,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s3),
        decoration: _fieldDecoration(colors),
        child: Row(
          children: [
            _Avatar(name: employee?.name, colors: colors),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: employee == null
                  ? Text('select_employee'.tr,
                      style: AppTextStyles.body(context)
                          .copyWith(color: colors.textTertiary))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(employee.name,
                            style: AppTextStyles.body(context).copyWith(
                                fontWeight: FontWeight.w600)),
                        if (employee.jobTitle != null &&
                            employee.jobTitle!.isNotEmpty)
                          Text(employee.jobTitle!,
                              style: AppTextStyles.sm(context)),
                      ],
                    ),
            ),
            Icon(Icons.unfold_more, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildTypePicker(AppColorScheme colors) {
    final desc = _leaveTypes.firstWhere((t) => t.$1 == _type).$3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: _leaveTypes
              .map((t) => _ChoiceChip(
                    label: t.$2.tr,
                    selected: _type == t.$1,
                    onTap: () => _onTypePicked(t.$1),
                    colors: colors,
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.s2),
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: colors.textTertiary),
            const SizedBox(width: AppSpacing.s1),
            Expanded(child: Text(desc.tr, style: AppTextStyles.sm(context))),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodField(AppColorScheme colors) {
    final range = _range;
    return InkWell(
      onTap: _pickRange,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: _fieldDecoration(colors),
        child: range == null
            ? Row(
                children: [
                  Icon(Icons.event_outlined, size: 20, color: colors.brand),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Text('leave_period_hint'.tr,
                        style: AppTextStyles.body(context)
                            .copyWith(color: colors.textTertiary)),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _DateColumn(
                      label: 'leave_from'.tr,
                      date: range.start,
                      colors: colors,
                    ),
                  ),
                  Icon(Icons.arrow_back, size: 16, color: colors.textTertiary),
                  Expanded(
                    child: _DateColumn(
                      label: 'leave_to'.tr,
                      date: range.end,
                      colors: colors,
                      alignEnd: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                    decoration: BoxDecoration(
                      color: colors.brandSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      _requestedDays == 1
                          ? 'leave_one_day'.tr
                          : 'leave_days_count'
                              .trParams({'count': '$_requestedDays'}),
                      style: AppTextStyles.sm(context).copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBalanceArea(AppColorScheme colors) {
    if (_type != 'annual' || _employee == null) {
      return const SizedBox.shrink();
    }
    return GetBuilder<LeaveController>(
      builder: (ctrl) {
        if (ctrl.balanceLoading) {
          return const Padding(
            padding: EdgeInsets.only(top: AppSpacing.s3),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          );
        }
        final info = ctrl.balanceInfo;
        if (info == null) return const SizedBox.shrink();

        final remaining = (info['remaining_days'] as num?)?.toInt() ?? 0;
        final used = (info['used_days'] as num?)?.toInt() ?? 0;
        final total =
            (info['total_days'] as num?)?.toInt() ?? (used + remaining);

        return Column(
          children: [
            const SizedBox(height: AppSpacing.s3),
            _InfoBanner(
              icon: remaining > 0
                  ? Icons.account_balance_wallet_outlined
                  : Icons.warning_amber_rounded,
              color: remaining > 0 ? colors.brand : colors.error,
              text: 'leave_balance_summary'.trParams({
                'remaining': '$remaining',
                'used': '$used',
                'total': '$total',
              }),
              colors: colors,
            ),
            if (_exceedsBalance) ...[
              const SizedBox(height: AppSpacing.s3),
              _buildOnExceed(colors, remaining),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOnExceed(AppColorScheme colors, int remaining) {
    final paid = remaining;
    final unpaid = _requestedDays - remaining;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 18, color: colors.warning),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  'leave_balance_warning'
                      .trParams({'paid': '$paid', 'unpaid': '$unpaid'}),
                  style: AppTextStyles.sm(context).copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Text('leave_on_exceed_title'.tr,
              style: AppTextStyles.sm(context)
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.s2),
          _OnExceedOption(
            selected: _onExceed == 'split',
            title: 'leave_on_exceed_split'.tr,
            subtitle: 'leave_on_exceed_split_hint'.tr,
            onTap: () => setState(() => _onExceed = 'split'),
            colors: colors,
          ),
          const SizedBox(height: AppSpacing.s2),
          _OnExceedOption(
            selected: _onExceed == 'block',
            title: 'leave_on_exceed_block'.tr,
            subtitle: 'leave_on_exceed_block_hint'.tr,
            onTap: () => setState(() => _onExceed = 'block'),
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, AppColorScheme colors) {
    return Text(text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ));
  }

  BoxDecoration _fieldDecoration(AppColorScheme colors) => BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.borderHairline),
      );
}

class _DateColumn extends StatelessWidget {
  final String label;
  final DateTime date;
  final AppColorScheme colors;
  final bool alignEnd;

  const _DateColumn({
    required this.label,
    required this.date,
    required this.colors,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.xs(context)),
        const SizedBox(height: 2),
        Text(formatted,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final AppColorScheme colors;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(text,
                style: AppTextStyles.sm(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }
}

class _OnExceedOption extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _OnExceedOption({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s2),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? colors.brand : colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTextStyles.sm(context)
                          .copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppTextStyles.xs(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? name;
  final AppColorScheme colors;

  const _Avatar({required this.name, required this.colors});

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim().characters.first
        : '?';
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: colors.brand,
        ),
      ),
    );
  }
}

/// Searchable employee selector shown as a nested bottom sheet.
class _EmployeePicker extends StatefulWidget {
  final List<EmployeeModel> employees;

  const _EmployeePicker({required this.employees});

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.employees
        : widget.employees
            .where((e) =>
                e.name.toLowerCase().contains(q) ||
                (e.employeeCode?.toLowerCase().contains(q) ?? false) ||
                (e.jobTitle?.toLowerCase().contains(q) ?? false))
            .toList();

    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    // Space available above the keyboard (and system insets), minus our margins.
    final available = mq.size.height -
        viewInsets -
        mq.padding.top -
        mq.padding.bottom -
        AppSpacing.s4 * 2;
    final cap = mq.size.height * 0.7;
    final sheetHeight = available < cap ? available : cap;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        // Lift the card to sit directly on top of the keyboard.
        padding: EdgeInsets.only(bottom: viewInsets),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Material(
              color: colors.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: sheetHeight,
                child: Column(
                  children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'leave_search_employee'.tr,
                  hintStyle: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    color: colors.textTertiary,
                  ),
                  filled: true,
                  fillColor: colors.sunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.s5),
                      child: Text('leave_no_employees_found'.tr,
                          style: AppTextStyles.bodySecondary(context)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s1),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _Avatar(name: e.name, colors: colors),
                          title: Text(e.name,
                              style: AppTextStyles.body(context).copyWith(
                                  fontWeight: FontWeight.w600)),
                          subtitle: (e.jobTitle != null &&
                                  e.jobTitle!.isNotEmpty)
                              ? Text(e.jobTitle!,
                                  style: AppTextStyles.sm(context))
                              : null,
                          onTap: () => Get.back<EmployeeModel>(result: e),
                        );
                      },
                    ),
            ),
            ],
          ),
        ),
      ),
          ),
        ),
      ),
    );
  }
}
