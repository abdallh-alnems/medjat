import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/leave/leave_controller.dart';
import '../../../data/model/leave_model.dart';
import 'widgets/add_leave_sheet.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<LeaveController>(LeaveController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('leaves'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_leave',
        onPressed: () => showAddLeaveSheet(ctrl),
        backgroundColor: colors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _filterBar(context, ctrl, colors),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s2,
            ),
            child: GetBuilder<LeaveController>(
              builder: (_) {
                final filtered = ctrl.filteredLeaves;
                final current =
                    filtered.where((l) => _leaveCategory(l) == 0).length;
                final ended =
                    filtered.where((l) => _leaveCategory(l) == 1).length;
                final rejected =
                    filtered.where((l) => _leaveCategory(l) == 2).length;
                return Row(
                  children: [
                    Expanded(
                      child: _FilterChip(
                        label: '${'leave_tab_current'.tr} ($current)',
                        selected: ctrl.requestsTab == 0,
                        onTap: () => ctrl.setRequestsTab(0),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: _FilterChip(
                        label: '${'leave_tab_ended'.tr} ($ended)',
                        selected: ctrl.requestsTab == 1,
                        onTap: () => ctrl.setRequestsTab(1),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: _FilterChip(
                        label: '${'leave_tab_rejected'.tr} ($rejected)',
                        selected: ctrl.requestsTab == 2,
                        onTap: () => ctrl.setRequestsTab(2),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadLeaves,
              child: GetBuilder<LeaveController>(
                builder: (_) {
                  final list = ctrl.filteredLeaves
                      .where((l) => _leaveCategory(l) == ctrl.requestsTab)
                      .toList();
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadLeaves,
                    widget: list.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.beach_access_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_leaves'.tr,
                                    style:
                                        AppTextStyles.bodySecondary(context)),
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
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _LeaveTile(
                              leave: list[i],
                              onApprove: () => ctrl.approveLeave(list[i].id),
                              onReject: () => _showRejectDialog(
                                  context, ctrl, list[i].id),
                              onConvertToAbsence: () => _showConvertDialog(
                                  context, ctrl, list[i].id),
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

  Widget _filterBar(
      BuildContext context, LeaveController ctrl, AppColorScheme colors) {
    return GetBuilder<LeaveController>(
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, 0),
        child: Column(
          children: [
            TextField(
              onChanged: ctrl.setSearchQuery,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'search_employee'.tr,
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: colors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: colors.borderHairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: colors.borderHairline),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Expanded(
                  child: _filterField(
                    context,
                    colors,
                    text: ctrl.branchFilter == null
                        ? 'all_branches'.tr
                        : ctrl.branches
                            .firstWhere((b) => b.id == ctrl.branchFilter,
                                orElse: () => ctrl.branches.first)
                            .name,
                    onTap: () => _showSelectSheet(
                      context,
                      colors,
                      title: 'all_branches'.tr,
                      selected: ctrl.branchFilter,
                      options: [
                        MapEntry(null, 'all_branches'.tr),
                        ...ctrl.branches.map((b) => MapEntry(b.id, b.name)),
                      ],
                      onSelect: ctrl.setBranchFilter,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: _filterField(
                    context,
                    colors,
                    text: ctrl.categoryFilter == null
                        ? 'all_categories'.tr
                        : ctrl.categories
                            .firstWhere((c) => c.id == ctrl.categoryFilter,
                                orElse: () => ctrl.categories.first)
                            .name,
                    onTap: () => _showSelectSheet(
                      context,
                      colors,
                      title: 'all_categories'.tr,
                      selected: ctrl.categoryFilter,
                      options: [
                        MapEntry(null, 'all_categories'.tr),
                        ...ctrl.categories.map((c) => MapEntry(c.id, c.name)),
                      ],
                      onSelect: ctrl.setCategoryFilter,
                    ),
                  ),
                ),
                if (ctrl.hasActiveFilters) ...[
                  const SizedBox(width: AppSpacing.s2),
                  IconButton(
                    onPressed: ctrl.clearFilters,
                    icon: Icon(Icons.filter_alt_off, color: colors.error),
                    tooltip: 'clear_filters'.tr,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterField(
    BuildContext context,
    AppColorScheme colors, {
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sm(context),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }

  void _showSelectSheet(
    BuildContext context,
    AppColorScheme colors, {
    required String title,
    required int? selected,
    required List<MapEntry<int?, String>> options,
    required ValueChanged<int?> onSelect,
  }) {
    Get.bottomSheet<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: colors.canvas,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  child: Text(title,
                      style: AppTextStyles.body(context)
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: options.map((opt) {
                      final isSel = opt.key == selected;
                      return ListTile(
                        title: Text(opt.value,
                            style: AppTextStyles.body(context)),
                        trailing: isSel
                            ? Icon(Icons.check, color: colors.brand)
                            : null,
                        onTap: () {
                          Get.back<void>();
                          onSelect(opt.key);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(
      BuildContext context, LeaveController ctrl, int leaveId) {
    final reasonCtrl = TextEditingController();
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('reject_leave'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'rejection_reason'.tr,
              hintStyle: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textTertiary,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () {
                Get.back<void>();
                ctrl.rejectLeave(leaveId,
                    reason: reasonCtrl.text.trim().isNotEmpty
                        ? reasonCtrl.text.trim()
                        : null);
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('reject'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showConvertDialog(
      BuildContext context, LeaveController ctrl, int leaveId) {
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('convert_to_absence'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          content: Text('convert_to_absence_confirm'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textSecondary,
              )),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () {
                Get.back<void>();
                ctrl.convertToAbsence(leaveId);
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('convert_to_absence'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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

class _LeaveTile extends StatelessWidget {
  final LeaveModel leave;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onConvertToAbsence;

  const _LeaveTile({
    required this.leave,
    required this.onApprove,
    required this.onReject,
    required this.onConvertToAbsence,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(leave.status, colors);

    String dateLabel =
        '${leave.startDate.day}/${leave.startDate.month}/${leave.startDate.year}';
    if (leave.endDate != null && leave.endDate != leave.startDate) {
      dateLabel =
          '$dateLabel - ${leave.endDate!.day}/${leave.endDate!.month}/${leave.endDate!.year}';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leave.employeeName ?? 'employee'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  leave.statusLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Text(
                leave.typeLabel,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
          if (leave.reason != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              leave.reason!,
              style: AppTextStyles.sm(context),
            ),
          ],
          if (leave.status == 'rejected' &&
              leave.rejectionReason != null &&
              leave.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Text(
                    leave.rejectionReason!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (leave.status == 'approved' &&
              leave.approvedByName != null &&
              leave.approvedByName!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 14, color: colors.success),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    'approved_by'.trParams({'name': leave.approvedByName!}),
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (leave.approvedAt != null)
                  Text(
                    '${leave.approvedAt!.day}/${leave.approvedAt!.month}/${leave.approvedAt!.year}',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
          if (leave.status == 'rejected' &&
              leave.rejectedByName != null &&
              leave.rejectedByName!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.person_off_outlined, size: 14, color: colors.error),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    'rejected_by'.trParams({'name': leave.rejectedByName!}),
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (leave.status == 'approved') ...[
            const SizedBox(height: AppSpacing.s3),
            OutlinedButton.icon(
              onPressed: onConvertToAbsence,
              icon: const Icon(Icons.event_busy_outlined, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withValues(alpha: 0.4)),
                minimumSize: const Size.fromHeight(40),
              ),
              label: Text('convert_to_absence'.tr),
            ),
          ],
          if (leave.status == 'pending') ...[
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onApprove,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('accept'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('reject'.tr),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'pending':
        return colors.warning;
      case 'approved':
        return colors.success;
      case 'rejected':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }
}

/// True when the leave's date has already passed (it has ended).
bool _isPastLeave(LeaveModel l) {
  final d = l.endDate ?? l.startDate;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return d.isBefore(today);
}

/// 0 = current (active), 1 = ended (date passed), 2 = rejected.
int _leaveCategory(LeaveModel l) {
  if (l.status == 'rejected') return 2;
  if (_isPastLeave(l)) return 1;
  return 0;
}
