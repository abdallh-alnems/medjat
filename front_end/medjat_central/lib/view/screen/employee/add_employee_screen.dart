import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/employee/add_employee_controller.dart';
import '../../../data/model/branch_model.dart';

class AddEmployeeScreen extends StatelessWidget {
  const AddEmployeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AddEmployeeController());

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة موظف')),
      body: Obx(() {
        if (ctrl.status.value == StatusRequest.success &&
            ctrl.activationCode != null) {
          return _ActivationCodeView(ctrl: ctrl);
        }
        return _AddEmployeeForm(ctrl: ctrl);
      }),
    );
  }
}

class _AddEmployeeForm extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _AddEmployeeForm({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final jobTitleCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('البيانات الأساسية', style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s4),
            PrimaryInput(
              label: 'الاسم بالكامل',
              controller: nameCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'رقم الموبايل',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'رقم الموبايل مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'الوظيفة',
              controller: jobTitleCtrl,
              hint: 'مثال: محاسب — مدير مبيعات',
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'الراتب الأساسي',
              controller: salaryCtrl,
              keyboardType: TextInputType.number,
              hint: '0.00',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'الراتب مطلوب' : null,
            ),
            const SizedBox(height: AppSpacing.s3),
            PrimaryInput(
              label: 'البريد الإلكتروني',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              hint: 'optional@company.com',
            ),
            const SizedBox(height: AppSpacing.s4),
            Text('الفرع', style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s3),
            GetBuilder<AddEmployeeController>(
              builder: (_) {
                return _BranchSelector(
                  branches: ctrl.branches,
                  selectedId: ctrl.selectedBranchId,
                  onSelect: (id) {
                    ctrl.selectedBranchId = id;
                    ctrl.update();
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.s6),
            Obx(() => PrimaryButton(
                  text: 'إضافة الموظف',
                  isLoading: ctrl.status.value == StatusRequest.loading,
                  onPressed: () => _submit(ctrl, nameCtrl, phoneCtrl,
                      jobTitleCtrl, salaryCtrl, emailCtrl, formKey),
                )),
            const SizedBox(height: AppSpacing.s5),
          ],
        ),
      ),
    );
  }

  void _submit(
    AddEmployeeController ctrl,
    TextEditingController nameCtrl,
    TextEditingController phoneCtrl,
    TextEditingController jobTitleCtrl,
    TextEditingController salaryCtrl,
    TextEditingController emailCtrl,
    GlobalKey<FormState> formKey,
  ) {
    if (!formKey.currentState!.validate()) return;
    if (ctrl.selectedBranchId == null) {
      Get.snackbar('خطأ', 'يرجى اختيار الفرع',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    ctrl.createEmployee({
      'name': nameCtrl.text.trim(),
      'phone': phoneCtrl.text.trim(),
      'job_title': jobTitleCtrl.text.trim(),
      'base_salary': double.tryParse(salaryCtrl.text.trim()) ?? 0,
      'email': emailCtrl.text.trim(),
      'branch_id': ctrl.selectedBranchId,
    });
  }
}

class _ActivationCodeView extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _ActivationCodeView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(Icons.check_circle_outline,
                size: 36, color: colors.success),
          ),
          const SizedBox(height: AppSpacing.s5),
          Text('تم إضافة الموظف بنجاح', style: AppTextStyles.h2(context)),
          const SizedBox(height: AppSpacing.s6),
          Text('كود التفعيل', style: AppTextStyles.bodySecondary(context)),
          const SizedBox(height: AppSpacing.s3),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.brand, width: 2),
            ),
            child: Text(
              ctrl.activationCode ?? '',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: colors.brand,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'أرسل هذا الكود للموظف — صالح لمدة ٢٤ ساعة',
            style: AppTextStyles.sm(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s5),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: ctrl.activationCode ?? ''));
              Get.snackbar('تم', 'تم نسخ الكود',
                  snackPosition: SnackPosition.BOTTOM);
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('نسخ الكود'),
          ),
          const SizedBox(height: AppSpacing.s5),
          PrimaryButton(
            text: 'تم',
            onPressed: () => Get.back(result: true),
          ),
        ],
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  final List<BranchModel> branches;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const _BranchSelector({
    required this.branches,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (branches.isEmpty) {
      return Text('لا يوجد فروع متاحة', style: AppTextStyles.sm(context));
    }

    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: branches.map((b) {
        final selected = selectedId == b.id;
        return InkWell(
          onTap: () => onSelect(b.id),
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: selected ? colors.brandSubtle : colors.sunken,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: selected ? colors.brand : colors.borderHairline,
              ),
            ),
            child: Text(
              b.name,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: selected ? colors.brand : colors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
