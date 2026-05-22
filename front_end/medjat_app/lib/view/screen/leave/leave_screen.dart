import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/leave/leave_controller.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => LeaveController());
    return Scaffold(
      appBar: AppBar(title: const Text('الإجازات')),
      body: GetBuilder<LeaveController>(
        builder: (controller) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _balanceSection(context, controller),
                const SizedBox(height: 24),
                _applyForm(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _balanceSection(BuildContext context, LeaveController controller) {
    final balance = controller.balance;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('رصيد الإجازات', style: AppTextStyles.h3(context)),
          const SizedBox(height: 12),
          if (balance != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(context, 'الرصيد', balance['total_days']?.toString() ?? '0'),
                _statItem(context, 'المستخدم', balance['used_days']?.toString() ?? '0'),
                _statItem(context, 'المتبقي', balance['remaining_days']?.toString() ?? '0'),
              ],
            )
          else
            Text('جاري التحميل...', style: AppTextStyles.bodySecondary(context)),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.h2(context)),
        Text(label, style: AppTextStyles.xs(context)),
      ],
    );
  }

  Widget _applyForm(BuildContext context, LeaveController controller) {
    final dateController = TextEditingController();
    final reasonController = TextEditingController();
    String selectedType = 'annual';

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تقديم إجازة', style: AppTextStyles.h3(context)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'نوع الإجازة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'annual', child: Text('سنوية')),
                DropdownMenuItem(value: 'sick', child: Text('مرضية')),
                DropdownMenuItem(value: 'personal', child: Text('شخصية')),
                DropdownMenuItem(value: 'unpaid', child: Text('بدون راتب')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => selectedType = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'التاريخ',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  dateController.text =
                      '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'السبب (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GetBuilder<LeaveController>(
              builder: (ctrl) {
                return PrimaryButton(
                  text: 'تقديم الطلب',
                  isLoading: ctrl.applyStatus == StatusRequest.loading,
                  onPressed: () {
                    if (dateController.text.isEmpty) {
                      Get.snackbar('خطأ', 'اختر التاريخ',
                          snackPosition: SnackPosition.BOTTOM);
                      return;
                    }
                    ctrl.applyLeave(
                      date: dateController.text,
                      type: selectedType,
                      reason: reasonController.text.isEmpty
                          ? null
                          : reasonController.text,
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
