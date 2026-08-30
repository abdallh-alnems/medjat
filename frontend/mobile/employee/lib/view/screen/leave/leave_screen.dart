import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/leave/leave_controller.dart';
import '../../widget/ad/top_native_ad.dart';
import '../../widget/stat_item.dart';
import 'widgets/leave_apply_form.dart';
import 'widgets/leave_request_card.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => LeaveController());
    return Scaffold(
      appBar: AppBar(title: Text('leaves'.tr)),
      body: GetBuilder<LeaveController>(
        builder: (controller) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNativeAd(horizontalMargin: 0),
                _balanceSection(context, controller),
                const SizedBox(height: 24),
                LeaveApplyForm(controller: controller),
                const SizedBox(height: 28),
                _myRequestsSection(context, controller),
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
          Text('leave_balance'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: 12),
          if (balance != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                StatItem(label: 'balance'.tr, value: balance['total_days']?.toString() ?? '0'),
                StatItem(label: 'used'.tr, value: balance['used_days']?.toString() ?? '0'),
                StatItem(label: 'remaining'.tr, value: balance['remaining_days']?.toString() ?? '0'),
              ],
            )
          else
            Text('loading'.tr, style: AppTextStyles.bodySecondary(context)),
        ],
      ),
    );
  }

  int _leaveCategory(Map<String, dynamic> leave) {
    final status = (leave['status'] as String?) ?? 'pending';
    if (status == 'rejected') return 2;
    final start = leave['start_date']?.toString() ?? '';
    final end = leave['end_date']?.toString() ?? '';
    if (_isPast(end.isEmpty ? start : end)) return 1;
    return 0;
  }

  Widget _myRequestsSection(BuildContext context, LeaveController controller) {
    final colors = AppColors.of(context);
    final current =
        controller.myLeaves.where((l) => _leaveCategory(l) == 0).toList();
    final ended =
        controller.myLeaves.where((l) => _leaveCategory(l) == 1).toList();
    final rejected =
        controller.myLeaves.where((l) => _leaveCategory(l) == 2).toList();
    final tab = controller.requestsTab;
    final list = tab == 0 ? current : (tab == 1 ? ended : rejected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('my_leave_requests'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tabButton(context, colors,
                  label: 'leave_tab_current'.tr,
                  count: current.length,
                  selected: tab == 0,
                  onTap: () => controller.setRequestsTab(0)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tabButton(context, colors,
                  label: 'leave_tab_ended'.tr,
                  count: ended.length,
                  selected: tab == 1,
                  onTap: () => controller.setRequestsTab(1)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tabButton(context, colors,
                  label: 'leave_tab_rejected'.tr,
                  count: rejected.length,
                  selected: tab == 2,
                  onTap: () => controller.setRequestsTab(2)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (controller.myLeavesStatus == StatusRequest.loading &&
            controller.myLeaves.isEmpty)
          Text('loading'.tr, style: AppTextStyles.bodySecondary(context))
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('no_leave_requests'.tr,
                style: AppTextStyles.bodySecondary(context)),
          )
        else
          ...list.map((l) => LeaveRequestCard(controller: controller, leave: l)),
      ],
    );
  }

  Widget _tabButton(BuildContext context, AppColorScheme colors,
      {required String label,
      required int count,
      required bool selected,
      required VoidCallback onTap}) {
    final brand = AppColors.brand(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? brand.withValues(alpha: 0.12) : colors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? brand : colors.borderHairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sm(context).copyWith(
                  color: selected ? brand : colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? brand
                      : colors.textTertiary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.xs(context).copyWith(
                    color: selected ? Colors.white : colors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isPast(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return d.isBefore(today);
  }
}
