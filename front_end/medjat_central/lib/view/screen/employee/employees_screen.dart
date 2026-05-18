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
            icon: const Icon(Icons.filter_list_outlined),
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
            Text('filter'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s4),
            ListTile(
              title: Text('all_branches'.tr),
              onTap: () {
                ctrl.filterByBranch(null);
                Get.back();
              },
            ),
            const Divider(),
            const SizedBox(height: AppSpacing.s3),
          ],
        ),
      ),
    );
  }
}
