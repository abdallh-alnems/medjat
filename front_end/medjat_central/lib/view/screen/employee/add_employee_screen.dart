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
import '../../../data/model/shift_model.dart';

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
  final formKey = GlobalKey<FormState>();

  AddEmployeeController get ctrl => widget.ctrl;

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    jobTitleCtrl.dispose();
    salaryCtrl.dispose();
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
      if (usingShift)
        'shift_id': ctrl.selectedShiftId
      else ...{
        'work_start_time': ctrl.workStartTimeStr,
        'work_end_time': ctrl.workEndTimeStr,
      },
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
