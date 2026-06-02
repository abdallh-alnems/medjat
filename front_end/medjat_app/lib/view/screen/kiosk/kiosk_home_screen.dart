import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../data/model/station_model.dart';
import '../../../../logic/controller/station/station_controller.dart';

class KioskHomeScreen extends StatelessWidget {
  const KioskHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StationController>();

    return Scaffold(
      body: SafeArea(
        child: PopScope(
          canPop: false,
          child: Column(
            children: [
              _buildAppBar(context, controller),
              Expanded(
                child: Obx(() {
                  if (controller.isLocked.value) {
                    return _buildLockedBanner(context);
                  }
                  return _buildEmployeeGrid(context, controller);
                }),
              ),
              _buildLastCheckIn(context, controller),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, StationController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand(context).withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: AppColors.brand(context))),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor, color: AppColors.brand(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() => Text(
                  controller.station?.branchName ?? 'كيوسك',
                  style: AppTextStyles.h3(context),
                )),
          ),
          TextButton.icon(
            onPressed: () => _showExitDialog(context, controller),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.red.shade700),
          const SizedBox(height: 16),
          Text('الكيوسك مقفل', style: AppTextStyles.h2(context)),
          const SizedBox(height: 8),
          Text(
            'تم إيقاف الكيوسك بسبب الخروج من النطاق المسموح',
            style: AppTextStyles.bodySecondary(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeGrid(BuildContext context, StationController controller) {
    return Obx(() {
      final employees = controller.employees;
      if (employees.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('جاري تحميل الموظفين...',
                  style: AppTextStyles.bodySecondary(context)),
            ],
          ),
        );
      }

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: employees.length,
        itemBuilder: (context, index) {
          final emp = employees[index];
          return _EmployeeCard(
            employee: emp,
            onTap: () => _handleCheckIn(context, controller, emp),
          );
        },
      );
    });
  }

  void _handleCheckIn(
    BuildContext context,
    StationController controller,
    BranchEmployee employee,
  ) {
    controller.checkInOut(
      employeeId: employee.id,
      method: 'fingerprint',
    );
  }

  Widget _buildLastCheckIn(BuildContext context, StationController controller) {
    return Obx(() {
      final result = controller.lastCheckIn;
      if (result == null) return const SizedBox.shrink();

      final isIn = result.action == 'check_in';
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isIn ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isIn ? Colors.green.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isIn ? Icons.login : Icons.logout,
              color: isIn ? Colors.green.shade700 : Colors.orange.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.employeeName,
                    style: AppTextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isIn ? 'تم تسجيل الحضور' : 'تم تسجيل الانصراف',
                    style: AppTextStyles.sm(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showExitDialog(BuildContext context, StationController controller) {
    final pinController = TextEditingController();

    Get.dialog<void>(
      AlertDialog(
        title: const Text('خروج من الكيوسك'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل رمز المدير للخروج'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'رمز المدير',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Get.back<void>();
              controller.exitKiosk(pinController.text);
            },
            child: Text('خروج', style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final BranchEmployee employee;
  final VoidCallback onTap;

  const _EmployeeCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.of(context).borderHairline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                employee.name.isNotEmpty ? employee.name[0] : '?',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              employee.name,
              style: AppTextStyles.sm(context),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (employee.jobTitle != null)
              Text(
                employee.jobTitle!,
                style: AppTextStyles.xs(context).copyWith(
                  color: AppColors.textTertiary(context),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
