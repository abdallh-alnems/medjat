import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../core/shared/input_fields/primary_input.dart';
import '../../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../../data/model/employee_model.dart';
import '../../../../logic/controller/break/break_controller.dart';

Future<void> showAddBreakSheet(BreakController controller) {
  return Get.bottomSheet<void>(
    AddBreakSheet(controller: controller),
    isScrollControlled: true,
  );
}

class AddBreakSheet extends StatefulWidget {
  final BreakController controller;

  const AddBreakSheet({super.key, required this.controller});

  @override
  State<AddBreakSheet> createState() => _AddBreakSheetState();
}

class _AddBreakSheetState extends State<AddBreakSheet> {
  final TextEditingController _typeCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _startTimeCtrl = TextEditingController();
  final TextEditingController _endTimeCtrl = TextEditingController();

  bool _deductFromSalary = false;
  bool _submitting = false;

  bool _loadingEmployees = true;
  String? _employeesError;
  List<EmployeeModel> _employees = [];
  EmployeeModel? _employee;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _reasonCtrl.dispose();
    _dateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _employeesError = null;
    });
    try {
      final response =
          await Get.find<EmployeeData>().getEmployees(status: 'active');
      final list = _parseEmployees(response['data']);
      if (!mounted) return;
      setState(() {
        _employees = list;
        _loadingEmployees = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _employeesError = 'break_created_failed'.tr;
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

  Future<void> _pickEmployee() async {
    final selected = await Get.bottomSheet<EmployeeModel>(
      _EmployeePicker(employees: _employees),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
    if (selected != null) setState(() => _employee = selected);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      _dateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime(TextEditingController ctrl, String hint) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (_employee == null) {
      Get.snackbar('error'.tr, 'select_employee'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_dateCtrl.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'break_select_date'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_startTimeCtrl.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'break_select_start_time'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_endTimeCtrl.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'break_select_end_time'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _submitting = true);
    final ok = await widget.controller.createBreak(
      employeeId: _employee!.id,
      date: _dateCtrl.text.trim(),
      startTime: _startTimeCtrl.text.trim(),
      endTime: _endTimeCtrl.text.trim(),
      type: _typeCtrl.text.trim(),
      reason: _reasonCtrl.text.trim(),
      deductFromSalary: _deductFromSalary,
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
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                    PrimaryInput(
                      label: 'break_type'.tr,
                      controller: _typeCtrl,
                      hint: 'break_type_hint'.tr,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _sectionLabel('break_date'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    _buildDateField(colors),
                    const SizedBox(height: AppSpacing.s4),
                    _sectionLabel('break_time'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeField(colors, _startTimeCtrl, 'break_start_time'.tr),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: _buildTimeField(colors, _endTimeCtrl, 'break_end_time'.tr),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    PrimaryInput(
                      label: 'break_reason'.tr,
                      controller: _reasonCtrl,
                      hint: 'break_reason'.tr,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    _buildDeductToggle(colors),
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
                    Text('request_break'.tr, style: AppTextStyles.h3(context)),
                    const SizedBox(height: 2),
                    Text('request_break_subtitle'.tr,
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

  Widget _buildDeductToggle(AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s1,
      ),
      decoration: _fieldDecoration(colors),
      child: Row(
        children: [
          Icon(Icons.money_off, size: 20, color: colors.brand),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('break_deduct_hourly'.tr,
                    style: AppTextStyles.body(context)),
                Text('break_deduct_hourly_hint'.tr,
                    style: AppTextStyles.sm(context)
                        .copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          Switch(
            value: _deductFromSalary,
            activeThumbColor: colors.brand,
            onChanged: (v) => setState(() => _deductFromSalary = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(AppColorScheme colors) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: _fieldDecoration(colors),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 20, color: colors.brand),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                _dateCtrl.text.trim().isEmpty
                    ? 'break_select_date'.tr
                    : _dateCtrl.text,
                style: _dateCtrl.text.trim().isEmpty
                    ? AppTextStyles.body(context)
                        .copyWith(color: colors.textTertiary)
                    : const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
      AppColorScheme colors, TextEditingController ctrl, String hint) {
    return InkWell(
      onTap: () => _pickTime(ctrl, hint),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: _fieldDecoration(colors),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: colors.brand),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                ctrl.text.trim().isEmpty ? hint.tr : ctrl.text,
                style: ctrl.text.trim().isEmpty
                    ? AppTextStyles.body(context)
                        .copyWith(color: colors.textTertiary)
                    : const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ],
        ),
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
                  style:
                      AppTextStyles.sm(context).copyWith(color: colors.error)),
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
                            style: AppTextStyles.body(context)
                                .copyWith(fontWeight: FontWeight.w600)),
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
                                      style: AppTextStyles.body(context)
                                          .copyWith(fontWeight: FontWeight.w600)),
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
