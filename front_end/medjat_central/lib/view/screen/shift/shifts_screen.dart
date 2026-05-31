import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../data/model/shift_model.dart';
import '../../../logic/controller/shift/shift_controller.dart';

class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ShiftController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('shifts'.tr)),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          heroTag: 'fab_shifts',
          onPressed: () => _showAddEditSheet(context, ctrl),
          backgroundColor: colors.brand,
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.loadShifts,
        child: GetBuilder<ShiftController>(
          builder: (_) {
            return HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadShifts,
              widget: ctrl.shifts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule_outlined,
                              size: 48, color: colors.textTertiary),
                          const SizedBox(height: AppSpacing.s3),
                          Text('no_shifts'.tr,
                              style: AppTextStyles.bodySecondary(context)),
                          const SizedBox(height: AppSpacing.s4),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showAddEditSheet(context, ctrl),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text('add_shift'.tr),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4,
                        AppSpacing.s4,
                        AppSpacing.s4,
                        AppSpacing.s7,
                      ),
                      itemCount: ctrl.shifts.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s3),
                      itemBuilder: (_, i) => _ShiftTile(
                        shift: ctrl.shifts[i],
                        onView: () => Get.toNamed<void>(
                          AppRoutes.shiftMembers,
                          arguments: ctrl.shifts[i],
                        ),
                        onEdit: () => _showAddEditSheet(
                          context,
                          ctrl,
                          existing: ctrl.shifts[i],
                        ),
                        onDelete: () => _confirmDelete(context, ctrl, ctrl.shifts[i]),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ShiftController ctrl, ShiftModel shift) {
    Get.dialog<void>(
      AlertDialog(
        title: Text('delete'.tr),
        content: Text('${'confirm_delete'.tr} "${shift.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              final ok = await ctrl.deleteShift(shift.id);
              if (ok) {
                Get.snackbar('done'.tr, 'shift_deleted'.tr,
                    snackPosition: SnackPosition.BOTTOM);
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.of(context).error),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  void _showAddEditSheet(
    BuildContext context,
    ShiftController ctrl, {
    ShiftModel? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final isLoading = false.obs;
    TimeOfDay startTime = existing != null
        ? _parseTimeOfDay(existing.startTime)
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = existing != null
        ? _parseTimeOfDay(existing.endTime)
        : const TimeOfDay(hour: 17, minute: 0);

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.s5,
              right: AppSpacing.s5,
              top: AppSpacing.s5,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
            ),
            child: SingleChildScrollView(
              child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing != null ? 'edit_shift'.tr : 'add_shift'.tr,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: 'shift_name'.tr),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'required'.tr : null,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('shift_start'.tr),
                    trailing: Text(
                      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (t != null) {
                        startTime = t;
                        setModalState(() {});
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('shift_end'.tr),
                    trailing: Text(
                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (t != null) {
                        endTime = t;
                        setModalState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Obx(() => SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading.value
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  isLoading.value = true;
                                  final startStr =
                                      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
                                  final endStr =
                                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

                                  bool ok;
                                  if (existing != null) {
                                    ok = await ctrl.updateShift(existing.id, {
                                      'name': nameCtrl.text.trim(),
                                      'start_time': startStr,
                                      'end_time': endStr,
                                    });
                                  } else {
                                    ok = await ctrl.createShift(
                                      name: nameCtrl.text.trim(),
                                      startTime: startStr,
                                      endTime: endStr,
                                    );
                                  }
                                  isLoading.value = false;
                                  if (ok) {
                                    Get.back();
                                    Get.snackbar(
                                      'done'.tr,
                                      existing != null
                                          ? 'shift_updated'.tr
                                          : 'shift_created'.tr,
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.of(context).brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: isLoading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  existing != null ? 'update'.tr : 'create'.tr,
                                  style: const TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      )),
                ],
              ),
            ),
            ),
          );
        },
      ),
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
    );
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
}

class _ShiftTile extends StatelessWidget {
  final ShiftModel shift;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ShiftTile({
    required this.shift,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final badgeColor = colors.brand;

    return Dismissible(
      key: ValueKey(shift.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.s4),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(Icons.delete_outline, color: colors.error),
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.schedule_outlined,
                    color: badgeColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          shift.name,
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (shift.branchName != null) ...[
                          const SizedBox(width: AppSpacing.s2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.brandSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              shift.branchName!,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 10,
                                color: colors.brand,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${_formatTime(shift.startTime)} - ${_formatTime(shift.endTime)}',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Icon(Icons.person_outline, size: 14, color: colors.textTertiary),
                        const SizedBox(width: 2),
                        Text(
                          '${shift.employeeCount}',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String t) {
    final parts = t.split(':');
    return '${parts[0]}:${parts[1]}';
  }
}
