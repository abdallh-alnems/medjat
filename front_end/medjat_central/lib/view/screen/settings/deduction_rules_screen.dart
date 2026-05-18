import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/deduction_rules_controller.dart';
import '../../../data/model/deduction_rule_model.dart';

class DeductionRulesScreen extends StatelessWidget {
  const DeductionRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DeductionRulesController());

    return Scaffold(
      appBar: AppBar(title: Text('deduction_rules'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_deduction_rules',
        onPressed: () => _showAddRuleSheet(context, ctrl),
        backgroundColor: AppColors.of(context).brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.loadRules,
        child: GetBuilder<DeductionRulesController>(
          builder: (_) {
            return HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadRules,
              widget: ctrl.rules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune_outlined,
                              size: 48,
                              color: AppColors.of(context).textTertiary),
                          const SizedBox(height: AppSpacing.s3),
                          Text('no_rules'.tr,
                              style: AppTextStyles.bodySecondary(context)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4,
                        AppSpacing.s4,
                        AppSpacing.s4,
                        AppSpacing.s9,
                      ),
                      itemCount: ctrl.rules.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s2),
                      itemBuilder: (_, i) => _RuleTile(
                        rule: ctrl.rules[i],
                        onEdit: () =>
                            _showEditRuleSheet(context, ctrl, ctrl.rules[i]),
                        onDelete: () => _confirmDelete(context, ctrl, ctrl.rules[i]),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  void _showAddRuleSheet(BuildContext context, DeductionRulesController ctrl) {
    _showRuleSheet(context, ctrl, title: 'add_rule'.tr);
  }

  void _showEditRuleSheet(
      BuildContext context, DeductionRulesController ctrl, DeductionRuleModel rule) {
    _showRuleSheet(context, ctrl, title: 'edit_rule'.tr, rule: rule);
  }

  void _showRuleSheet(
    BuildContext context, DeductionRulesController ctrl, {
    required String title,
    DeductionRuleModel? rule,
  }) {
    final nameCtrl = TextEditingController(text: rule?.name ?? '');
    final valueCtrl =
        TextEditingController(text: rule != null ? rule.value.toString() : '');
    String selectedType = rule?.type ?? 'late_proportional';
    String selectedUnit = rule?.unit ?? 'fixed';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h3(context)),
              const SizedBox(height: AppSpacing.s4),
              PrimaryInput(
                label: 'rule_name'.tr,
                controller: nameCtrl,
                hint: 'rule_name'.tr,
              ),
              const SizedBox(height: AppSpacing.s3),
              Text('type'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.of(context).textSecondary,
                  )),
              const SizedBox(height: AppSpacing.s2),
              StatefulBuilder(
                builder: (context, setState) {
                  return Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      _TypeChip(
                        label: 'late_proportional'.tr,
                        selected: selectedType == 'late_proportional',
                        onTap: () => setState(() => selectedType = 'late_proportional'),
                      ),
                      _TypeChip(
                        label: 'late_fixed'.tr,
                        selected: selectedType == 'late_fixed',
                        onTap: () => setState(() => selectedType = 'late_fixed'),
                      ),
                      _TypeChip(
                        label: 'absence_type'.tr,
                        selected: selectedType == 'absence',
                        onTap: () => setState(() => selectedType = 'absence'),
                      ),
                      _TypeChip(
                        label: 'custom'.tr,
                        selected: selectedType == 'custom',
                        onTap: () => setState(() => selectedType = 'custom'),
                      ),
                      _TypeChip(
                        label: 'overtime'.tr,
                        selected: selectedType == 'overtime_hourly',
                        onTap: () =>
                            setState(() => selectedType = 'overtime_hourly'),
                      ),
                      _TypeChip(
                        label: 'bonus'.tr,
                        selected: selectedType == 'bonus_fixed',
                        onTap: () => setState(() => selectedType = 'bonus_fixed'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s3),
              PrimaryInput(
                label: 'value'.tr,
                controller: valueCtrl,
                keyboardType: TextInputType.number,
                hint: '0.00',
              ),
              const SizedBox(height: AppSpacing.s4),
              PrimaryButton(
                text: rule != null ? 'update'.tr : 'add'.tr,
                onPressed: () {
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'type': selectedType,
                    'value': double.tryParse(valueCtrl.text.trim()) ?? 0,
                    'unit': selectedUnit,
                  };
                  if (rule != null) {
                    ctrl.updateRule(rule.id, data);
                  } else {
                    ctrl.createRule(data);
                  }
                  Get.back();
                },
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, DeductionRulesController ctrl, DeductionRuleModel rule) {
    Get.dialog(
      AlertDialog(
        title: Text('delete_rule'.tr),
        content: Text('${'confirm_delete'.tr} "${rule.name}"؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () {
              Get.back();
              ctrl.deleteRule(rule.id);
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.of(context).error),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final DeductionRuleModel rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleTile({
    required this.rule,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      rule.typeLabel,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Text(
                      rule.value.toStringAsFixed(2),
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
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
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
