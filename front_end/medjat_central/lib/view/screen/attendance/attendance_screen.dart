import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/attendance_pdf_exporter.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';
import '../../../logic/controller/branch/branch_controller.dart';
import '../../../logic/controller/shift/shift_controller.dart';
import '../../../logic/controller/category/category_controller.dart';
import '../../../logic/controller/employee/employee_controller.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/employee_model.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../data/model/employee_category_model.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GetBuilder<AttendanceController>(
      builder: (ctrl) {
        return Scaffold(
          appBar: AppBar(
            title: Text('attendance_departure'.tr),
            actions: [
              IconButton(
                tooltip: 'export_pdf'.tr,
                icon: const Icon(Icons.file_download_outlined, size: 22),
                onPressed: () => _exportPdf(context, ctrl),
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _showFilterSheet(context, ctrl),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ctrl.activeFilterCount > 0
                          ? colors.brand
                          : colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: ctrl.activeFilterCount > 0
                            ? colors.brand
                            : colors.borderHairline,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 20,
                          color: ctrl.activeFilterCount > 0
                              ? Colors.white
                              : colors.textSecondary,
                        ),
                        if (ctrl.activeFilterCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${ctrl.activeFilterCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6C5CE7),
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _DatePickerRow(ctrl: ctrl),
              if (ctrl.status == StatusRequest.success && ctrl.records.isNotEmpty) ...[
                if (ctrl.newLatecomersCount > 0 &&
                    !ctrl.latecomerBannerDismissed)
                  _LatecomerBanner(ctrl: ctrl),
                _SummaryCard(ctrl: ctrl),
                _StatusFilterBar(ctrl: ctrl),
                _SearchBar(ctrl: ctrl),
              ],
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
                            final filtered = c.filteredRecords;
                            return filtered.isEmpty
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
                                              AppTextStyles.bodySecondary(context),
                                        ),
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
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: AppSpacing.s2),
                                    itemBuilder: (_, i) => _AttendanceTile(
                                      record: filtered[i],
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
      },
    );
  }

  void _showFilterSheet(BuildContext context, AttendanceController ctrl) {
    final branchCtrl = Get.find<BranchController>();
    final shiftCtrl = Get.find<ShiftController>();
    final categoryCtrl = Get.find<CategoryController>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttendanceFilterPanel(
        ctrl: ctrl,
        branches: branchCtrl.branches,
        shifts: shiftCtrl.shifts,
        categories: categoryCtrl.categories,
      ),
    );
  }

  void _showManualCheckInSheet(BuildContext context, AttendanceController ctrl) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ManualCheckInSheet(ctrl: ctrl),
    );
  }

  Future<void> _exportPdf(
      BuildContext context, AttendanceController ctrl) async {
    if (ctrl.records.isEmpty) {
      Get.snackbar('export_pdf'.tr, 'no_records_to_export'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await AttendancePdfExporter.exportAndShare(
        records: ctrl.filteredRecords,
        date: ctrl.selectedDate,
      );
    } catch (e) {
      Get.snackbar('export_failed'.tr, e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

class _LatecomerBanner extends StatelessWidget {
  final AttendanceController ctrl;
  const _LatecomerBanner({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active, size: 18, color: colors.warning),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'new_latecomers'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colors.warning,
                  ),
                ),
                Text(
                  '${ctrl.newLatecomersCount} ${"new_latecomers".tr}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.full),
            onTap: ctrl.dismissLatecomerBanner,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 16, color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AttendanceController ctrl;
  const _SummaryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rate = ctrl.attendanceRatePercent;
    final avgLate = ctrl.averageLateMinutes;

    final rateColor = rate >= 90
        ? colors.success
        : rate >= 70
            ? colors.warning
            : colors.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s3,
      ),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              icon: Icons.trending_up,
              label: 'attendance_rate'.tr,
              value: '$rate%',
              accent: rateColor,
              subtitle: '${ctrl.attendedCount}/${ctrl.records.length}',
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: colors.borderHairline,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          ),
          Expanded(
            child: _SummaryMetric(
              icon: Icons.timer_outlined,
              label: 'avg_late_minutes'.tr,
              value: '$avgLate',
              accent: avgLate > 0 ? colors.warning : colors.textSecondary,
              subtitle: 'minutes_short'.tr,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color accent;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  final AttendanceController ctrl;
  const _StatusFilterBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final chips = <_StatusChipData>[
      _StatusChipData(
        key: 'all',
        label: 'attendance_today'.tr,
        icon: Icons.people_outline,
        count: ctrl.records.length,
        color: colors.brand,
      ),
      _StatusChipData(
        key: 'present',
        label: 'present'.tr,
        icon: Icons.check_circle_outline,
        count: ctrl.presentCount,
        color: colors.success,
      ),
      _StatusChipData(
        key: 'absent',
        label: 'absent'.tr,
        icon: Icons.cancel_outlined,
        count: ctrl.absentCount,
        color: colors.error,
      ),
      _StatusChipData(
        key: 'not_arrived',
        label: 'not_arrived'.tr,
        icon: Icons.person_outline,
        count: ctrl.notArrivedCount,
        color: colors.textTertiary,
      ),
      _StatusChipData(
        key: 'late',
        label: 'late'.tr,
        icon: Icons.access_time,
        count: ctrl.lateCount,
        color: colors.warning,
      ),
      _StatusChipData(
        key: 'leave',
        label: 'on_leave'.tr,
        icon: Icons.beach_access_outlined,
        count: ctrl.leaveCount,
        color: colors.accentWarm,
      ),
      _StatusChipData(
        key: 'half_day',
        label: 'status_half_day'.tr,
        icon: Icons.brightness_2_outlined,
        count: ctrl.halfDayCount,
        color: colors.brandSubtle,
      ),
    ];

    chips.removeWhere((c) => c.count == 0 && c.key != 'all');

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s1),
        itemBuilder: (_, i) {
          final chip = chips[i];
          final isSelected = chip.key == 'all'
              ? ctrl.statusFilter == null
              : ctrl.statusFilter == chip.key;
          final bgColor = isSelected ? chip.color : colors.surface;
          final textColor = isSelected ? Colors.white : colors.textPrimary;
          final borderColor =
              isSelected ? chip.color : colors.borderHairline;

          return Material(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => ctrl.toggleStatusFilter(
                chip.key == 'all' ? null : chip.key,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chip.label,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : colors.sunken,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${chip.count}',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final AttendanceController ctrl;
  const _SearchBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.borderHairline),
              ),
              child: TextField(
                onChanged: ctrl.onSearch,
                decoration: InputDecoration(
                  hintText: 'search_employee'.tr,
                  hintStyle: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: colors.textSecondary),
                  suffixIcon: ctrl.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close,
                              size: 16, color: colors.textTertiary),
                          onPressed: () => ctrl.onSearch(''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          _SortButton(ctrl: ctrl),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final AttendanceController ctrl;
  const _SortButton({required this.ctrl});

  static const _options = <Map<String, String>>[
    {'key': 'name', 'label': 'sort_name', 'icon': 'name'},
    {'key': 'status', 'label': 'sort_status', 'icon': 'status'},
    {'key': 'check_in', 'label': 'sort_check_in', 'icon': 'time'},
  ];

  IconData _iconFor(String key) {
    switch (key) {
      case 'status':
        return Icons.flag_outlined;
      case 'time':
        return Icons.access_time;
      default:
        return Icons.sort_by_alpha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showMenu(context),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert,
                  size: 16, color: colors.textSecondary),
              const SizedBox(width: 4),
              Icon(_iconFor(ctrl.sortBy == 'status'
                      ? 'status'
                      : ctrl.sortBy == 'check_in'
                          ? 'time'
                          : 'name'),
                  size: 14, color: colors.brand),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s3,
          AppSpacing.s4,
          AppSpacing.s5,
        ),
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Text('sort_by'.tr, style: AppTextStyles.h3(context)),
            ),
            const SizedBox(height: AppSpacing.s2),
            ..._options.map((opt) {
              final isSelected = ctrl.sortBy == opt['key'];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () {
                    ctrl.setSortBy(opt['key']!);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                      vertical: AppSpacing.s3,
                    ),
                    child: Row(
                      children: [
                        Icon(_iconFor(opt['icon']!),
                            size: 18,
                            color: isSelected
                                ? colors.brand
                                : colors.textSecondary),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: Text(
                            opt['label']!.tr,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? colors.brand
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, size: 18, color: colors.brand),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatusChipData {
  final String key;
  final String label;
  final IconData icon;
  final int count;
  final Color color;
  const _StatusChipData({
    required this.key,
    required this.label,
    required this.icon,
    required this.count,
    required this.color,
  });
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
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: ctrl.selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) ctrl.changeDate(picked);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: colors.brand),
                    const SizedBox(width: AppSpacing.s2),
                    Text(
                      '${_dayName(ctrl.selectedDate)}  ${_formatDate(ctrl.selectedDate)}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s1),
                    Icon(Icons.expand_more,
                        size: 16, color: colors.brand),
                  ],
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

  String _dayName(DateTime date) {
    const ar = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const en = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final isAr = Get.locale?.languageCode == 'ar';
    return (isAr ? ar : en)[date.weekday - 1];
  }
}

String? _formatAttendanceShiftRange(String? start, String? end) {
  String? trim(String? t) {
    if (t == null || t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0]}:${parts[1]}';
  }

  final s = trim(start);
  final e = trim(end);
  if (s == null && e == null) return null;
  return '${s ?? '—'} - ${e ?? '—'}';
}

class _AttendanceTile extends StatelessWidget {
  final AttendanceRecordModel record;
  const _AttendanceTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(record.status, colors);
    final hasFlags = (record.lateMinutes ?? 0) > 0 ||
        (record.overtimeMinutes ?? 0) > 0;
    final hasTimes = record.checkIn != null || record.checkOut != null;
    final isLeaveLike = record.status == 'leave' ||
        record.status == 'holiday' ||
        record.status == 'weekly_off';
    final leaveReason = _leaveReason(record);

    final canEditNote = record.id > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => Get.toNamed<void>(
        AppRoutes.employeeDetail
            .replaceAll(':id', '${record.employeeId}'),
        arguments: {'id': record.employeeId, 'initialTab': 1},
      ),
      onLongPress: canEditNote
          ? () => _showNoteSheet(context, record)
          : () => Get.snackbar(
                'add_note'.tr,
                'note_requires_attendance'.tr,
                snackPosition: SnackPosition.BOTTOM,
              ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s3,
          AppSpacing.s3,
          AppSpacing.s3,
          AppSpacing.s3,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: status bar + name/subtitle + status badge ──
            Row(
              children: [
                Container(
                  width: 3,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.employeeName ?? 'employee'.tr,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if ((record.note ?? '').trim().isNotEmpty &&
                              !isLeaveLike) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.sticky_note_2,
                                size: 13, color: colors.brand),
                          ],
                        ],
                      ),
                      if (record.branchName != null ||
                          record.shiftName != null ||
                          (record.shiftStart ?? '').isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          [
                            record.branchName,
                            record.shiftName,
                            _formatAttendanceShiftRange(
                                record.shiftStart, record.shiftEnd),
                          ]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      isLeaveLike && leaveReason != null
                          ? leaveReason
                          : record.statusLabel,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            // ── Times row (skipped for leave-like statuses; badge holds the reason) ──
            if (!isLeaveLike) ...[
              const SizedBox(height: AppSpacing.s3),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s4),
                child: hasTimes
                    ? _TimesRow(record: record)
                    : Text(
                        'not_recorded'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
              ),
            ],
            // ── Flags row (late/overtime) ──
            if (hasFlags) ...[
              const SizedBox(height: AppSpacing.s2),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.s4),
                child: Wrap(
                  spacing: AppSpacing.s2,
                  runSpacing: 4,
                  children: [
                    if ((record.lateMinutes ?? 0) > 0)
                      _DurationChip(
                        icon: Icons.timer_outlined,
                        text:
                            '${'late_by'.tr} ${record.lateMinutes!.round()} ${'minutes_short'.tr}',
                        color: colors.warning,
                      ),
                    if ((record.overtimeMinutes ?? 0) > 0)
                      _DurationChip(
                        icon: Icons.add_circle_outline,
                        text:
                            '${'overtime_by'.tr} ${record.overtimeMinutes!.round()} ${'minutes_short'.tr}',
                        color: colors.success,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
      case 'holiday':
      case 'weekly_off':
        return colors.accentWarm;
      case 'not_arrived':
        return colors.textTertiary;
      default:
        return colors.textTertiary;
    }
  }

  void _showNoteSheet(BuildContext context, AttendanceRecordModel record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteEditSheet(record: record),
    );
  }

  String? _leaveReason(AttendanceRecordModel r) {
    if (r.status == 'holiday') return 'status_holiday'.tr;
    if (r.status == 'weekly_off') return 'status_weekly_off'.tr;
    if (r.status == 'leave') {
      final note = r.note?.trim();
      if (note != null && note.isNotEmpty) return note;
      if (r.leaveType != null && r.leaveType!.isNotEmpty) return r.leaveType;
      return 'status_leave'.tr;
    }
    return null;
  }
}

class _TimesRow extends StatelessWidget {
  final AttendanceRecordModel record;
  const _TimesRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        if (record.checkIn != null)
          _TimePoint(
            icon: Icons.login,
            time: _formatTime(record.checkIn!),
            color: colors.success,
          ),
        if (record.checkIn != null && record.checkOut != null) ...[
          const SizedBox(width: AppSpacing.s2),
          Icon(Icons.arrow_forward, size: 12, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.s2),
        ],
        if (record.checkIn == null && record.checkOut != null)
          _TimePoint(
            icon: Icons.logout,
            time: _formatTime(record.checkOut!),
            color: colors.error,
          ),
        if (record.checkIn != null && record.checkOut != null)
          _TimePoint(
            icon: Icons.logout,
            time: _formatTime(record.checkOut!),
            color: colors.error,
          ),
        const Spacer(),
        if (record.checkIn != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 12, color: colors.textSecondary),
              const SizedBox(width: 3),
              Text(
                _workDuration(record.checkIn!, record.checkOut),
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _workDuration(DateTime checkIn, DateTime? checkOut) {
    final end = checkOut ?? DateTime.now();
    final diff = end.difference(checkIn);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}

class _TimePoint extends StatelessWidget {
  final IconData icon;
  final String time;
  final Color color;
  const _TimePoint({
    required this.icon,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DurationChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceFilterPanel extends StatefulWidget {
  final AttendanceController ctrl;
  final List<BranchModel> branches;
  final List<ShiftModel> shifts;
  final List<EmployeeCategoryModel> categories;
  const _AttendanceFilterPanel({
    required this.ctrl,
    required this.branches,
    required this.shifts,
    required this.categories,
  });

  @override
  State<_AttendanceFilterPanel> createState() => _AttendanceFilterPanelState();
}

class _AttendanceFilterPanelState extends State<_AttendanceFilterPanel> {
  late int? _branchId = widget.ctrl.branchFilter;
  late int? _shiftId = widget.ctrl.shiftFilter;
  late int? _categoryId = widget.ctrl.categoryFilter;

  List<ShiftModel> get _visibleShifts {
    if (_branchId == null) return widget.shifts;
    return widget.shifts
        .where((s) => s.branchId == null || s.branchId == _branchId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final visibleShifts = _visibleShifts;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('customize_view'.tr, style: AppTextStyles.h2(context)),
          const SizedBox(height: AppSpacing.s4),
          if (widget.branches.isNotEmpty) ...[
            _FilterLabel(text: 'branch'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _branchId,
              hint: 'all_branches'.tr,
              icon: Icons.account_tree_outlined,
              items: widget.branches
                  .map((b) => DropdownMenuItem<int?>(
                        value: b.id,
                        child: Text(b.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _branchId = v;
                if (_shiftId != null &&
                    !visibleShifts.any((s) => s.id == _shiftId)) {
                  _shiftId = null;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (visibleShifts.isNotEmpty) ...[
            _FilterLabel(text: 'shift'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _shiftId,
              hint: 'all_shifts'.tr,
              icon: Icons.schedule_outlined,
              items: visibleShifts
                  .map((s) => DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text(s.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _shiftId = v),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (widget.categories.isNotEmpty) ...[
            _FilterLabel(text: 'category'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _categoryId,
              hint: 'all_categories'.tr,
              icon: Icons.category_outlined,
              items: widget.categories
                  .map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _branchId = null;
                      _shiftId = null;
                      _categoryId = null;
                    });
                  },
                  child: Text(
                    'clear_filters'.tr,
                    style:
                        const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.ctrl.applyFilters(
                      branchId: _branchId,
                      shiftId: _shiftId,
                      categoryId: _categoryId,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'apply'.tr,
                    style:
                        const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'IBM Plex Sans Arabic',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.expand_more, size: 18),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                hint: Text(
                  hint,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                items: [
                  DropdownMenuItem<T>(
                    value: null as T,
                    child: Text(hint),
                  ),
                  ...items,
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualCheckInSheet extends StatefulWidget {
  final AttendanceController ctrl;
  const _ManualCheckInSheet({required this.ctrl});

  @override
  State<_ManualCheckInSheet> createState() => _ManualCheckInSheetState();
}

class _ManualCheckInSheetState extends State<_ManualCheckInSheet> {
  final _searchCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _scrollCtrl = DraggableScrollableController();

  late List<EmployeeModel> _allEmployees;
  late List<BranchModel> _branches;
  late List<ShiftModel> _shifts;
  late List<EmployeeCategoryModel> _categories;

  final Set<int> _selectedIds = <int>{};
  int? _branchId;
  int? _shiftId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  TimeOfDay _checkIn = TimeOfDay.now();
  TimeOfDay _checkOut = TimeOfDay.now();
  bool _isCheckOut = false;
  String _search = '';
  bool _showFilters = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _date = widget.ctrl.selectedDate;
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final empCtrl = Get.find<EmployeeController>();
    if (empCtrl.employees.isEmpty) await empCtrl.loadEmployees();
    _allEmployees = empCtrl.employees.where((e) => e.status == 'active').toList();

    final branchCtrl = Get.find<BranchController>();
    final shiftCtrl = Get.find<ShiftController>();
    final catCtrl = Get.find<CategoryController>();
    _branches = branchCtrl.branches;
    _shifts = shiftCtrl.shifts;
    _categories = catCtrl.categories;

    setState(() => _loading = false);
  }

  List<ShiftModel> get _visibleShifts {
    if (_branchId == null) return _shifts;
    return _shifts
        .where((s) => s.branchId == null || s.branchId == _branchId)
        .toList();
  }

  List<EmployeeModel> get _filteredEmployees {
    var list = _isCheckOut
        ? widget.ctrl.getEmployeesEligibleForCheckOut(_allEmployees)
        : widget.ctrl.getEmployeesEligibleForCheckIn(_allEmployees);

    if (_branchId != null) {
      list = list.where((e) => e.branchId == _branchId).toList();
    }
    if (_shiftId != null) {
      list = list.where((e) => e.shiftId == _shiftId).toList();
    }
    if (_categoryId != null) {
      list = list.where((e) {
        // Employees don't have category on the model; skip client-side
        return true;
      }).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              (e.employeeCode?.toLowerCase().contains(q) ?? false) ||
              (e.jobTitle?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final employees = _filteredEmployees;

    return DraggableScrollableSheet(
      controller: _scrollCtrl,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.85, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.canvas,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(
                            top: AppSpacing.s3, bottom: AppSpacing.s4),
                        decoration: BoxDecoration(
                          color: colors.borderHairline,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4),
                      child: Text('manual_attendance'.tr,
                          style: AppTextStyles.h2(context)),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('mode_check_in'.tr),
                              icon: const Icon(Icons.login, size: 16),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('mode_check_out'.tr),
                              icon: const Icon(Icons.logout, size: 16),
                            ),
                          ],
                          selected: {_isCheckOut},
                          onSelectionChanged: (s) => setState(() {
                            _isCheckOut = s.first;
                            _selectedIds.clear();
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: colors.borderHairline),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) =>
                              setState(() => _search = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'search_employee'.tr,
                            hintStyle: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 14,
                              color: colors.textSecondary,
                            ),
                            prefixIcon: Icon(Icons.search,
                                size: 20, color: colors.textSecondary),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.close,
                                        size: 18, color: colors.textTertiary),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _search = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s3,
                              vertical: AppSpacing.s2,
                            ),
                          ),
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () =>
                            setState(() => _showFilters = !_showFilters),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s3, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border:
                                Border.all(color: colors.borderHairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune,
                                  size: 16, color: colors.textSecondary),
                              const SizedBox(width: AppSpacing.s2),
                              Text(
                                'customize_view'.tr,
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s1),
                              Icon(
                                  _showFilters
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 16,
                                  color: colors.textTertiary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_showFilters) ...[
                      const SizedBox(height: AppSpacing.s3),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4),
                        child: _buildFilters(colors),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s3),
                    if (!_loading && employees.isNotEmpty)
                      _buildSelectAllBar(colors, employees),
                  ],
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                    padding: EdgeInsets.all(AppSpacing.s6),
                    child: CircularProgressIndicator(),
                  )),
                )
              else if (employees.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.s6),
                    child: Column(
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 48, color: colors.textTertiary),
                        const SizedBox(height: AppSpacing.s3),
                        Text(
                          _isCheckOut
                              ? 'no_employees_eligible_check_out'.tr
                              : 'all_employees_have_records'.tr,
                          style: AppTextStyles.bodySecondary(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final emp = employees[i];
                      final isSelected = _selectedIds.contains(emp.id);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s4,
                          vertical: 2,
                        ),
                        child: Material(
                          color: isSelected
                              ? colors.brand.withValues(alpha: 0.08)
                              : colors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            onTap: () => setState(() {
                              if (isSelected) {
                                _selectedIds.remove(emp.id);
                              } else {
                                _selectedIds.add(emp.id);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s3,
                                vertical: AppSpacing.s2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: isSelected
                                    ? Border.all(color: colors.brand)
                                    : Border.all(
                                        color: colors.borderHairline),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colors.brand
                                          : colors.sunken,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.full),
                                    ),
                                    child: Center(
                                      child: isSelected
                                          ? const Icon(Icons.check,
                                              size: 18, color: Colors.white)
                                          : Text(
                                              emp.name.isNotEmpty
                                                  ? emp.name[0]
                                                  : '?',
                                              style: TextStyle(
                                                fontFamily: 'Geist',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: colors.textSecondary,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emp.name,
                                          style: TextStyle(
                                            fontFamily:
                                                'IBM Plex Sans Arabic',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? colors.brand
                                                : colors.textPrimary,
                                          ),
                                        ),
                                        if (emp.branchName != null ||
                                            emp.jobTitle != null)
                                          Text(
                                            [
                                              emp.branchName,
                                              emp.jobTitle,
                                            ].whereType<String>().join(' · '),
                                            style: TextStyle(
                                              fontFamily:
                                                  'IBM Plex Sans Arabic',
                                              fontSize: 11,
                                              color: colors.textTertiary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (emp.shiftName != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.sunken,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.full),
                                      ),
                                      child: Text(
                                        emp.shiftName!,
                                        style: TextStyle(
                                          fontFamily: 'IBM Plex Sans Arabic',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: employees.length,
                  ),
                ),
              if (_selectedIds.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildBottomActions(colors, employees),
                ),
              const SliverPadding(
                  padding: EdgeInsets.only(bottom: AppSpacing.s7)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters(AppColorScheme colors) {
    final visibleShifts = _visibleShifts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_branches.isNotEmpty) ...[
          _ManualLabel(text: 'branch'.tr),
          const SizedBox(height: AppSpacing.s2),
          _ManualDropdown<int?>(
            value: _branchId,
            hint: 'all_branches'.tr,
            icon: Icons.account_tree_outlined,
            items: _branches
                .map((b) => DropdownMenuItem<int?>(
                      value: b.id,
                      child: Text(b.name),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _branchId = v;
              if (_shiftId != null &&
                  !_visibleShifts.any((s) => s.id == _shiftId)) {
                _shiftId = null;
              }
            }),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        if (visibleShifts.isNotEmpty) ...[
          _ManualLabel(text: 'shift'.tr),
          const SizedBox(height: AppSpacing.s2),
          _ManualDropdown<int?>(
            value: _shiftId,
            hint: 'all_shifts'.tr,
            icon: Icons.schedule_outlined,
            items: visibleShifts
                .map((s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.name),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _shiftId = v),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        if (_categories.isNotEmpty) ...[
          _ManualLabel(text: 'category'.tr),
          const SizedBox(height: AppSpacing.s2),
          _ManualDropdown<int?>(
            value: _categoryId,
            hint: 'all_categories'.tr,
            icon: Icons.category_outlined,
            items: _categories
                .map((c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: AppSpacing.s3),
        ],
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() {
                _branchId = null;
                _shiftId = null;
                _categoryId = null;
              }),
              child: Text(
                'clear_filters'.tr,
                style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectAllBar(
      AppColorScheme colors, List<EmployeeModel> visible) {
    final visibleIds = visible.map((e) => e.id).toSet();
    final allSelected = visibleIds.isNotEmpty &&
        visibleIds.every((id) => _selectedIds.contains(id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s2,
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => setState(() {
              if (allSelected) {
                _selectedIds.removeAll(visibleIds);
              } else {
                _selectedIds.addAll(visibleIds);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: allSelected
                        ? colors.brand
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    'select_all'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${_selectedIds.length} ${'selected_count'.tr}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.brand,
                ),
              ),
            ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.s2),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => setState(() => _selectedIds.clear()),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 16, color: colors.textTertiary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotesField(AppColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: TextField(
        controller: _notesCtrl,
        maxLength: 500,
        maxLines: 2,
        minLines: 1,
        decoration: InputDecoration(
          hintText: 'note_placeholder'.tr,
          hintStyle: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            color: colors.textTertiary,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
            child: Icon(Icons.sticky_note_2_outlined,
                size: 18, color: colors.textSecondary),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 30),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s2,
            vertical: AppSpacing.s2,
          ),
          isDense: true,
        ),
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 13,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBottomActions(
      AppColorScheme colors, List<EmployeeModel> visible) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNotesField(colors),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: colors.borderHairline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: colors.brand),
                        const SizedBox(width: AppSpacing.s2),
                        Text(
                          '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _isCheckOut ? _checkOut : _checkIn,
                    );
                    if (t != null) {
                      setState(() {
                        if (_isCheckOut) {
                          _checkOut = t;
                        } else {
                          _checkIn = t;
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: colors.borderHairline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            _isCheckOut ? Icons.logout : Icons.login,
                            size: 14,
                            color: colors.brand),
                        const SizedBox(width: AppSpacing.s2),
                        Text(
                          _isCheckOut
                              ? '${_checkOut.hour.toString().padLeft(2, '0')}:${_checkOut.minute.toString().padLeft(2, '0')}'
                              : '${_checkIn.hour.toString().padLeft(2, '0')}:${_checkIn.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final selected = _allEmployees
                    .where((e) => _selectedIds.contains(e.id))
                    .toList();
                if (selected.isEmpty) return;
                final notes = _notesCtrl.text.trim();
                Navigator.of(context).pop();
                await widget.ctrl.recordManualAttendanceBatch(
                  employees: selected,
                  date: _date,
                  checkInTime: _isCheckOut ? null : _checkIn,
                  checkOutTime: _isCheckOut ? _checkOut : null,
                  notes: notes.isEmpty ? null : notes,
                );
              },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                child: Text(
                  _selectedIds.length > 1
                      ? '${'save'.tr} (${_selectedIds.length})'
                      : 'save'.tr,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualLabel extends StatelessWidget {
  final String text;
  const _ManualLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'IBM Plex Sans Arabic',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }
}

class _ManualDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _ManualDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.expand_more, size: 18),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                hint: Text(
                  hint,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                items: [
                  DropdownMenuItem<T>(
                    value: null as T,
                    child: Text(hint),
                  ),
                  ...items,
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteEditSheet extends StatefulWidget {
  final AttendanceRecordModel record;
  const _NoteEditSheet({required this.record});

  @override
  State<_NoteEditSheet> createState() => _NoteEditSheetState();
}

class _NoteEditSheetState extends State<_NoteEditSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.record.note ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool clear}) async {
    setState(() => _saving = true);
    final attendanceCtrl = Get.find<AttendanceController>();
    final ok = await attendanceCtrl.updateAttendanceNote(
      record: widget.record,
      note: clear ? null : _ctrl.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasExisting = (widget.record.note ?? '').trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s3,
          AppSpacing.s4,
          AppSpacing.s5,
        ),
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(
              hasExisting ? 'edit_note'.tr : 'add_note'.tr,
              style: AppTextStyles.h3(context),
            ),
            const SizedBox(height: 2),
            Text(
              widget.record.employeeName ?? '',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.borderHairline),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3,
                vertical: AppSpacing.s2,
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLength: 500,
                maxLines: 4,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'note_placeholder'.tr,
                  hintStyle: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textTertiary,
                  ),
                  border: InputBorder.none,
                  counterStyle: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 10,
                    color: colors.textTertiary,
                  ),
                ),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                if (hasExisting)
                  TextButton.icon(
                    onPressed: _saving ? null : () => _save(clear: true),
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: colors.error),
                    label: Text(
                      'delete_note'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        color: colors.error,
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'cancel'.tr,
                    style:
                        const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                ElevatedButton.icon(
                  onPressed: _saving ? null : () => _save(clear: false),
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(
                    'save'.tr,
                    style:
                        const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
