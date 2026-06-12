import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/category/category_employees_controller.dart';
import '../../widget/employee/employee_card.dart';

/// Lists the employees that belong to a single category. Reached by tapping a
/// category tile in [CategoriesScreen].
class CategoryEmployeesScreen extends StatelessWidget {
  const CategoryEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<CategoryEmployeesController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ctrl.categoryName.isNotEmpty
              ? ctrl.categoryName
              : 'employee_categories'.tr,
        ),
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadEmployees,
              child: GetBuilder<CategoryEmployeesController>(
                builder: (_) {
                  if (ctrl.permissionDenied) {
                    return _PermissionDenied();
                  }
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadEmployees,
                    widget: ctrl.employees.isEmpty
                        ? _EmptyState(ctrl: ctrl)
                        : _EmployeeList(ctrl: ctrl),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  final CategoryEmployeesController ctrl;
  const _EmployeeList({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // +1 row for the bottom loader/sentinel when more pages may exist.
    final showFooter = ctrl.hasMore || ctrl.isLoadingMore;
    final itemCount = ctrl.employees.length + (showFooter ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 300) {
          ctrl.loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          0,
          AppSpacing.s4,
          AppSpacing.s7,
        ),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s3),
        itemBuilder: (_, i) {
          if (i >= ctrl.employees.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final emp = ctrl.employees[i];
          return EmployeeCard(
            employee: emp,
            onTap: () => Get.toNamed<void>(
              AppRoutes.employeeDetail.replaceAll(':id', '${emp.id}'),
              arguments: {'id': emp.id},
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final CategoryEmployeesController ctrl;
  const _EmptyState({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isSearching = ctrl.searchQuery.isNotEmpty;

    return ListView(
      // Keep it scrollable so RefreshIndicator still works when empty.
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(
          isSearching ? Icons.search_off_outlined : Icons.group_off_outlined,
          size: 48,
          color: colors.textTertiary,
        ),
        const SizedBox(height: AppSpacing.s3),
        Center(
          child: Text(
            isSearching ? 'no_matching_employees'.tr : 'no_employees'.tr,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary(context),
          ),
        ),
      ],
    );
  }
}

/// Shown when the user can open the category list but lacks the
/// `manage_employees` permission the employee endpoint requires (403).
class _PermissionDenied extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Icon(Icons.lock_outline, size: 48, color: colors.textTertiary),
        const SizedBox(height: AppSpacing.s3),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
            child: Text(
              'no_permission_view_employees'.tr,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}
