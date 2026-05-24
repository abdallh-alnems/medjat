import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
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
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadEmployees,
                    widget: ctrl.employees.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off_outlined,
                                    size: 48,
                                    color: AppColors.of(context).textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_employees'.tr,
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
                            });
                          },
                          child: Text('clear_all'.tr),
                        ),
                    ],
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

class _ActiveFiltersBar extends StatelessWidget {
  final EmployeeController ctrl;
  const _ActiveFiltersBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chips = <Widget>[];

    if (ctrl.branchFilter != null) {
      chips.add(_filterChip(
        context,
        label: ctrl.branchName(ctrl.branchFilter) ?? '',
        color: colors.brand,
        onRemove: () => ctrl.applyFilters(
          branchId: null,
          shiftId: ctrl.shiftFilter,
          categoryId: ctrl.categoryFilter,
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
