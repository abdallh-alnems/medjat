import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/employee/add_employee_controller.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/employee_category_model.dart';

/// Strips non-digits and the national trunk prefix (leading zeros) from a
/// locally-typed number so it can be joined to a country code as E.164.
/// E.g. Egypt "01023809407" + code "20" → "+201023809407" (not "+2001023809407").
String _nationalDigits(String raw) =>
    raw.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');

/// Builds an E.164 number from a country dial code and a locally-typed number.
String _toE164(String phoneCode, String raw) =>
    '+$phoneCode${_nationalDigits(raw)}';

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
  DateTime? hireDate;
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
  static const _daysOfWeek = [
    'saturday',
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];
  bool showBankInfo = false;
  bool showCompliance = false;
  bool showAllowances = false;
  // Recurring monthly allowances added alongside the salary (housing, transport…).
  final List<_AllowanceDraft> allowanceDrafts = [];
  // Per-employee document requests: papers requested from THIS employee only.
  final List<_DocRequestDraft> docRequestDrafts = [];
  final Set<String> weeklyOffDays = {};
  // A fixed weekly off day is optional — when disabled the employee's rest day
  // is variable (e.g. set per rotating schedule) and no fixed day is sent.
  bool enableWeeklyOff = false;
  Country? selectedCountry;
  // Fixed-term (temporary) employment.
  bool isTemporary = false;
  DateTime? tempStart;
  final tempDurationCtrl = TextEditingController();
  String tempUnit = 'weeks';
  static const _durationUnits = ['days', 'weeks', 'months'];
  final formKey = GlobalKey<FormState>();

  /// End date computed from the temporary start + duration, or null if invalid.
  DateTime? get _tempEndDate {
    final start = tempStart ?? _today;
    final n = int.tryParse(tempDurationCtrl.text.trim());
    if (n == null || n <= 0) return null;
    switch (tempUnit) {
      case 'days':
        return start.add(Duration(days: n));
      case 'weeks':
        return start.add(Duration(days: n * 7));
      case 'months':
        return DateTime(start.year, start.month + n, start.day);
      default:
        return null;
    }
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (country) => setState(() => selectedCountry = country),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Localized weekday name for [d] (DateTime.weekday: Mon=1 … Sun=7).
  String _weekdayName(DateTime d) {
    const keys = [
      'day_monday',
      'day_tuesday',
      'day_wednesday',
      'day_thursday',
      'day_friday',
      'day_saturday',
      'day_sunday',
    ];
    return keys[d.weekday - 1].tr;
  }

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool _isPast(DateTime d) => DateTime(d.year, d.month, d.day).isBefore(_today);

  /// Contract end must be strictly after the start date.
  bool get _contractEndInvalid =>
      contractStart != null &&
      contractEnd != null &&
      !contractEnd!.isAfter(contractStart!);

  String? _expiryWarning(DateTime? date) =>
      date != null && _isPast(date) ? 'date_in_past_warning'.tr : null;

  Future<void> _pickDate(
    DateTime? current,
    ValueChanged<DateTime> onPicked,
  ) async {
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
    tempDurationCtrl.dispose();
    nationalIdCtrl.dispose();
    nationalityCtrl.dispose();
    iqamaNumberCtrl.dispose();
    passportNumberCtrl.dispose();
    workPermitNumberCtrl.dispose();
    for (final d in allowanceDrafts) {
      d.dispose();
    }
    for (final d in docRequestDrafts) {
      d.dispose();
    }
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
            _PhoneField(
              controller: phoneCtrl,
              country: selectedCountry,
              onPickCountry: _pickCountry,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'job_title'.tr,
              controller: jobTitleCtrl,
              optional: true,
            ),
            if (ctrl.categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              GetBuilder<AddEmployeeController>(
                builder: (_) {
                  final colors = AppColors.of(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                        child: Text(
                          'employee_categories'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: colors.borderHairline),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: ctrl.selectedCategoryId,
                            hint: Text(
                              'optional'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                                color: colors.textSecondary,
                              ),
                            ),
                            isExpanded: true,
                            // Allow menu items to grow taller than the default
                            // 48px so two-line (name + description) items fit.
                            itemHeight: null,
                            icon: Icon(
                              Icons.expand_more,
                              color: colors.textTertiary,
                            ),
                            // Closed button shows only the name (single line),
                            // while the open menu shows name + description.
                            selectedItemBuilder: (context) => [
                              Text(
                                'select_category'.tr,
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 14,
                                  color: colors.textTertiary,
                                ),
                              ),
                              ...ctrl.categories.map(
                                (cat) => Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    cat.name,
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  'select_category'.tr,
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 14,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ),
                              ...ctrl.categories.map((cat) {
                                final desc = cat.description?.trim() ?? '';
                                return DropdownMenuItem<int?>(
                                  value: cat.id,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cat.name,
                                        style: const TextStyle(
                                          fontFamily: 'IBM Plex Sans Arabic',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (desc.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            desc,
                                            style: TextStyle(
                                              fontFamily:
                                                  'IBM Plex Sans Arabic',
                                              fontSize: 12,
                                              color: colors.textTertiary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (v) {
                              ctrl.selectedCategoryId = v;
                              ctrl.update();
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'base_salary'.tr,
              controller: salaryCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'salary_required'.tr;
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed < 0) return 'salary_required'.tr;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            _DateFieldTile(
              label: 'hire_date'.tr,
              date: hireDate,
              onTap: () => _pickDate(hireDate, (d) => hireDate = d),
              onClear: () => setState(() => hireDate = null),
            ),
            const SizedBox(height: AppSpacing.s4),
            _SectionToggle(
              title: 'weekly_day_off_enable'.tr,
              enabled: enableWeeklyOff,
              onToggle: (v) {
                setState(() {
                  enableWeeklyOff = v;
                  if (!v) weeklyOffDays.clear();
                });
              },
            ),
            if (enableWeeklyOff) ...[
              const SizedBox(height: AppSpacing.s3),
              _WeeklyDayOffSelector(
                selectedDays: weeklyOffDays,
                daysOfWeek: _daysOfWeek,
                onToggle: (day) {
                  setState(() {
                    if (weeklyOffDays.contains(day)) {
                      weeklyOffDays.remove(day);
                    } else {
                      weeklyOffDays.add(day);
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            _SectionToggle(
              title: 'allowances_title'.tr,
              enabled: showAllowances,
              onToggle: (v) => setState(() {
                showAllowances = v;
                // Seed one empty row when the section is first opened.
                if (v && allowanceDrafts.isEmpty) {
                  allowanceDrafts.add(_AllowanceDraft());
                }
              }),
            ),
            if (showAllowances) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                'allowance_add_employee_hint'.tr,
                style: AppTextStyles.sm(context),
              ),
              const SizedBox(height: AppSpacing.s3),
              ...List.generate(allowanceDrafts.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _AllowanceDraftCard(
                    draft: allowanceDrafts[i],
                    onRemove: () => setState(() {
                      allowanceDrafts[i].dispose();
                      allowanceDrafts.removeAt(i);
                    }),
                  ),
                );
              }),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => allowanceDrafts.add(_AllowanceDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('allowance_add'.tr),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            _SectionToggle(
              title: 'bank_info'.tr,
              enabled: showBankInfo,
              onToggle: (v) => setState(() => showBankInfo = v),
            ),
            if (showBankInfo) ...[
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(label: 'bank_name'.tr, controller: bankNameCtrl),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'bank_account_number'.tr,
                controller: bankAccountCtrl,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'bank_iban'.tr,
                controller: bankIbanCtrl,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'bank_swift'.tr,
                controller: bankSwiftCtrl,
                keyboardType: TextInputType.text,
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            _SectionToggle(
              title: 'compliance_info'.tr,
              enabled: showCompliance,
              onToggle: (v) => setState(() => showCompliance = v),
            ),
            if (showCompliance) ...[
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(label: 'national_id'.tr, controller: nationalIdCtrl),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'nationality'.tr,
                controller: nationalityCtrl,
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'iqama_number'.tr,
                controller: iqamaNumberCtrl,
              ),
              const SizedBox(height: AppSpacing.s3),
              _DateFieldTile(
                label: 'iqama_expiry'.tr,
                date: iqamaExpiry,
                warning: _expiryWarning(iqamaExpiry),
                onTap: () => _pickDate(iqamaExpiry, (d) => iqamaExpiry = d),
                onClear: () => setState(() => iqamaExpiry = null),
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'passport_number'.tr,
                controller: passportNumberCtrl,
              ),
              const SizedBox(height: AppSpacing.s3),
              _DateFieldTile(
                label: 'passport_expiry'.tr,
                date: passportExpiry,
                warning: _expiryWarning(passportExpiry),
                onTap: () =>
                    _pickDate(passportExpiry, (d) => passportExpiry = d),
                onClear: () => setState(() => passportExpiry = null),
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'work_permit_number'.tr,
                controller: workPermitNumberCtrl,
              ),
              const SizedBox(height: AppSpacing.s3),
              _DateFieldTile(
                label: 'work_permit_expiry'.tr,
                date: workPermitExpiry,
                warning: _expiryWarning(workPermitExpiry),
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
                warning: _contractEndInvalid
                    ? 'contract_end_before_start'.tr
                    : _expiryWarning(contractEnd),
                warningIsError: _contractEndInvalid,
                onTap: () => _pickDate(contractEnd, (d) => contractEnd = d),
                onClear: () => setState(() => contractEnd = null),
              ),
              const SizedBox(height: AppSpacing.s3),
              _DateFieldTile(
                label: 'health_insurance_expiry'.tr,
                date: healthInsuranceExpiry,
                warning: _expiryWarning(healthInsuranceExpiry),
                onTap: () => _pickDate(
                  healthInsuranceExpiry,
                  (d) => healthInsuranceExpiry = d,
                ),
                onClear: () => setState(() => healthInsuranceExpiry = null),
              ),
              // ── Request specific documents from THIS employee ──────
              const SizedBox(height: AppSpacing.s4),
              Text(
                'requested_documents_title'.tr,
                style: AppTextStyles.bodySecondary(context),
              ),
              const SizedBox(height: AppSpacing.s1),
              Text(
                'requested_documents_hint'.tr,
                style: AppTextStyles.sm(context),
              ),
              const SizedBox(height: AppSpacing.s3),
              ...List.generate(docRequestDrafts.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                  child: _DocRequestCard(
                    draft: docRequestDrafts[i],
                    onRemove: () => setState(() {
                      docRequestDrafts[i].dispose();
                      docRequestDrafts.removeAt(i);
                    }),
                  ),
                );
              }),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => docRequestDrafts.add(_DocRequestDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('requested_documents_add'.tr),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s4),
            _SectionToggle(
              title: 'temporary_employment'.tr,
              enabled: isTemporary,
              onToggle: (v) => setState(() => isTemporary = v),
            ),
            if (isTemporary) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                'temporary_employment_hint'.tr,
                style: AppTextStyles.sm(context),
              ),
              const SizedBox(height: AppSpacing.s3),
              _DateFieldTile(
                label: 'employment_start'.tr,
                date: tempStart ?? _today,
                onTap: () =>
                    _pickDate(tempStart ?? _today, (d) => tempStart = d),
                onClear: () => setState(() => tempStart = null),
              ),
              const SizedBox(height: AppSpacing.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: PrimaryInput(
                      label: 'employment_duration'.tr,
                      controller: tempDurationCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: _DurationUnitDropdown(
                      value: tempUnit,
                      units: _durationUnits,
                      onChanged: (v) =>
                          setState(() => tempUnit = v ?? tempUnit),
                    ),
                  ),
                ],
              ),
              if (_tempEndDate != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 16,
                      color: AppColors.of(context).brand,
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Text(
                      '${'employment_ends_on'.tr}: ${_fmtDate(_tempEndDate!)} — ${_weekdayName(_tempEndDate!)}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.of(context).brand,
                      ),
                    ),
                  ],
                ),
              ],
            ],
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
            const SizedBox(height: AppSpacing.s4),
            GetBuilder<AddEmployeeController>(
              builder: (_) {
                final hasShifts = ctrl.shifts.isNotEmpty;
                final usingShift = hasShifts && ctrl.selectedShiftId != null;
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
                        horizontal: AppSpacing.s3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: ctrl.selectedShiftId,
                          hint: Text(
                            'select_shift'.tr,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                          ),
                          isExpanded: true,
                          icon: Icon(
                            Icons.expand_more,
                            color: colors.textTertiary,
                          ),
                          items: ctrl.shifts
                              .map(
                                (s) => DropdownMenuItem<int?>(
                                  value: s.id,
                                  child: Text(
                                    '${s.name} (${s.startTime.substring(0, 5)} - ${s.endTime.substring(0, 5)})',
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
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
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: colors.textTertiary,
                          ),
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
              optional: true,
            ),
            const SizedBox(height: AppSpacing.s6),
            Obx(
              () => PrimaryButton(
                text: 'add_employee_btn'.tr,
                isLoading: ctrl.status.value == StatusRequest.loading,
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;
    if (ctrl.selectedBranchId == null) {
      Get.snackbar(
        'error'.tr,
        'please_select_branch'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (_contractEndInvalid) {
      Get.snackbar(
        'error'.tr,
        'contract_end_before_start'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (isTemporary && _tempEndDate == null) {
      Get.snackbar(
        'error'.tr,
        'duration_required'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final usingShift = ctrl.shifts.isNotEmpty && ctrl.selectedShiftId != null;

    // Phone is optional. When left blank the employee signs in via the
    // activation link / QR code shown after creation instead of by phone.
    final phoneE164 =
        (phoneCtrl.text.trim().isNotEmpty && selectedCountry != null)
        ? _toE164(selectedCountry!.phoneCode, phoneCtrl.text)
        : null;

    // Collect filled-in allowance rows; the backend defaults each one's start
    // month to the hire month and runs it open-ended.
    final allowancesPayload = <Map<String, dynamic>>[];
    if (showAllowances) {
      for (final d in allowanceDrafts) {
        final type = d.typeCtrl.text.trim();
        final amount = double.tryParse(d.amountCtrl.text.trim());
        if (type.isEmpty || amount == null || amount <= 0) continue;
        allowancesPayload.add({'type': type, 'amount': amount});
      }
    }

    // Per-employee document requests entered in the official-documents section.
    final docRequestsPayload = <Map<String, dynamic>>[];
    if (showCompliance) {
      for (final d in docRequestDrafts) {
        final docName = d.nameCtrl.text.trim();
        if (docName.isEmpty) continue;
        final note = d.noteCtrl.text.trim();
        docRequestsPayload.add({
          'name': docName,
          if (note.isNotEmpty) 'description': note,
        });
      }
    }

    ctrl.createEmployee({
      'name': nameCtrl.text.trim(),
      if (phoneE164 != null) 'phone': phoneE164,
      'job_title': jobTitleCtrl.text.trim(),
      'base_salary': double.tryParse(salaryCtrl.text.trim()) ?? 0,
      if (hireDate != null) 'hire_date': _fmtDate(hireDate!),
      if (isTemporary && _tempEndDate != null)
        'auto_terminate_at': _fmtDate(_tempEndDate!),
      'branch_id': ctrl.selectedBranchId,
      if (ctrl.selectedCategoryId != null)
        'category_ids': [ctrl.selectedCategoryId],
      if (usingShift)
        'shift_id': ctrl.selectedShiftId
      else ...{
        'work_start_time': ctrl.workStartTimeStr,
        'work_end_time': ctrl.workEndTimeStr,
      },
      if (showBankInfo) ...{
        if (bankNameCtrl.text.trim().isNotEmpty)
          'bank_name': bankNameCtrl.text.trim(),
        if (bankAccountCtrl.text.trim().isNotEmpty)
          'bank_account_number': bankAccountCtrl.text.trim(),
        if (bankIbanCtrl.text.trim().isNotEmpty)
          'bank_iban': bankIbanCtrl.text.trim(),
        if (bankSwiftCtrl.text.trim().isNotEmpty)
          'bank_swift': bankSwiftCtrl.text.trim(),
      },
      if (annualLeaveCtrl.text.trim().isNotEmpty)
        'annual_leave_days': int.tryParse(annualLeaveCtrl.text.trim()),
      if (allowancesPayload.isNotEmpty) 'allowances': allowancesPayload,
      if (docRequestsPayload.isNotEmpty)
        'requested_documents': docRequestsPayload,
      if (enableWeeklyOff && weeklyOffDays.isNotEmpty)
        'weekly_off_days': weeklyOffDays.toList(),
      if (showCompliance) ...{
        if (nationalIdCtrl.text.trim().isNotEmpty)
          'national_id': nationalIdCtrl.text.trim(),
        if (nationalityCtrl.text.trim().isNotEmpty)
          'nationality': nationalityCtrl.text.trim(),
        if (iqamaNumberCtrl.text.trim().isNotEmpty)
          'iqama_number': iqamaNumberCtrl.text.trim(),
        if (iqamaExpiry != null) 'iqama_expiry': _fmtDate(iqamaExpiry!),
        if (passportNumberCtrl.text.trim().isNotEmpty)
          'passport_number': passportNumberCtrl.text.trim(),
        if (passportExpiry != null)
          'passport_expiry': _fmtDate(passportExpiry!),
        if (workPermitNumberCtrl.text.trim().isNotEmpty)
          'work_permit_number': workPermitNumberCtrl.text.trim(),
        if (workPermitExpiry != null)
          'work_permit_expiry': _fmtDate(workPermitExpiry!),
        if (contractType != null) 'contract_type': contractType,
        if (contractStart != null) 'contract_start': _fmtDate(contractStart!),
        if (contractEnd != null) 'contract_end': _fmtDate(contractEnd!),
        if (healthInsuranceExpiry != null)
          'health_insurance_expiry': _fmtDate(healthInsuranceExpiry!),
      },
    });
  }
}

class _ActivationCodeView extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _ActivationCodeView({required this.ctrl});

  void _copy(String? value, String toast) {
    if (value == null || value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    Get.snackbar('done'.tr, toast, snackPosition: SnackPosition.BOTTOM);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final joinLink = ctrl.joinLink;
    final phone = ctrl.employeePhone;

    return SingleChildScrollView(
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
            child: Icon(
              Icons.check_circle_outline,
              size: 36,
              color: colors.success,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('employee_added_success'.tr, style: AppTextStyles.h2(context)),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'join_methods_hint'.tr,
            style: AppTextStyles.sm(context),
            textAlign: TextAlign.center,
          ),

          // ── QR code ──────────────────────────────────────────
          if (joinLink != null && joinLink.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s6),
            Text('join_qr'.tr, style: AppTextStyles.bodySecondary(context)),
            const SizedBox(height: AppSpacing.s3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.borderHairline),
              ),
              child: QrImageView(
                data: joinLink,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ],

          // ── Login phone ──────────────────────────────────────
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s5),
            Text('login_phone'.tr, style: AppTextStyles.bodySecondary(context)),
            const SizedBox(height: AppSpacing.s2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s5,
                vertical: AppSpacing.s3,
              ),
              decoration: BoxDecoration(
                color: colors.sunken,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.borderHairline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_iphone, size: 18, color: colors.brand),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Activation code ──────────────────────────────────
          const SizedBox(height: AppSpacing.s5),
          Text(
            'activation_code'.tr,
            style: AppTextStyles.bodySecondary(context),
          ),
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
            'single_use_hint'.tr,
            style: AppTextStyles.sm(context),
            textAlign: TextAlign.center,
          ),

          // ── Copy actions ─────────────────────────────────────
          const SizedBox(height: AppSpacing.s5),
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s3,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _copy(ctrl.activationCode, 'code_copied'.tr),
                icon: const Icon(Icons.copy, size: 18),
                label: Text('copy_code'.tr),
              ),
              if (joinLink != null && joinLink.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _copy(joinLink, 'link_copied'.tr),
                  icon: const Icon(Icons.link, size: 18),
                  label: Text('copy_link'.tr),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: ctrl.shareViaWhatsApp,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text('share_via_whatsapp'.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          PrimaryButton(
            text: 'done'.tr,
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final Country? country;
  final VoidCallback onPickCountry;

  const _PhoneField({
    required this.controller,
    required this.country,
    required this.onPickCountry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasCountry = country != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: Row(
            children: [
              Text(
                'phone_number'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.s1),
              Text(
                '(${'optional'.tr})',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // Two separate cards: the country selector on the left and the phone
        // field on the right. Top-aligned so a validation error growing under
        // the phone field never stretches the country card. The country card's
        // height comes from its padding (matching the field) — not a fixed
        // height — so the two boxes line up at rest.
        Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onPickCountry,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasCountry
                          ? '${country!.flagEmoji}  +${country!.phoneCode}'
                          : 'select_country'.tr,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: hasCountry
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 16,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(hintText: 'phone_number_hint'.tr),
                validator: (v) {
                  final n = (v ?? '').trim();
                  // Phone is optional — blank is valid (sign-in via link/QR).
                  if (n.isEmpty) return null;
                  // Once a number is typed, a country code is required to build
                  // a valid E.164 number (8–15 digits total).
                  if (country == null) return 'country_required'.tr;
                  final full = '${country!.phoneCode}${_nationalDigits(n)}';
                  if (!RegExp(r'^[1-9]\d{7,14}$').hasMatch(full)) {
                    return 'phone_invalid'.tr;
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionToggle extends StatelessWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _SectionToggle({
    required this.title,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: () => onToggle(!enabled),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: enabled ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 22,
              color: enabled ? colors.brand : colors.textTertiary,
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeThumbColor: colors.brand,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFieldTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  /// Optional message shown below the tile. When [warningIsError] is true it is
  /// rendered in the error color (a hard problem); otherwise in the warning
  /// color (a non-blocking heads-up, e.g. an expiry date in the past).
  final String? warning;
  final bool warningIsError;

  const _DateFieldTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    this.warning,
    this.warningIsError = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasDate = date != null;
    final text = hasDate
        ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
        : 'select_date'.tr;
    final messageColor = warningIsError ? colors.error : colors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: warning != null ? messageColor : colors.borderHairline,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 20,
                  color: colors.textSecondary,
                ),
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
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                    onPressed: onClear,
                  ),
              ],
            ),
          ),
        ),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s1,
              left: AppSpacing.s1,
              right: AppSpacing.s1,
            ),
            child: Row(
              children: [
                Icon(
                  warningIsError
                      ? Icons.error_outline
                      : Icons.warning_amber_rounded,
                  size: 14,
                  color: messageColor,
                ),
                const SizedBox(width: AppSpacing.s1),
                Expanded(
                  child: Text(
                    warning!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: messageColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DurationUnitDropdown extends StatelessWidget {
  final String value;
  final List<String> units;
  final ValueChanged<String?> onChanged;

  const _DurationUnitDropdown({
    required this.value,
    required this.units,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Non-breaking space keeps this field's top aligned with the labelled
        // duration input beside it.
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.s2),
          child: Text(
            ' ',
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: units
              .map((u) => DropdownMenuItem(value: u, child: Text('unit_$u'.tr)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
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
              .map(
                (t) =>
                    DropdownMenuItem(value: t, child: Text('contract_$t'.tr)),
              )
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
                  final result = await Get.toNamed<dynamic>(
                    AppRoutes.branchManage,
                  );
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

/// Mutable draft for one recurring monthly allowance entered on the add-employee
/// form. The type is typed in freely (e.g. "housing", "transport", or any
/// custom name) and amount is held in its own controller. start_month defaults
/// server-side to the hire month and the allowance runs open-ended.
class _AllowanceDraft {
  final TextEditingController typeCtrl = TextEditingController();
  final TextEditingController amountCtrl = TextEditingController();

  void dispose() {
    typeCtrl.dispose();
    amountCtrl.dispose();
  }
}

/// Mutable draft for one document requested from this specific employee. The
/// name is the paper to provide (e.g. "Driver's license"); an optional note
/// gives the employee extra context. Submitted as an employee-scoped required
/// document so only this person is asked for it.
class _DocRequestDraft {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    noteCtrl.dispose();
  }
}

class _DocRequestCard extends StatelessWidget {
  final _DocRequestDraft draft;
  final VoidCallback onRemove;

  const _DocRequestCard({required this.draft, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: draft.nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'requested_document_name_label'.tr,
                    hintText: 'requested_document_name_hint'.tr,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'delete'.tr,
                icon: Icon(Icons.delete_outline, color: colors.error),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          TextFormField(
            controller: draft.noteCtrl,
            decoration: InputDecoration(
              labelText: 'requested_document_note_label'.tr,
            ),
          ),
        ],
      ),
    );
  }
}

class _AllowanceDraftCard extends StatelessWidget {
  final _AllowanceDraft draft;
  final VoidCallback onRemove;

  const _AllowanceDraftCard({required this.draft, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  controller: draft.typeCtrl,
                  decoration: InputDecoration(
                    labelText: 'allowance_type_label'.tr,
                    hintText: 'allowance_type_hint'.tr,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'delete'.tr,
                icon: Icon(Icons.delete_outline, color: colors.error),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          TextFormField(
            controller: draft.amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'amount'.tr,
              suffixText: 'currency_egp'.tr,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyDayOffSelector extends StatelessWidget {
  final Set<String> selectedDays;
  final List<String> daysOfWeek;
  final ValueChanged<String> onToggle;

  const _WeeklyDayOffSelector({
    required this.selectedDays,
    required this.daysOfWeek,
    required this.onToggle,
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
            'weekly_day_off'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ),
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: daysOfWeek.map((d) {
            final selected = selectedDays.contains(d);
            return GestureDetector(
              onTap: () => onToggle(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.brand.withValues(alpha: 0.12)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected ? colors.brand : colors.borderHairline,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: selected ? colors.brand : colors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Text(
                      'day_$d'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected ? colors.brand : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
