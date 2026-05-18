import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';
import '../../../data/model/attendance_model.dart';

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
                    widget: ctrl.records.isEmpty
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
                            itemCount: ctrl.records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _AttendanceTile(
                              record: ctrl.records[i],
                            ),
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

  void _showManualCheckInSheet(BuildContext context, AttendanceController ctrl) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('manual_check_in'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s5),
            TextField(
              decoration: InputDecoration(
                hintText: 'employee_number'.tr,
                labelText: 'employee_number'.tr,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    child: Text('check_in'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: Text('check_out'.tr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
        ),
      ),
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
