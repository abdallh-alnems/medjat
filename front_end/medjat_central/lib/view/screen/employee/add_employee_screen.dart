import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/employee/add_employee_controller.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/employee_category_model.dart';

class AddEmployeeScreen extends StatelessWidget {
  const AddEmployeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AddEmployeeController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('add_employee'.tr)),
      body: Obx(() {
        if (ctrl.status.value == StatusRequest.success &&
            ctrl.activationCode != null) {
          return _ActivationCodeView(ctrl: ctrl);
        }
        return GetBuilder<AddEmployeeController>(
          builder: (_) {
            if (ctrl.branchesLoading) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            if (ctrl.branches.isEmpty) {
              return _NoBranchesView(colors: colors);
            }
            return _AddEmployeeForm(ctrl: ctrl);
          },
        );
      }),
    );
  }
}

class _AddEmployeeForm extends StatefulWidget {
  final AddEmployeeController ctrl;
  const _AddEmployeeForm({required this.ctrl});

  @override
  State<_AddEmployeeForm> createState() => _AddEmployeeFormState();
}

class _AddEmployeeFormState extends State<_AddEmployeeForm> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final jobTitleCtrl = TextEditingController();
  final salaryCtrl = TextEditingController();
  final bankNameCtrl = TextEditingController();
  final bankAccountCtrl = TextEditingController();
  final bankIbanCtrl = TextEditingController();
  final bankSwiftCtrl = TextEditingController();
  final annualLeaveCtrl = TextEditingController();
  // Compliance / legal credentials
  final nationalIdCtrl = TextEditingController();
  final nationalityCtrl = TextEditingController();
  final iqamaNumberCtrl = TextEditingController();
  final passportNumberCtrl = TextEditingController();
  final workPermitNumberCtrl = TextEditingController();
  DateTime? iqamaExpiry;
  DateTime? passportExpiry;
  DateTime? workPermitExpiry;
  DateTime? contractStart;
  DateTime? contractEnd;
  DateTime? healthInsuranceExpiry;
  String? contractType;
  static const _contractTypes = [
    'permanent',
    'fixed_term',
    'part_time',
    'temporary',
  ];
  final formKey = GlobalKey<FormState>();

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  AddEmployeeController get ctrl => widget.ctrl;

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    jobTitleCtrl.dispose();
    salaryCtrl.dispose();
    bankNameCtrl.dispose();
    bankAccountCtrl.dispose();
    bankIbanCtrl.dispose();
    bankSwiftCtrl.dispose();
    annualLeaveCtrl.dispose();
    nationalIdCtrl.dispose();
    nationalityCtrl.dispose();
    iqamaNumberCtrl.dispose();
    passportNumberCtrl.dispose();
    workPermitNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('basic_info'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s4),
            PrimaryInput(
              label: 'full_name'.tr,
              controller: nameCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'name_required'.tr : null,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'phone_number'.tr,
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'phone_required'.tr : null,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'job_title'.tr,
              controller: jobTitleCtrl,
              hint: 'job_title'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'base_salary'.tr,
              controller: salaryCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              hint: '0',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'salary_required'.tr : null,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('bank_info'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'bank_name'.tr,
              controller: bankNameCtrl,
              hint: 'bank_name'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'bank_account_number'.tr,
              controller: bankAccountCtrl,
              keyboardType: TextInputType.text,
              hint: 'bank_account_number'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'bank_iban'.tr,
              controller: bankIbanCtrl,
              keyboardType: TextInputType.text,
              hint: 'bank_iban'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'bank_swift'.tr,
              controller: bankSwiftCtrl,
              keyboardType: TextInputType.text,
              hint: 'bank_swift'.tr,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('compliance_info'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'national_id'.tr,
              controller: nationalIdCtrl,
              hint: 'optional'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'nationality'.tr,
              controller: nationalityCtrl,
              hint: 'optional'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'iqama_number'.tr,
              controller: iqamaNumberCtrl,
              hint: 'optional'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            _DateFieldTile(
              label: 'iqama_expiry'.tr,
              date: iqamaExpiry,
              onTap: () => _pickDate(iqamaExpiry, (d) => iqamaExpiry = d),
              onClear: () => setState(() => iqamaExpiry = null),
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'passport_number'.tr,
              controller: passportNumberCtrl,
              hint: 'optional'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            _DateFieldTile(
              label: 'passport_expiry'.tr,
              date: passportExpiry,
              onTap: () => _pickDate(passportExpiry, (d) => passportExpiry = d),
              onClear: () => setState(() => passportExpiry = null),
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'work_permit_number'.tr,
              controller: workPermitNumberCtrl,
              hint: 'optional'.tr,
            ),
            const SizedBox(height: AppSpacing.s3),
            _DateFieldTile(
              label: 'work_permit_expiry'.tr,
              date: workPermitExpiry,
              onTap: () =>
                  _pickDate(workPermitExpiry, (d) => workPermitExpiry = d),
              onClear: () => setState(() => workPermitExpiry = null),
            ),
            const SizedBox(height: AppSpacing.s3),
            _ContractTypeDropdown(
              value: contractType,
              types: _contractTypes,
              onChanged: (v) => setState(() => contractType = v),
            ),
            const SizedBox(height: AppSpacing.s3),
            _DateFieldTile(
              label: 'contract_start'.tr,
              date: contractStart,
              onTap: () => _pickDate(contractStart, (d) => contractStart = d),
              onClear: () => setState(() => contractStart = null),
            ),
            const SizedBox(height: AppSpacing.s3),
            _DateFieldTile(
              label: 'contract_end'.tr,
              date: contractEnd,
              onTap: () => _pickDate(contractEnd, (d) => contractEnd = d),
              onClear: () => setState(() => contractEnd = null),
            ),
            const SizedBox(height: AppSpacing.s3),
            _DateFieldTile(
              label: 'health_insurance_expiry'.tr,
              date: healthInsuranceExpiry,
              onTap: () => _pickDate(
                  healthInsuranceExpiry, (d) => healthInsuranceExpiry = d),
              onClear: () => setState(() => healthInsuranceExpiry = null),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('branch'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s3),
            GetBuilder<AddEmployeeController>(
              builder: (_) {
                return _BranchSelector(
                  branches: ctrl.branches,
                  selectedId: ctrl.selectedBranchId,
                  onSelect: (id) {
                    ctrl.selectedBranchId = id;
                    ctrl.update();
                  },
                );
              },
            ),
            if (ctrl.categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s4),
              Text('employee_categories'.tr, style: AppTextStyles.h3(context)),
              const SizedBox(height: AppSpacing.s3),
              GetBuilder<AddEmployeeController>(
                builder: (_) {
                  return _CategoryChips(
                    categories: ctrl.categories,
                    selectedIds: ctrl.selectedCategoryIds,
                    onToggle: (id) {
                      if (ctrl.selectedCategoryIds.contains(id)) {
                        ctrl.selectedCategoryIds.remove(id);
                      } else {
                        ctrl.selectedCategoryIds.add(id);
                      }
                      ctrl.update();
                    },
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            GetBuilder<AddEmployeeController>(
              builder: (_) {
                final hasShifts = ctrl.shifts.isNotEmpty;
                final usingShift =
                    hasShifts && ctrl.selectedShiftId != null;
                return Text(
                  hasShifts ? 'shift'.tr : 'employee_schedule'.tr,
                  style: AppTextStyles.h3(context),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            GetBuilder<AddEmployeeController>(
              builder: (_) {
                final colors = AppColors.of(context);
                if (ctrl.shifts.isEmpty) return const SizedBox.shrink();
                final usingShift = ctrl.selectedShiftId != null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: ctrl.selectedShiftId,
                          hint: Text('select_shift'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                                color: colors.textSecondary,
                              )),
                          isExpanded: true,
                          icon: Icon(Icons.expand_more,
                              color: colors.textTertiary),
                          items: ctrl.shifts
                              .map((s) => DropdownMenuItem<int?>(
                                    value: s.id,
                                    child: Text(
                                      '${s.name} (${s.startTime.substring(0, 5)} - ${s.endTime.substring(0, 5)})',
                                      style: const TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            ctrl.selectedShiftId = v;
                            ctrl.update();
                          },
                        ),
                      ),
                    ),
                    if (usingShift) ...[
                      const SizedBox(height: AppSpacing.s2),
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: colors.textTertiary),
                          const SizedBox(width: AppSpacing.s1),
                          Expanded(
                            child: Text(
                              'shift_hint'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s3),
                      TextButton.icon(
                        onPressed: () {
                          ctrl.selectedShiftId = null;
                          ctrl.update();
                        },
                        icon: const Icon(Icons.schedule_outlined, size: 18),
                        label: Text('use_custom_hours'.tr),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s3),
                  ],
                );
              },
            ),
            GetBuilder<AddEmployeeController>(
              builder: (_) {
                final usingShift =
                    ctrl.shifts.isNotEmpty && ctrl.selectedShiftId != null;
                if (usingShift) return const SizedBox.shrink();
                return Column(
                  children: [
                    _TimePickerTile(
                      label: 'work_start_time'.tr,
                      time: ctrl.startTime,
                      onTap: () async {
                        final t = await showTimePicker(
                          context: Get.context!,
                          initialTime: ctrl.startTime,
                        );
                        if (t != null) ctrl.setStartTime(t);
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    _TimePickerTile(
                      label: 'work_end_time'.tr,
                      time: ctrl.endTime,
                      onTap: () async {
                        final t = await showTimePicker(
                          context: Get.context!,
                          initialTime: ctrl.endTime,
                        );
                        if (t != null) ctrl.setEndTime(t);
                      },
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('leave_settings_title'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'employee_annual_leave_label'.tr,
              controller: annualLeaveCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              hint: 'employee_annual_leave_hint'.tr,
            ),
            const SizedBox(height: AppSpacing.s6),
            Obx(() => PrimaryButton(
                  text: 'add_employee_btn'.tr,
                  isLoading: ctrl.status.value == StatusRequest.loading,
                  onPressed: _submit,
                )),
            const SizedBox(height: AppSpacing.s5),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    if (ctrl.selectedBranchId == null) {
      Get.snackbar('error'.tr, 'please_select_branch'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final usingShift =
        ctrl.shifts.isNotEmpty && ctrl.selectedShiftId != null;

    ctrl.createEmployee({
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'job_title': jobTitleCtrl.text.trim(),
      'base_salary': int.tryParse(salaryCtrl.text.trim()) ?? 0,
      'branch_id': ctrl.selectedBranchId,
      if (ctrl.selectedCategoryIds.isNotEmpty)
        'category_ids': ctrl.selectedCategoryIds.toList(),
      if (usingShift)
        'shift_id': ctrl.selectedShiftId
      else ...{
        'work_start_time': ctrl.workStartTimeStr,
        'work_end_time': ctrl.workEndTimeStr,
      },
      if (bankNameCtrl.text.trim().isNotEmpty)
        'bank_name': bankNameCtrl.text.trim(),
      if (bankAccountCtrl.text.trim().isNotEmpty)
        'bank_account_number': bankAccountCtrl.text.trim(),
      if (bankIbanCtrl.text.trim().isNotEmpty)
        'bank_iban': bankIbanCtrl.text.trim(),
      if (bankSwiftCtrl.text.trim().isNotEmpty)
        'bank_swift': bankSwiftCtrl.text.trim(),
      if (annualLeaveCtrl.text.trim().isNotEmpty)
        'annual_leave_days': int.tryParse(annualLeaveCtrl.text.trim()),
      if (nationalIdCtrl.text.trim().isNotEmpty)
        'national_id': nationalIdCtrl.text.trim(),
      if (nationalityCtrl.text.trim().isNotEmpty)
        'nationality': nationalityCtrl.text.trim(),
      if (iqamaNumberCtrl.text.trim().isNotEmpty)
        'iqama_number': iqamaNumberCtrl.text.trim(),
      if (iqamaExpiry != null) 'iqama_expiry': _fmtDate(iqamaExpiry!),
      if (passportNumberCtrl.text.trim().isNotEmpty)
        'passport_number': passportNumberCtrl.text.trim(),
      if (passportExpiry != null) 'passport_expiry': _fmtDate(passportExpiry!),
      if (workPermitNumberCtrl.text.trim().isNotEmpty)
        'work_permit_number': workPermitNumberCtrl.text.trim(),
      if (workPermitExpiry != null)
        'work_permit_expiry': _fmtDate(workPermitExpiry!),
      if (contractType != null) 'contract_type': contractType,
      if (contractStart != null) 'contract_start': _fmtDate(contractStart!),
      if (contractEnd != null) 'contract_end': _fmtDate(contractEnd!),
      if (healthInsuranceExpiry != null)
        'health_insurance_expiry': _fmtDate(healthInsuranceExpiry!),
    });
  }
}

class _ActivationCodeView extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _ActivationCodeView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(Icons.check_circle_outline,
                size: 36, color: colors.success),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('employee_added_success'.tr, style: AppTextStyles.h2(context)),
          const SizedBox(height: AppSpacing.s6),
          Text('activation_code'.tr, style: AppTextStyles.bodySecondary(context)),
          const SizedBox(height: AppSpacing.s3),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.brand, width: 2),
            ),
            child: Text(
              ctrl.activationCode ?? '',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: colors.brand,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'send_code_hint'.tr,
            style: AppTextStyles.sm(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: ctrl.activationCode ?? ''));
              Get.snackbar('done'.tr, 'code_copied'.tr,
                  snackPosition: SnackPosition.BOTTOM);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: Text('copy_code'.tr),
          ),
          const SizedBox(height: AppSpacing.s5),
          PrimaryButton(
            text: 'done'.tr,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
  }
}

class _DateFieldTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateFieldTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasDate = date != null;
    final text = hasDate
        ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
        : 'select_date'.tr;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 20, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: hasDate ? colors.brand : colors.textTertiary,
              ),
            ),
            if (hasDate)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close, size: 18, color: colors.textTertiary),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }
}

class _ContractTypeDropdown extends StatelessWidget {
  final String? value;
  final List<String> types;
  final ValueChanged<String?> onChanged;

  const _ContractTypeDropdown({
    required this.value,
    required this.types,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: Text(
            'contract_type'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(hintText: 'optional'.tr),
          items: types
              .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text('contract_$t'.tr),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBranchesView extends StatelessWidget {
  final AppColorScheme colors;
  const _NoBranchesView({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'add_branch_first'.tr,
              style: AppTextStyles.h3(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'add_branch_first_hint'.tr,
              style: AppTextStyles.bodySecondary(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Get.toNamed<dynamic>(AppRoutes.branchManage);
                  if (result == true) {
                    Get.find<AddEmployeeController>().loadBranches();
                  }
                },
                icon: const Icon(Icons.add_business),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                  child: Text('add_branch'.tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<EmployeeCategoryModel> categories;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;

  const _CategoryChips({
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: categories.map((cat) {
        final selected = selectedIds.contains(cat.id);
        return FilterChip(
          label: Text(
            cat.name,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.brand : colors.textPrimary,
            ),
          ),
          selected: selected,
          onSelected: (_) => onToggle(cat.id),
          selectedColor: colors.brandSubtle,
          checkmarkColor: colors.brand,
          side: BorderSide(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        );
      }).toList(),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final List<BranchModel> branches;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const _BranchSelector({
    required this.branches,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (branches.isEmpty) {
      return Text('no_branches_available'.tr, style: AppTextStyles.sm(context));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedId,
          hint: Text(
            'please_select_branch'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          items: branches.map((b) {
            return DropdownMenuItem<int>(
              value: b.id,
              child: Text(
                b.name,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: onSelect,
        ),
      ),
    );
  }
}
