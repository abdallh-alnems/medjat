import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';
import '../../../logic/controller/branch/branch_controller.dart';
import '../../../logic/controller/employee/employee_controller.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/employee_model.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AttendanceController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('attendance_departure'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_outlined),
            onPressed: () => _showFilterSheet(context, ctrl),
          ),
        ],
      ),
      body: Column(
        children: [
          _DatePickerRow(ctrl: ctrl),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadAttendance,
              child: GetBuilder<AttendanceController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadAttendance,
                    widget: GetBuilder<AttendanceController>(
                      builder: (c) {
                        if (!c.hasEmployees) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.s5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.group_add_outlined,
                                      size: 56, color: colors.textTertiary),
                                  const SizedBox(height: AppSpacing.s4),
                                  Text('add_employees_first'.tr,
                                      style: AppTextStyles.h3(context),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: AppSpacing.s5),
                                  ElevatedButton.icon(
                                    onPressed: () => Get.toNamed<void>(
                                        AppRoutes.employeeAdd),
                                    icon: const Icon(Icons.person_add, size: 20),
                                    label: Text('add_employee'.tr),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colors.brand,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return c.records.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.event_available_outlined,
                                        size: 48,
                                        color: colors.textTertiary),
                                    const SizedBox(height: AppSpacing.s3),
                                    Text('no_records_today'.tr,
                                        style:
                                            AppTextStyles.bodySecondary(context)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.s4,
                                  0,
                                  AppSpacing.s4,
                                  AppSpacing.s7,
                                ),
                                itemCount: c.records.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.s2),
                                itemBuilder: (_, i) => _AttendanceTile(
                                  record: c.records[i],
                                ),
                              );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_attendance',
        onPressed: () => _showManualCheckInSheet(context, ctrl),
        backgroundColor: colors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, AttendanceController ctrl) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('filter'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s4),
            ListTile(
              title: Text('all_branches'.tr),
              onTap: () {
                ctrl.filterByBranch(null);
                Get.back();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManualCheckInSheet(BuildContext context, AttendanceController ctrl) async {
    final employeeCtrl = Get.find<EmployeeController>();
    final branchCtrl = Get.find<BranchController>();
    if (employeeCtrl.employees.isEmpty) {
      await employeeCtrl.loadEmployees();
    }
    if (branchCtrl.branches.isEmpty) {
      await branchCtrl.loadBranches();
    }

    EmployeeModel? selectedEmployee;
    int? selectedBranchId;
    DateTime selectedDate = ctrl.selectedDate;
    TimeOfDay checkIn = TimeOfDay.now();
    TimeOfDay checkOut = TimeOfDay.now();
    bool isCheckOutMode = false;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = AppColors.of(context);

          final baseEmployees = isCheckOutMode
              ? ctrl.getEmployeesEligibleForCheckOut(employeeCtrl.employees)
              : ctrl.getEmployeesEligibleForCheckIn(employeeCtrl.employees);

          final filteredEmployees = baseEmployees
              .where((e) =>
                  selectedBranchId == null || e.branchId == selectedBranchId)
              .toList();

          final branchHasEmployees = selectedBranchId == null ||
              employeeCtrl.employees
                  .any((e) => e.branchId == selectedBranchId);

          if (selectedEmployee != null &&
              !filteredEmployees.any((e) => e.id == selectedEmployee!.id)) {
            selectedEmployee = null;
          }

          return Container(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s4,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.borderHairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('manual_attendance'.tr, style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s4),
                  Text('attendance_mode'.tr, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('mode_check_in'.tr),
                          icon: const Icon(Icons.login, size: 18),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('mode_check_out'.tr),
                          icon: const Icon(Icons.logout, size: 18),
                        ),
                      ],
                      selected: {isCheckOutMode},
                      onSelectionChanged: (s) => setSheetState(() {
                        isCheckOutMode = s.first;
                        selectedEmployee = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  if (branchCtrl.branches.length > 1) ...[
                    Text('branch'.tr, style: AppTextStyles.h3(context)),
                    const SizedBox(height: AppSpacing.s2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.sunken,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: selectedBranchId,
                          hint: Text('all_branches'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                                color: colors.textSecondary,
                              )),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('all_branches'.tr,
                                  style: const TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ),
                            ...branchCtrl.branches.map((b) =>
                                DropdownMenuItem<int?>(
                                  value: b.id,
                                  child: Text(b.name,
                                      style: const TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      )),
                                )),
                          ],
                          onChanged: (v) =>
                              setSheetState(() => selectedBranchId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                  ],
                  if (filteredEmployees.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      child: Text(
                        !branchHasEmployees
                            ? 'no_employees_in_branch'.tr
                            : isCheckOutMode
                                ? 'no_employees_eligible_check_out'.tr
                                : 'all_employees_have_records'.tr,
                        style: AppTextStyles.bodySecondary(context),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                    Text('select_employee'.tr, style: AppTextStyles.h3(context)),
                    const SizedBox(height: AppSpacing.s2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.sunken,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EmployeeModel>(
                          value: selectedEmployee,
                          hint: Text('select_employee'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                                color: colors.textSecondary,
                              )),
                          isExpanded: true,
                          items: filteredEmployees
                              .map((e) => DropdownMenuItem<EmployeeModel>(
                                    value: e,
                                    child: Text(
                                      e.name,
                                      style: const TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setSheetState(() => selectedEmployee = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text('date'.tr, style: AppTextStyles.h3(context)),
                    const SizedBox(height: AppSpacing.s2),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetCtx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setSheetState(() => selectedDate = picked);
                      },
                      child: _PickerTile(
                        icon: Icons.calendar_today,
                        value:
                            '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      isCheckOutMode ? 'check_out'.tr : 'check_in'.tr,
                      style: AppTextStyles.h3(context),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    InkWell(
                      onTap: () async {
                        final t = await showTimePicker(
                          context: sheetCtx,
                          initialTime: isCheckOutMode ? checkOut : checkIn,
                        );
                        if (t != null) {
                          setSheetState(() {
                            if (isCheckOutMode) {
                              checkOut = t;
                            } else {
                              checkIn = t;
                            }
                          });
                        }
                      },
                      child: _PickerTile(
                        icon: isCheckOutMode ? Icons.logout : Icons.login,
                        value: isCheckOutMode
                            ? '${checkOut.hour.toString().padLeft(2, '0')}:${checkOut.minute.toString().padLeft(2, '0')}'
                            : '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: selectedEmployee == null
                            ? null
                            : () async {
                                Get.back();
                                await ctrl.recordManualAttendance(
                                  employeeId: selectedEmployee!.id,
                                  branchId: selectedEmployee!.branchId,
                                  date: selectedDate,
                                  checkInTime: isCheckOutMode ? null : checkIn,
                                  checkOutTime: isCheckOutMode ? checkOut : null,
                                );
                              },
                        icon: const Icon(Icons.save_outlined),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                          child: Text('save'.tr),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final AttendanceController ctrl;
  const _DatePickerRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        children: [
          IconButton.outlined(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => ctrl.changeDate(
              ctrl.selectedDate.subtract(const Duration(days: 1)),
            ),
          ),
          Expanded(
            child: Center(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: ctrl.selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) ctrl.changeDate(picked);
                },
                child: Text(
                  _formatDate(ctrl.selectedDate),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.brand,
                  ),
                ),
              ),
            ),
          ),
          IconButton.outlined(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () {
              final next = ctrl.selectedDate.add(const Duration(days: 1));
              if (!next.isAfter(DateTime.now())) {
                ctrl.changeDate(next);
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _AttendanceTile extends StatelessWidget {
  final AttendanceRecordModel record;
  const _AttendanceTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(record.status, colors);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.employeeName ?? 'employee'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (record.checkIn != null)
                      Text(
                        '${'check_in_label'.tr} ${_formatTime(record.checkIn!)}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    if (record.checkIn != null && record.checkOut != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s2),
                        child: Text('—',
                            style: TextStyle(
                                fontSize: 12, color: colors.textTertiary)),
                      ),
                    if (record.checkOut != null)
                      Text(
                        '${'check_out_label'.tr} ${_formatTime(record.checkOut!)}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    if (record.checkIn == null && record.checkOut == null)
                      Text(
                        'not_recorded'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s2,
              vertical: AppSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              record.statusLabel,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'present':
        return colors.success;
      case 'absent':
        return colors.error;
      case 'late':
        return colors.warning;
      case 'leave':
        return colors.accentWarm;
      default:
        return colors.textTertiary;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String value;
  const _PickerTile({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: AppSpacing.s2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.brand,
            ),
          ),
        ],
      ),
    );
  }
}
