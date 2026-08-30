import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../logic/controller/settings/leave_encashments_controller.dart';

class LeaveEncashmentsScreen extends StatelessWidget {
  const LeaveEncashmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(LeaveEncashmentsController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('leave_encashments_title'.tr)),
      body: GetBuilder<LeaveEncashmentsController>(
        builder: (_) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
                child: Row(
                  children: [
                    _filterChip(ctrl, null, 'all'.tr),
                    const SizedBox(width: AppSpacing.s2),
                    _filterChip(ctrl, 'pending', 'enc_status_pending'.tr),
                    const SizedBox(width: AppSpacing.s2),
                    _filterChip(ctrl, 'paid', 'enc_status_paid'.tr),
                  ],
                ),
              ),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: ctrl.status,
                  onRetry: ctrl.load,
                  widget: ctrl.encashments.isEmpty
                      ? Center(
                          child: Text('leave_encashments_empty'.tr,
                              style: AppTextStyles.sm(context)))
                      : RefreshIndicator(
                          onRefresh: ctrl.load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.s4),
                            itemCount: ctrl.encashments.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) =>
                                _tile(context, colors, ctrl.encashments[i]),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(
      LeaveEncashmentsController ctrl, String? value, String label) {
    final selected = ctrl.statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ctrl.setFilter(value),
    );
  }

  Widget _tile(
      BuildContext context, AppColorScheme colors, Map<String, dynamic> e) {
    final status = (e['status'] ?? 'pending').toString();
    final isPaid = status == 'paid';
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
                Text((e['employee_name'] ?? '—').toString(),
                    style: AppTextStyles.body(context)),
                const SizedBox(height: 2),
                Text(
                  'enc_line'.trParams({
                    'days': (e['days'] ?? 0).toString(),
                    'year': (e['source_year'] ?? '').toString(),
                  }),
                  style: AppTextStyles.sm(context),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${e['amount'] ?? 0}', style: AppTextStyles.body(context)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isPaid ? colors.brand : colors.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  isPaid ? 'enc_status_paid'.tr : 'enc_status_pending'.tr,
                  style: AppTextStyles.xs(context).copyWith(
                    color: isPaid ? colors.brand : colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
