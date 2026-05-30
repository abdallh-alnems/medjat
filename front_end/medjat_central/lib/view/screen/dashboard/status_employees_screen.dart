import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/live_attendance_model.dart';
import '../../../logic/controller/dashboard/status_employees_controller.dart';

class StatusEmployeesScreen extends StatelessWidget {
  const StatusEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(StatusEmployeesController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(ctrl.title),
        actions: [
          GetBuilder<StatusEmployeesController>(
            builder: (_) {
              final count = ctrl.activeFilterCount;
              return Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: ctrl.hasAnyFilterOptions
                      ? () => _openFilterPanel(context, ctrl)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: count > 0 ? colors.brand : colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: count > 0 ? colors.brand : colors.borderHairline,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.tune,
                            size: 20,
                            color: count > 0 ? Colors.white : colors.textSecondary),
                        if (count > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$count',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Geist',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: colors.brand,
                                  height: 1,
                                ),
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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4, AppSpacing.s2, AppSpacing.s4, AppSpacing.s2),
            child: TextField(
              onChanged: ctrl.onSearch,
              decoration: InputDecoration(
                hintText: 'search_by_name'.tr,
                prefixIcon:
                    Icon(Icons.search, color: colors.textTertiary),
              ),
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 15,
              ),
            ),
          ),
          GetBuilder<StatusEmployeesController>(
            builder: (_) {
              if (ctrl.activeFilterCount == 0) return const SizedBox.shrink();
              return _ActiveFiltersBar(ctrl: ctrl);
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadEmployees,
              child: GetBuilder<StatusEmployeesController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadEmployees,
                    widget: ctrl.filteredEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_employees_found'.tr,
                                    style: AppTextStyles.bodySecondary(context)),
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
                            itemCount: ctrl.filteredEntries.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) =>
                                _StatusEmployeeTile(entry: ctrl.filteredEntries[i]),
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

  void _openFilterPanel(BuildContext context, StatusEmployeesController ctrl) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterPanel(ctrl: ctrl),
    );
  }
}

class _StatusEmployeeTile extends StatelessWidget {
  final LiveAttendanceEntry entry;
  const _StatusEmployeeTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: colors.borderHairline),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
      leading: CircleAvatar(
        backgroundColor: colors.brand.withValues(alpha: 0.12),
        child: Text(
          entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontFamily: 'Geist',
            fontWeight: FontWeight.w700,
            color: colors.brand,
          ),
        ),
      ),
      title: Text(
        entry.name,
        style: const TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.jobTitle != null)
            Text(
              entry.jobTitle!,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          if (entry.branchName != null)
            Text(
              entry.branchName!,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.textTertiary,
              ),
            ),
          if (entry.checkInTime != null)
            Text(
              '${'check_in_label'.tr} ${entry.checkInTime!.substring(0, 5)}'
              '${entry.checkOutTime != null ? "  |  ${'check_out_label'.tr} ${entry.checkOutTime!.substring(0, 5)}" : ""}',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.textTertiary,
              ),
            ),
        ],
      ),
      trailing: _StatusBadge(entry: entry),
      onTap: () => Get.toNamed(
        AppRoutes.employeeDetail.replaceAll(':id', '${entry.employeeId}'),
        arguments: {'id': entry.employeeId},
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LiveAttendanceEntry entry;
  const _StatusBadge({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final (label, color) = _badgeData(colors);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  (String, Color) _badgeData(AppColorScheme colors) {
    if (entry.isLate) return ('status_late'.tr, colors.warning);
    switch (entry.status) {
      case LiveStatus.inside:
        return ('status_present'.tr, colors.success);
      case LiveStatus.out:
        return ('status_out'.tr, colors.textSecondary);
      case LiveStatus.notIn:
        return ('status_not_in'.tr, colors.accentWarm);
      case LiveStatus.preShift:
        return ('status_pre_shift'.tr, colors.textTertiary);
      case LiveStatus.absent:
        return ('status_absent'.tr, colors.error);
      case LiveStatus.leave:
        return (_leaveLabel(entry), colors.accentWarm);
      case LiveStatus.unknown:
        return ('unknown'.tr, colors.textTertiary);
    }
  }

  static String _leaveLabel(LiveAttendanceEntry entry) {
    if (entry.attendanceStatus == 'holiday') return 'status_holiday'.tr;
    if (entry.attendanceStatus == 'weekly_off') return 'status_weekly_off'.tr;
    final reason = entry.leaveReason?.trim();
    if (reason != null && reason.isNotEmpty) return reason;
    return 'status_leave'.tr;
  }
}

class _FilterPanel extends StatefulWidget {
  final StatusEmployeesController ctrl;
  const _FilterPanel({required this.ctrl});

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late int? _branchId = widget.ctrl.selectedBranchId;
  late int? _shiftId = widget.ctrl.selectedShiftId;
  late int? _categoryId = widget.ctrl.selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ctrl = widget.ctrl;
    final shifts = ctrl.shiftsForBranch(_branchId);

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
          if (ctrl.branches.isNotEmpty) ...[
            _PanelLabel(text: 'branch'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _branchId,
              hint: 'all_branches'.tr,
              icon: Icons.account_tree_outlined,
              items: ctrl.branches.map((b) {
                final id = (b['id'] as num?)?.toInt();
                return DropdownMenuItem<int?>(
                  value: id,
                  child: Text((b['name'] as String?) ?? ''),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                _branchId = v;
                if (_shiftId != null &&
                    !ctrl.shiftsForBranch(v).any((s) => s.id == _shiftId)) {
                  _shiftId = null;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (shifts.isNotEmpty) ...[
            _PanelLabel(text: 'shift'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _shiftId,
              hint: 'all_shifts'.tr,
              icon: Icons.schedule_outlined,
              items: shifts
                  .map((s) => DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text(s.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _shiftId = v),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (ctrl.categories.isNotEmpty) ...[
            _PanelLabel(text: 'category'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _categoryId,
              hint: 'all_categories'.tr,
              icon: Icons.category_outlined,
              items: ctrl.categories
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
                  child: Text('clear_filters'.tr,
                      style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic')),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ctrl.applyFilters(
                      branchId: _branchId,
                      shiftId: _shiftId,
                      categoryId: _categoryId,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text('apply'.tr,
                      style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelLabel extends StatelessWidget {
  final String text;
  const _PanelLabel({required this.text});

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
  final T value;
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
                hint: Text(hint,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      color: colors.textSecondary,
                    )),
                items: [
                  DropdownMenuItem<T>(
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

class _ActiveFiltersBar extends StatelessWidget {
  final StatusEmployeesController ctrl;
  const _ActiveFiltersBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chips = <Widget>[];

    if (ctrl.selectedBranchId != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.branchName(ctrl.selectedBranchId) ?? '',
        onRemove: () => ctrl.applyFilters(
          shiftId: ctrl.selectedShiftId,
          categoryId: ctrl.selectedCategoryId,
        ),
      ));
    }
    if (ctrl.selectedShiftId != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.shiftName(ctrl.selectedShiftId) ?? '',
        onRemove: () => ctrl.applyFilters(
          branchId: ctrl.selectedBranchId,
          categoryId: ctrl.selectedCategoryId,
        ),
      ));
    }
    if (ctrl.selectedCategoryId != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.categoryName(ctrl.selectedCategoryId) ?? '',
        onRemove: () => ctrl.applyFilters(
          branchId: ctrl.selectedBranchId,
          shiftId: ctrl.selectedShiftId,
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Wrap(
        spacing: AppSpacing.s2,
        runSpacing: AppSpacing.s1,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton(
            onPressed: ctrl.clearFilters,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('clear_filters'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                )),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required VoidCallback onRemove,
  }) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.only(
          left: AppSpacing.s3, right: AppSpacing.s2, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.brand.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Icon(Icons.close, size: 14, color: colors.brand),
          ),
        ],
      ),
    );
  }
}
