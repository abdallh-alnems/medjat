import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/schedule_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../logic/controller/schedule/schedule_controller.dart';

class WeeklyScheduleScreen extends StatelessWidget {
  const WeeklyScheduleScreen({super.key});

  static const double _nameColWidth = 124;
  static const double _dayColWidth = 92;
  static const double _rowHeight = 64;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ScheduleController>();
    final colors = AppColors.of(context);
    final selected = <int>{}.obs;

    return Scaffold(
      appBar: AppBar(
        title: Text('weekly_schedule'.tr),
        actions: [
          GetBuilder<ScheduleController>(
            builder: (_) => TextButton(
              onPressed: ctrl.busy
                  ? null
                  : () => _confirmPublish(context, ctrl),
              child: Text(
                'publish'.tr,
                style: TextStyle(
                  color: ctrl.hasDraftCells
                      ? colors.brand
                      : colors.textTertiary,
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GetBuilder<ScheduleController>(
        builder: (_) {
          return Column(
            children: [
              _weekBar(context, ctrl),
              const Divider(height: 1),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: ctrl.status,
                  onRetry: ctrl.loadWeek,
                  widget: ctrl.employees.isEmpty
                      ? _emptyState(context)
                      : _grid(context, ctrl, selected),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Obx(
        () => selected.isEmpty
            ? const SizedBox.shrink()
            : _bulkBar(context, ctrl, selected),
      ),
    );
  }

  // ── week navigation + copy ──

  Widget _weekBar(BuildContext context, ScheduleController ctrl) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: ctrl.busy ? null : ctrl.previousWeek,
            tooltip: 'previous'.tr,
          ),
          Expanded(
            child: Text(
              '${_d(ctrl.weekStartStr)} – ${_d(ctrl.weekEndStr)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: ctrl.busy ? null : ctrl.nextWeek,
            tooltip: 'next'.tr,
          ),
          TextButton.icon(
            onPressed: ctrl.busy ? null : () => _copyPrevious(context, ctrl),
            icon: Icon(Icons.copy_all_outlined, size: 18, color: colors.brand),
            label: Text(
              'copy_previous_week'.tr,
              style: TextStyle(color: colors.brand, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── the grid ──

  Widget _grid(
    BuildContext context,
    ScheduleController ctrl,
    RxSet<int> selected,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: _nameColWidth + _dayColWidth * 7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(context, ctrl),
            Expanded(
              child: ListView.builder(
                itemCount: ctrl.employees.length,
                itemBuilder: (_, i) =>
                    _employeeRow(context, ctrl, ctrl.employees[i], selected),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context, ScheduleController ctrl) {
    final colors = AppColors.of(context);
    return Container(
      height: 44,
      color: colors.surface,
      child: Row(
        children: [
          SizedBox(width: _nameColWidth, child: _headerCell('employee'.tr)),
          for (final date in ctrl.days)
            SizedBox(width: _dayColWidth, child: _headerCell(_dayLabel(date))),
        ],
      ),
    );
  }

  Widget _headerCell(String text) => Center(
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'IBM Plex Sans Arabic',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _employeeRow(
    BuildContext context,
    ScheduleController ctrl,
    RosterEmployee emp,
    RxSet<int> selected,
  ) {
    final colors = AppColors.of(context);
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderHairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _nameColWidth,
            child: Obx(() {
              final isSel = selected.contains(emp.id);
              return InkWell(
                onTap: () =>
                    isSel ? selected.remove(emp.id) : selected.add(emp.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSel ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 18,
                        color: isSel ? colors.brand : colors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          emp.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          for (final date in ctrl.days)
            SizedBox(
              width: _dayColWidth,
              child: _cell(context, ctrl, emp, date),
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    ScheduleController ctrl,
    RosterEmployee emp,
    String date,
  ) {
    final colors = AppColors.of(context);
    final cell = ctrl.cellFor(emp.id, date);

    // Empty cell: a small centred "add" chip rather than a full-size card.
    if (cell == null) {
      return InkWell(
        onTap: () => _pickCell(context, ctrl, emp, date),
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Icon(Icons.add, size: 16, color: colors.textTertiary),
          ),
        ),
      );
    }

    Widget content;
    if (cell.isRest) {
      content = Text(
        'rest_day'.tr,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 11,
          color: colors.textTertiary,
        ),
      );
    } else {
      final c = cell.color != null ? _hex(cell.color!) : colors.brand;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cell.shiftName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
          if (cell.startTime != null)
            Text(
              '${_t(cell.startTime!)}-${_t(cell.endTime ?? '')}',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 9,
                color: colors.textSecondary,
              ),
            ),
        ],
      );
    }

    final bg = !cell.isRest && cell.color != null
        ? _hex(cell.color!).withValues(alpha: 0.12)
        : colors.surface;

    return InkWell(
      onTap: () => _pickCell(context, ctrl, emp, date),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: cell.isDraft ? colors.brand : colors.borderHairline,
            width: cell.isDraft ? 1.2 : 1,
          ),
        ),
        child: Center(child: content),
      ),
    );
  }

  // ── cell picker ──

  void _pickCell(
    BuildContext context,
    ScheduleController ctrl,
    RosterEmployee emp,
    String date,
  ) {
    final colors = AppColors.of(context);
    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s5),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${emp.name} · ${_dayLabel(date)} ${_d(date)}',
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            ...ctrl.shifts.map(
              (s) => _shiftOption(context, s, () {
                Get.back<void>();
                ctrl.assign(
                  employeeIds: [emp.id],
                  dates: [date],
                  shiftId: s.id,
                );
              }),
            ),
            _plainOption(context, Icons.weekend_outlined, 'rest_day'.tr, () {
              Get.back<void>();
              ctrl.assign(employeeIds: [emp.id], dates: [date]);
            }),
            if (ctrl.cellFor(emp.id, date) != null)
              _plainOption(context, Icons.clear, 'clear'.tr, () {
                Get.back<void>();
                ctrl.clearCell(emp.id, date);
              }, color: colors.error),
          ],
        ),
      ),
    );
  }

  Widget _shiftOption(BuildContext context, ShiftModel s, VoidCallback onTap) {
    final c = s.color != null ? _hex(s.color!) : AppColors.of(context).brand;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      title: Text(
        s.name,
        style: const TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 14,
        ),
      ),
      trailing: Text(
        '${_t(s.startTime)} - ${_t(s.endTime)}',
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 13,
          color: AppColors.of(context).textSecondary,
        ),
      ),
    );
  }

  Widget _plainOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        size: 20,
        color: color ?? AppColors.of(context).textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 14,
          color: color,
        ),
      ),
    );
  }

  // ── bulk assign bar ──

  Widget _bulkBar(
    BuildContext context,
    ScheduleController ctrl,
    RxSet<int> selected,
  ) {
    final colors = AppColors.of(context);
    return Material(
      elevation: 8,
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${selected.length} ${'selected_employees'.tr}',
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => selected.clear(),
                child: Text('cancel'.tr),
              ),
              ElevatedButton.icon(
                onPressed: ctrl.busy
                    ? null
                    : () => _bulkAssignSheet(context, ctrl, selected),
                icon: const Icon(Icons.event_available, size: 18),
                label: Text('assign'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bulkAssignSheet(
    BuildContext context,
    ScheduleController ctrl,
    RxSet<int> selected,
  ) {
    final colors = AppColors.of(context);
    final chosenDays = ctrl.days.toSet().obs; // default: whole week
    final shiftId = Rxn<int>();
    final isRest = false.obs;

    Get.bottomSheet<void>(
      Container(
        padding: EdgeInsets.only(
          left: AppSpacing.s5,
          right: AppSpacing.s5,
          top: AppSpacing.s5,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'assign_to'.tr,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text(
                'select_days'.tr,
                style: AppTextStyles.bodySecondary(context),
              ),
              const SizedBox(height: AppSpacing.s2),
              Obx(
                () => Wrap(
                  spacing: 6,
                  children: ctrl.days.map((d) {
                    final on = chosenDays.contains(d);
                    return FilterChip(
                      label: Text(
                        _dayLabel(d),
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: on,
                      onSelected: (_) =>
                          on ? chosenDays.remove(d) : chosenDays.add(d),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'select_shift'.tr,
                style: AppTextStyles.bodySecondary(context),
              ),
              const SizedBox(height: AppSpacing.s2),
              Obx(
                () => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...ctrl.shifts.map((s) {
                      final on = !isRest.value && shiftId.value == s.id;
                      final c = s.color != null ? _hex(s.color!) : colors.brand;
                      return ChoiceChip(
                        label: Text(
                          s.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: on,
                        avatar: CircleAvatar(backgroundColor: c, radius: 7),
                        onSelected: (_) {
                          isRest.value = false;
                          shiftId.value = s.id;
                        },
                      );
                    }),
                    ChoiceChip(
                      label: Text(
                        'rest_day'.tr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: isRest.value,
                      onSelected: (_) {
                        isRest.value = true;
                        shiftId.value = null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              Obx(
                () => SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        (chosenDays.isEmpty ||
                            (!isRest.value && shiftId.value == null))
                        ? null
                        : () async {
                            Get.back<void>();
                            final ok = await ctrl.assign(
                              employeeIds: selected.toList(),
                              dates: chosenDays.toList(),
                              shiftId: isRest.value ? null : shiftId.value,
                            );
                            if (ok) {
                              selected.clear();
                              Get.snackbar(
                                'done'.tr,
                                'schedule_updated'.tr,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('apply'.tr),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ── actions ──

  void _copyPrevious(BuildContext context, ScheduleController ctrl) {
    Get.dialog<void>(
      AlertDialog(
        title: Text('copy_previous_week'.tr),
        content: Text('copy_previous_week_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              Get.back<void>();
              final ok = await ctrl.copyPreviousWeek();
              Get.snackbar(
                'done'.tr,
                ok ? 'schedule_updated'.tr : 'error'.tr,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text('copy'.tr),
          ),
        ],
      ),
    );
  }

  void _confirmPublish(BuildContext context, ScheduleController ctrl) {
    if (!ctrl.hasDraftCells) {
      Get.snackbar(
        'publish'.tr,
        'nothing_to_publish'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.dialog<void>(
      AlertDialog(
        title: Text('publish'.tr),
        content: Text('publish_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              Get.back<void>();
              final ok = await ctrl.publish();
              Get.snackbar(
                'done'.tr,
                ok ? 'schedule_published'.tr : 'error'.tr,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text('publish'.tr),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 48, color: colors.textTertiary),
          const SizedBox(height: AppSpacing.s3),
          Text('no_employees'.tr, style: AppTextStyles.bodySecondary(context)),
        ],
      ),
    );
  }

  // ── formatting ──

  String _t(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return time;
    return '${parts[0]}:${parts[1]}';
  }

  /// "2026-05-25" -> "25/05"
  String _d(String date) {
    final p = date.split('-');
    if (p.length < 3) return date;
    return '${p[2]}/${p[1]}';
  }

  String _dayLabel(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return '';
    const keys = [
      'd_mon',
      'd_tue',
      'd_wed',
      'd_thu',
      'd_fri',
      'd_sat',
      'd_sun',
    ];
    return keys[d.weekday - 1].tr;
  }

  Color _hex(String hex) {
    final code = hex.replaceAll('#', '');
    return Color(int.parse('FF$code', radix: 16));
  }
}
