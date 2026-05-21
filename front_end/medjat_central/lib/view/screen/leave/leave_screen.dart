import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/leave/leave_controller.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/leave_model.dart';
import '../../../data/model/employee_model.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<LeaveController>(LeaveController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('leaves'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_leave',
        onPressed: () => _showCreateLeaveSheet(context, ctrl),
        backgroundColor: colors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s2,
            ),
            child: Row(
              children: [
                _FilterChip(
                  label: 'all'.tr,
                  selected: ctrl.statusFilter == null,
                  onTap: () => ctrl.filterByStatus(null),
                ),
                const SizedBox(width: AppSpacing.s2),
                _FilterChip(
                  label: 'under_review'.tr,
                  selected: ctrl.statusFilter == 'pending',
                  onTap: () => ctrl.filterByStatus('pending'),
                ),
                const SizedBox(width: AppSpacing.s2),
                _FilterChip(
                  label: 'accepted'.tr,
                  selected: ctrl.statusFilter == 'approved',
                  onTap: () => ctrl.filterByStatus('approved'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadLeaves,
              child: GetBuilder<LeaveController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadLeaves,
                    widget: ctrl.leaves.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.beach_access_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_leaves'.tr,
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
                            itemCount: ctrl.leaves.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _LeaveTile(
                              leave: ctrl.leaves[i],
                              onApprove: () =>
                                  ctrl.approveLeave(ctrl.leaves[i].id),
                              onReject: () => _showRejectDialog(
                                  context, ctrl, ctrl.leaves[i].id),
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
      BuildContext context, LeaveController ctrl, int leaveId) {
    final reasonCtrl = TextEditingController();
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('reject_leave'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'rejection_reason'.tr,
              hintStyle: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textTertiary,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () {
                Get.back<void>();
                ctrl.rejectLeave(leaveId,
                    reason: reasonCtrl.text.trim().isNotEmpty
                        ? reasonCtrl.text.trim()
                        : null);
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('reject'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateLeaveSheet(BuildContext context, LeaveController ctrl) {
    final reasonCtrl = TextEditingController();
    int? selectedEmployeeId;
    String selectedDuration = 'single';
    String selectedLeaveType = 'annual';
    String selectedDayOfWeek = 'saturday';
    DateTime? startDate;
    DateTime? endDate;

    final employeeData = Get.find<EmployeeData>();

    const leaveTypes = [
      ('annual', 'سنوية'),
      ('sick', 'مرضية'),
      ('personal', 'شخصية'),
      ('unpaid', 'بدون أجر'),
    ];

    const daysOfWeek = [
      ('saturday', 'السبت'),
      ('sunday', 'الأحد'),
      ('monday', 'الاثنين'),
      ('tuesday', 'الثلاثاء'),
      ('wednesday', 'الأربعاء'),
      ('thursday', 'الخميس'),
      ('friday', 'الجمعة'),
    ];

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = AppColors.of(context);

          if (selectedLeaveType == 'annual' && selectedEmployeeId != null) {
            ctrl.loadBalance(selectedEmployeeId!);
          }

          return Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
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
                  Text('add_leave'.tr, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  _sectionLabel('select_employee'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  FutureBuilder<List<EmployeeModel>>(
                    future: employeeData.getEmployees().then((response) {
                      dynamic payload = response['data'];
                      if (payload is Map && payload['data'] != null) {
                        payload = payload['data'];
                      }
                      List<dynamic>? items;
                      if (payload is List) {
                        items = payload;
                      } else if (payload is Map) {
                        for (final key
                            in const ['items', 'records', 'list', 'data']) {
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
                    }),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: Padding(
                          padding: EdgeInsets.all(AppSpacing.s3),
                          child: CircularProgressIndicator.adaptive(),
                        ));
                      }
                      final list = snapshot.data ?? [];
                      return _dropdownField<int>(
                        hint: 'select_employee'.tr,
                        value: selectedEmployeeId,
                        items: list,
                        colors: colors,
                        itemBuilder: (e) => DropdownMenuItem<int>(
                          value: (e as EmployeeModel).id,
                          child: Text(e.name,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                              )),
                        ),
                        onChanged: (v) {
                          setSheetState(() => selectedEmployeeId = v);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _sectionLabel('leave_type'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: leaveTypes
                        .map((t) => _TypeChip(
                              label: t.$2,
                              selected: selectedLeaveType == t.$1,
                              onTap: () => setSheetState(
                                  () => selectedLeaveType = t.$1),
                              colors: colors,
                            ))
                        .toList(),
                  ),
                  if (selectedLeaveType == 'annual' &&
                      selectedEmployeeId != null) ...[
                    const SizedBox(height: AppSpacing.s3),
                    GetBuilder<LeaveController>(
                      builder: (_) {
                        if (ctrl.balanceLoading) {
                          return const Center(
                              child: Padding(
                            padding: EdgeInsets.all(AppSpacing.s2),
                            child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2),
                          ));
                        }
                        if (ctrl.balanceInfo != null) {
                          final remaining =
                              (ctrl.balanceInfo!['remaining_days'] as num?)?.toInt() ?? 0;
                          final used = (ctrl.balanceInfo!['used_days'] as num?)?.toInt() ?? 0;
                          final total =
                              (ctrl.balanceInfo!['total_days'] as num?)?.toInt() ?? (used + remaining);
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.s3),
                            decoration: BoxDecoration(
                              color: remaining > 0
                                  ? colors.brandSubtle
                                  : colors.error.withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: remaining > 0
                                    ? colors.brand
                                    : colors.error,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                    remaining > 0
                                        ? Icons.info_outline
                                        : Icons.warning_amber_rounded,
                                    size: 18,
                                    color: remaining > 0
                                        ? colors.brand
                                        : colors.error),
                                const SizedBox(width: AppSpacing.s2),
                                Expanded(
                                  child: Text(
                                    'leave_balance_summary'.trParams({
                                      'remaining': remaining.toString(),
                                      'used': used.toString(),
                                      'total': total.toString(),
                                    }),
                                    style: TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: remaining > 0
                                          ? colors.brand
                                          : colors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  _sectionLabel('المدة', colors),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      _TypeChip(
                        label: 'leave_single'.tr,
                        selected: selectedDuration == 'single',
                        onTap: () =>
                            setSheetState(() => selectedDuration = 'single'),
                        colors: colors,
                      ),
                      _TypeChip(
                        label: 'leave_recurring'.tr,
                        selected: selectedDuration == 'recurring',
                        onTap: () => setSheetState(
                            () => selectedDuration = 'recurring'),
                        colors: colors,
                      ),
                    ],
                  ),
                  if (selectedDuration == 'single') ...[
                    const SizedBox(height: AppSpacing.s3),
                    _DatePickerField(
                      label: 'leave_start_date'.tr,
                      value: startDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (picked != null) {
                          setSheetState(() => startDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    _DatePickerField(
                      label: 'leave_end_date'.tr,
                      value: endDate,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              endDate ?? startDate ?? DateTime.now(),
                          firstDate: startDate ?? DateTime(2024, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (picked != null) {
                          setSheetState(() => endDate = picked);
                        }
                      },
                    ),
                    if (selectedLeaveType == 'annual' &&
                        startDate != null &&
                        ctrl.balanceInfo != null) ...[
                      const SizedBox(height: AppSpacing.s3),
                      _BalanceWarning(
                        startDate: startDate!,
                        endDate: endDate ?? startDate!,
                        remaining: (ctrl.balanceInfo!['remaining_days'] as int?) ?? 0,
                        colors: colors,
                      ),
                    ],
                  ],
                  if (selectedDuration == 'recurring') ...[
                    const SizedBox(height: AppSpacing.s3),
                    _sectionLabel('يوم الأسبوع', colors),
                    const SizedBox(height: AppSpacing.s2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4),
                      decoration: BoxDecoration(
                        color: colors.sunken,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedDayOfWeek,
                          items: daysOfWeek
                              .map((d) => DropdownMenuItem<String>(
                                    value: d.$1,
                                    child: Text(d.$2,
                                        style: const TextStyle(
                                          fontFamily: 'IBM Plex Sans Arabic',
                                          fontSize: 14,
                                        )),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setSheetState(() => selectedDayOfWeek = v);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'leave_reason'.tr,
                    controller: reasonCtrl,
                    hint: 'leave_reason'.tr,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryButton(
                    text: 'save'.tr,
                    onPressed: () async {
                      if (selectedEmployeeId == null) {
                        Get.snackbar('خطأ', 'يرجى اختيار الموظف',
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      if (selectedDuration == 'single' && startDate == null) {
                        Get.snackbar('خطأ', 'يرجى اختيار تاريخ البداية',
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }

                      bool success;
                      if (selectedDuration == 'recurring') {
                        success = await ctrl.createRecurringLeave(
                          employeeId: selectedEmployeeId!,
                          dayOfWeek: selectedDayOfWeek,
                          type: selectedLeaveType,
                          reason: reasonCtrl.text.trim().isNotEmpty
                              ? reasonCtrl.text.trim()
                              : null,
                        );
                      } else {
                        success = await ctrl.createLeave(
                          employeeId: selectedEmployeeId!,
                          type: selectedLeaveType,
                          startDate: startDate!,
                          endDate: endDate,
                          reason: reasonCtrl.text.trim().isNotEmpty
                              ? reasonCtrl.text.trim()
                              : null,
                        );
                      }
                      if (success) {
                        Get.back<void>();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text, AppColorScheme colors) {
    return Text(text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ));
  }

  Widget _dropdownField<T>({
    required String hint,
    required T? value,
    required List<dynamic> items,
    required AppColorScheme colors,
    required DropdownMenuItem<T> Function(dynamic) itemBuilder,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(hint,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textTertiary,
              )),
          value: value,
          items: items.map(itemBuilder).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BalanceWarning extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final int remaining;
  final AppColorScheme colors;

  const _BalanceWarning({
    required this.startDate,
    required this.endDate,
    required this.remaining,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final requestedDays =
        endDate.difference(startDate).inDays + 1;
    if (requestedDays <= remaining) return const SizedBox.shrink();

    final paidDays = remaining;
    final unpaidDays = requestedDays - remaining;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: colors.warning),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              'سيُحتسب $paidDays يوم بأجر و $unpaidDays يوم بدون أجر',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    this.value,
    required this.onTap,
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
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: colors.brand),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  value != null
                      ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                      : label,
                  style: TextStyle(
                    fontFamily: value != null ? 'Geist' : 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        value != null ? colors.textPrimary : colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _TypeChip({
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
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
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

class _LeaveTile extends StatelessWidget {
  final LeaveModel leave;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _LeaveTile({
    required this.leave,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(leave.status, colors);

    String dateLabel =
        '${leave.startDate.day}/${leave.startDate.month}/${leave.startDate.year}';
    if (leave.endDate != null && leave.endDate != leave.startDate) {
      dateLabel =
          '$dateLabel - ${leave.endDate!.day}/${leave.endDate!.month}/${leave.endDate!.year}';
    }

    return Container(
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
              Expanded(
                child: Text(
                  leave.employeeName ?? 'employee'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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
                  leave.statusLabel,
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
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Text(
                leave.typeLabel,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
          if (leave.reason != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              leave.reason!,
              style: AppTextStyles.sm(context),
            ),
          ],
          if (leave.status == 'rejected' &&
              leave.rejectionReason != null &&
              leave.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Text(
                    leave.rejectionReason!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (leave.status == 'pending') ...[
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onApprove,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('accept'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('reject'.tr),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'pending':
        return colors.warning;
      case 'approved':
        return colors.success;
      case 'rejected':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }
}
