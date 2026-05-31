import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/employee/employee_controller.dart';
import '../../widget/employee/employee_card.dart';

class EmployeesScreen extends StatelessWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployeeController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('employees'.tr),
        actions: [
          GetBuilder<EmployeeController>(
            builder: (_) => PopupMenuButton<String>(
              icon: const Icon(Icons.swap_vert),
              tooltip: 'sort_by'.tr,
              onSelected: ctrl.setSort,
              itemBuilder: (_) => EmployeeController.sortOptions
                  .map((s) => CheckedPopupMenuItem<String>(
                        value: s,
                        checked: ctrl.sortBy == s,
                        child: Text(_sortLabel(s)),
                      ))
                  .toList(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showFilterSheet(context, ctrl),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_employees',
        onPressed: () async {
          final result = await Get.toNamed(AppRoutes.employeeAdd);
          if (result == true) {
            ctrl.loadEmployees();
          }
        },
        backgroundColor: AppColors.of(context).brand,
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
      body: Column(
        children: [
          GetBuilder<EmployeeController>(
            builder: (_) => _StatsHeader(ctrl: ctrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4, AppSpacing.s2, AppSpacing.s4, AppSpacing.s2),
            child: TextField(
              onChanged: ctrl.onSearch,
              decoration: InputDecoration(
                hintText: 'search_employee'.tr,
                prefixIcon: Icon(Icons.search,
                    color: AppColors.of(context).textTertiary),
              ),
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 15,
              ),
            ),
          ),
          GetBuilder<EmployeeController>(
            builder: (_) {
              if (!ctrl.hasActiveFilters) return const SizedBox.shrink();
              return _ActiveFiltersBar(ctrl: ctrl);
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadEmployees,
              child: GetBuilder<EmployeeController>(
                builder: (_) {
                  // Skeleton while the first page loads; the spinner is only
                  // for refreshes once data already exists.
                  if (ctrl.status == StatusRequest.loading &&
                      ctrl.employees.isEmpty) {
                    return const _EmployeesSkeleton();
                  }
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadEmployees,
                    widget: ctrl.employees.isEmpty
                        ? _EmptyEmployees(ctrl: ctrl)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              0,
                              AppSpacing.s4,
                              AppSpacing.s7,
                            ),
                            itemCount: ctrl.employees.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s3),
                            itemBuilder: (_, i) => EmployeeCard(
                              employee: ctrl.employees[i],
                              onTap: () => Get.toNamed(
                                AppRoutes.employeeDetail
                                    .replaceAll(':id', '${ctrl.employees[i].id}'),
                                arguments: {'id': ctrl.employees[i].id},
                              ),
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

  void _showFilterSheet(BuildContext context, EmployeeController ctrl) {
    int? _branch = ctrl.branchFilter;
    int? _shift = ctrl.shiftFilter;
    int? _category = ctrl.categoryFilter;
    String? _status = ctrl.statusFilter;
    int? _expiring = ctrl.expiringFilter;

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = AppColors.of(context);
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
                  Row(
                    children: [
                      Text('filter'.tr, style: AppTextStyles.h3(context)),
                      const Spacer(),
                      if (ctrl.hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _branch = null;
                              _shift = null;
                              _category = null;
                              _status = null;
                              _expiring = null;
                            });
                          },
                          child: Text('clear_all'.tr),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _FilterLabel(text: 'employment_status'.tr),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s1,
                    children: EmployeeController.filterableStatuses.map((s) {
                      final selected = _status == s;
                      return ChoiceChip(
                        label: Text(
                          ctrl.statusLabel(s),
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            color: selected
                                ? AppColors.of(context).brand
                                : AppColors.of(context).textSecondary,
                          ),
                        ),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) =>
                            setSheetState(() => _status = selected ? null : s),
                        selectedColor:
                            AppColors.of(context).brand.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: selected
                              ? AppColors.of(context).brand
                              : AppColors.of(context).borderHairline,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  _FilterLabel(text: 'expiring_documents'.tr),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s1,
                    children: EmployeeController.expiringWindows.map((d) {
                      final selected = _expiring == d;
                      return ChoiceChip(
                        label: Text(
                          '${'within'.tr} $d ${'days_unit'.tr}',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            color: selected
                                ? AppColors.of(context).warning
                                : AppColors.of(context).textSecondary,
                          ),
                        ),
                        selected: selected,
                        showCheckmark: false,
                        avatar: Icon(Icons.event_busy_outlined,
                            size: 16,
                            color: selected
                                ? AppColors.of(context).warning
                                : AppColors.of(context).textTertiary),
                        onSelected: (_) =>
                            setSheetState(() => _expiring = selected ? null : d),
                        selectedColor: AppColors.of(context)
                            .warning
                            .withValues(alpha: 0.14),
                        side: BorderSide(
                          color: selected
                              ? AppColors.of(context).warning
                              : AppColors.of(context).borderHairline,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  if (ctrl.branches.isNotEmpty) ...[
                    _FilterLabel(text: 'branch'.tr),
                    const SizedBox(height: AppSpacing.s2),
                    _FilterDropdown(
                      value: _branch,
                      hint: 'all_branches'.tr,
                      items: ctrl.branches
                          .map((b) => DropdownMenuItem<int?>(
                                value: b.id,
                                child: Text(b.name,
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 14,
                                    )),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => _branch = v),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                  ],
                  if (ctrl.shifts.isNotEmpty) ...[
                    _FilterLabel(text: 'shift'.tr),
                    const SizedBox(height: AppSpacing.s2),
                    _FilterDropdown(
                      value: _shift,
                      hint: 'all_shifts'.tr,
                      items: ctrl.shifts
                          .map((s) => DropdownMenuItem<int?>(
                                value: s.id,
                                child: Text(
                                    '${s.name} (${s.startTime.substring(0, 5)} - ${s.endTime.substring(0, 5)})',
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 14,
                                    )),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => _shift = v),
                    ),
                    const SizedBox(height: AppSpacing.s3),
                  ],
                  if (ctrl.categories.isNotEmpty) ...[
                    _FilterLabel(text: 'employee_categories'.tr),
                    const SizedBox(height: AppSpacing.s2),
                    _FilterDropdown(
                      value: _category,
                      hint: 'all_categories'.tr,
                      items: ctrl.categories
                          .map((c) => DropdownMenuItem<int?>(
                                value: c.id,
                                child: Text(c.name,
                                    style: const TextStyle(
                                      fontFamily: 'IBM Plex Sans Arabic',
                                      fontSize: 14,
                                    )),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => _category = v),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                  ],
                  const SizedBox(height: AppSpacing.s2),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ctrl.applyFilters(
                          branchId: _branch,
                          shiftId: _shift,
                          categoryId: _category,
                          status: _status,
                          expiringWithin: _expiring,
                        );
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text('apply_filter'.tr),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
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

/// Clickable headcount chips (Total / Active / On-leave / Pending) that drive
/// the status filter. Hidden until the first load populates the counts.
class _StatsHeader extends StatelessWidget {
  final EmployeeController ctrl;
  const _StatsHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final counts = ctrl.statusCounts;
    if ((counts['total'] ?? 0) == 0 && !ctrl.hasActiveFilters) {
      return const SizedBox.shrink();
    }
    final colors = AppColors.of(context);

    final items = <({String? key, String label, int count, Color color})>[
      (
        key: null,
        label: 'total_employees'.tr,
        count: counts['total'] ?? 0,
        color: colors.brand
      ),
      (
        key: 'active',
        label: 'employee_active'.tr,
        count: counts['active'] ?? 0,
        color: colors.success
      ),
      (
        key: 'on_leave',
        label: 'employee_on_leave'.tr,
        count: counts['on_leave'] ?? 0,
        color: colors.accentWarm
      ),
      (
        key: 'pending_activation',
        label: 'pending_activation'.tr,
        count: counts['pending_activation'] ?? 0,
        color: colors.warning
      ),
    ];

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, AppSpacing.s2, AppSpacing.s4, 0),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s2),
        itemBuilder: (_, i) {
          final it = items[i];
          final selected = it.key == null
              ? ctrl.statusFilter == null
              : ctrl.statusFilter == it.key;
          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => ctrl.selectStatus(it.key),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
              decoration: BoxDecoration(
                color: selected
                    ? it.color.withValues(alpha: 0.12)
                    : colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: selected ? it.color : colors.borderHairline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${it.count}',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: it.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    it.label,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected ? it.color : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pulsing placeholder list shown while the first page loads.
class _EmployeesSkeleton extends StatefulWidget {
  const _EmployeesSkeleton();

  @override
  State<_EmployeesSkeleton> createState() => _EmployeesSkeletonState();
}

class _EmployeesSkeletonState extends State<_EmployeesSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s7),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
      itemBuilder: (_, __) => FadeTransition(
        opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Row(
            children: [
              _bone(colors, width: 48, height: 48, radius: AppRadius.full),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bone(colors, width: 140, height: 13),
                    const SizedBox(height: 8),
                    _bone(colors, width: 90, height: 11),
                  ],
                ),
              ),
              _bone(colors, width: 52, height: 18, radius: AppRadius.full),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bone(AppColorScheme colors,
      {required double width, required double height, double radius = 4}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

String _sortLabel(String sort) {
  switch (sort) {
    case 'name':
      return 'sort_by_name'.tr;
    case 'hire_date':
      return 'sort_by_hire_date'.tr;
    case 'status':
      return 'sort_by_status'.tr;
    default:
      return sort;
  }
}

/// Empty list state. Shows a "clear filters" action when a search/filter is
/// narrowing the results, otherwise a primary CTA to add the first employee.
class _EmptyEmployees extends StatelessWidget {
  final EmployeeController ctrl;
  const _EmptyEmployees({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isFiltered = ctrl.hasActiveFilters || ctrl.searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFiltered ? Icons.search_off_outlined : Icons.group_off_outlined,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              isFiltered ? 'no_matching_employees'.tr : 'no_employees'.tr,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context),
            ),
            const SizedBox(height: AppSpacing.s4),
            if (isFiltered)
              OutlinedButton.icon(
                onPressed: ctrl.clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text('clear_all'.tr),
              )
            else
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Get.toNamed(AppRoutes.employeeAdd);
                  if (result == true) ctrl.loadEmployees();
                },
                icon: const Icon(Icons.person_add_outlined,
                    size: 18, color: Colors.white),
                label: Text('add_first_employee'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveFiltersBar extends StatelessWidget {
  final EmployeeController ctrl;
  const _ActiveFiltersBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chips = <Widget>[];

    if (ctrl.statusFilter != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.statusLabel(ctrl.statusFilter!),
        color: colors.brand,
        onRemove: () => ctrl.applyFilters(
          branchId: ctrl.branchFilter,
          shiftId: ctrl.shiftFilter,
          categoryId: ctrl.categoryFilter,
          status: null,
          expiringWithin: ctrl.expiringFilter,
        ),
      ));
    }
    if (ctrl.expiringFilter != null) {
      chips.add(_filterChip(
        context,
        label: '${'expiring_documents'.tr} • ${ctrl.expiringFilter}'
            ' ${'days_unit'.tr}',
        color: colors.warning,
        onRemove: () => ctrl.applyFilters(
          branchId: ctrl.branchFilter,
          shiftId: ctrl.shiftFilter,
          categoryId: ctrl.categoryFilter,
          status: ctrl.statusFilter,
          expiringWithin: null,
        ),
      ));
    }
    if (ctrl.branchFilter != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.branchName(ctrl.branchFilter) ?? '',
        color: colors.brand,
        onRemove: () => ctrl.applyFilters(
          branchId: null,
          shiftId: ctrl.shiftFilter,
          categoryId: ctrl.categoryFilter,
          status: ctrl.statusFilter,
          expiringWithin: ctrl.expiringFilter,
        ),
      ));
    }
    if (ctrl.shiftFilter != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.shiftName(ctrl.shiftFilter) ?? '',
        color: colors.brand,
        onRemove: () => ctrl.applyFilters(
          branchId: ctrl.branchFilter,
          shiftId: null,
          categoryId: ctrl.categoryFilter,
          status: ctrl.statusFilter,
          expiringWithin: ctrl.expiringFilter,
        ),
      ));
    }
    if (ctrl.categoryFilter != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.categoryName(ctrl.categoryFilter) ?? '',
        color: colors.brand,
        onRemove: () => ctrl.applyFilters(
          branchId: ctrl.branchFilter,
          shiftId: ctrl.shiftFilter,
          categoryId: null,
          status: ctrl.statusFilter,
          expiringWithin: ctrl.expiringFilter,
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Wrap(
        spacing: AppSpacing.s2,
        runSpacing: AppSpacing.s1,
        children: chips,
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required Color color,
    required VoidCallback onRemove,
  }) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      deleteIcon: Icon(Icons.close, size: 16, color: color),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
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
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final int? value;
  final String hint;
  final List<DropdownMenuItem<int?>> items;
  final ValueChanged<int?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
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
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          hint: Text(hint,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textSecondary,
              )),
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(hint,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    color: colors.textTertiary,
                  )),
            ),
            ...items,
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
