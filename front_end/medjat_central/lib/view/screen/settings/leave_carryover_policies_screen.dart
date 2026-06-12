import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/leave_carryover_policies_controller.dart';

class LeaveCarryoverPoliciesScreen extends StatelessWidget {
  const LeaveCarryoverPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(LeaveCarryoverPoliciesController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('leave_scope_policies_title'.tr)),
      floatingActionButton: GetBuilder<LeaveCarryoverPoliciesController>(
        builder: (_) => FloatingActionButton.extended(
          onPressed: () => _openEditor(context, ctrl),
          icon: const Icon(Icons.add),
          label: Text('leave_policy_add'.tr),
        ),
      ),
      body: GetBuilder<LeaveCarryoverPoliciesController>(
        builder: (_) {
          // Hide the tenant-level row; it is edited on the settings screen.
          final overrides = ctrl.policies
              .where((p) => (p['scope_type'] ?? '') != 'tenant')
              .toList();
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.load,
            widget: overrides.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s6),
                      child: Text('leave_policy_empty'.tr,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.sm(context)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    itemCount: overrides.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.s2),
                    itemBuilder: (_, i) =>
                        _tile(context, colors, ctrl, overrides[i]),
                  ),
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, AppColorScheme colors,
      LeaveCarryoverPoliciesController ctrl, Map<String, dynamic> p) {
    final enabled = (p['carryover_enabled'] ?? 0).toString() == '1';
    final max = p['carryover_max_days'];
    final seniority = p['min_seniority_months'] ?? 0;
    final parts = <String>[
      enabled
          ? 'leave_policy_max_summary'
              .trParams({'max': max?.toString() ?? '∞'})
          : 'leave_carryover_off_hint'.tr,
      if ((seniority is num ? seniority : 0) > 0)
        'leave_policy_seniority_summary'.trParams({'m': seniority.toString()}),
      if (p['expiry_months'] != null)
        'leave_policy_expiry_summary'
            .trParams({'m': p['expiry_months'].toString()}),
      if ((p['encash_excess'] ?? 0).toString() == '1') 'leave_encash_enabled'.tr,
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
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
                Text(ctrl.scopeLabel(p), style: AppTextStyles.body(context)),
                const SizedBox(height: 2),
                Text(parts.join(' • '), style: AppTextStyles.sm(context)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: colors.error),
            onPressed: () => ctrl.deletePolicy((p['id'] as num).toInt()),
          ),
        ],
      ),
    );
  }

  void _openEditor(
      BuildContext context, LeaveCarryoverPoliciesController ctrl) {
    String scopeType = 'branch';
    int? scopeId;
    bool enabled = true;
    bool encash = false;
    final seniorityCtrl = TextEditingController(text: '0');
    final maxCtrl = TextEditingController();
    final expiryCtrl = TextEditingController();
    final legalCtrl = TextEditingController();

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (ctx, setState) {
          final colors = AppColors.of(ctx);
          final options = scopeType == 'branch' ? ctrl.branches : ctrl.categories;
          return Container(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s4,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.canvas,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('leave_policy_add'.tr, style: AppTextStyles.h3(ctx)),
                  const SizedBox(height: AppSpacing.s3),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'branch', label: Text('scope_branch'.tr)),
                      ButtonSegment(
                          value: 'category', label: Text('scope_category'.tr)),
                    ],
                    selected: {scopeType},
                    onSelectionChanged: (s) => setState(() {
                      scopeType = s.first;
                      scopeId = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  DropdownButtonFormField<int>(
                    initialValue: scopeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: scopeType == 'branch'
                          ? 'scope_branch'.tr
                          : 'scope_category'.tr,
                      border: const OutlineInputBorder(),
                    ),
                    items: options
                        .map((o) => DropdownMenuItem<int>(
                              value: (o['id'] as num).toInt(),
                              child: Text((o['name'] ?? '').toString()),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => scopeId = v),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'leave_policy_seniority_label'.tr,
                    controller: seniorityCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hint: '0',
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('leave_carryover_enabled'.tr,
                        style: AppTextStyles.body(ctx)),
                    value: enabled,
                    onChanged: (v) => setState(() => enabled = v),
                    activeThumbColor: colors.brand,
                  ),
                  if (enabled) ...[
                    PrimaryInput(
                      label: 'leave_carryover_max_label'.tr,
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      hint: '0',
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'leave_expiry_months_label'.tr,
                      controller: expiryCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      hint: '',
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'leave_legal_min_label'.tr,
                      controller: legalCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      hint: '0',
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('leave_encash_enabled'.tr,
                          style: AppTextStyles.body(ctx)),
                      value: encash,
                      onChanged: (v) => setState(() => encash = v),
                      activeThumbColor: colors.brand,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryButton(
                    text: 'save'.tr,
                    isLoading: ctrl.saving,
                    onPressed: () async {
                      if (scopeId == null) {
                        Get.snackbar('error'.tr, 'leave_policy_scope_required'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      final ok = await ctrl.savePolicy(
                        scopeType: scopeType,
                        scopeId: scopeId!,
                        minSeniorityMonths:
                            int.tryParse(seniorityCtrl.text.trim()) ?? 0,
                        carryoverEnabled: enabled,
                        carryoverMaxDays: int.tryParse(maxCtrl.text.trim()),
                        expiryMonths: int.tryParse(expiryCtrl.text.trim()),
                        encashExcess: encash,
                        legalMinCarryDays: int.tryParse(legalCtrl.text.trim()),
                      );
                      if (ok) Get.back<void>();
                    },
                  ),
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
