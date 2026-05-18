import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/plan_model.dart';
import '../../../logic/controller/plan/plan_controller.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الباقات')),
      body: GetBuilder<PlanController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status.value,
            onRetry: () => controller.loadPlans(),
            widget: RefreshIndicator(
              onRefresh: () => controller.loadPlans(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                itemCount: controller.plans.length,
                itemBuilder: (context, index) {
                  return _PlanCard(plan: controller.plans[index]);
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final priceCtl = TextEditingController();
    final maxEmpCtl = TextEditingController(text: '10');
    final maxBranchCtl = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إنشاء باقة جديدة', style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'اسم الباقة'),
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: priceCtl,
                decoration: const InputDecoration(labelText: 'السعر الشهري (جنيه)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: maxEmpCtl,
                decoration: const InputDecoration(labelText: 'الحد الأقصى للموظفين'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: maxBranchCtl,
                decoration: const InputDecoration(labelText: 'الحد الأقصى للفروع'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Get.find<PlanController>().createPlan(
                      name: nameCtl.text.trim(),
                      price: double.tryParse(priceCtl.text) ?? 0,
                      maxEmployees: int.tryParse(maxEmpCtl.text) ?? 10,
                      maxBranches: int.tryParse(maxBranchCtl.text) ?? 1,
                    );
                    Get.back();
                  }
                },
                child: const Text('إنشاء'),
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanModel plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
          border: Border.all(color: colors.borderHairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${plan.price.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.people_outline, size: 16, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text('حتى ${plan.maxEmployees} موظف', style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13, color: colors.textSecondary)),
              const SizedBox(width: AppSpacing.s4),
              Icon(Icons.business_outlined, size: 16, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text('${plan.maxBranches} ${plan.maxBranches == 1 ? 'فرع' : 'فروع'}', style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13, color: colors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
