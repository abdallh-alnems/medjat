import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/break/break_controller.dart';
import '../../../data/model/break_request_model.dart';
import 'widgets/add_break_sheet.dart';

class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<BreakController>(BreakController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('break_requests'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_break',
        onPressed: () => showAddBreakSheet(ctrl),
        backgroundColor: colors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s3,
              AppSpacing.s4,
              0,
            ),
            child: TextField(
              controller: ctrl.searchCtrl,
              onChanged: ctrl.search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'search_employee'.tr,
                hintStyle: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: colors.textTertiary,
                ),
                filled: true,
                fillColor: colors.sunken,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          GetBuilder<BreakController>(
            builder: (_) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s2,
                AppSpacing.s4,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _filterField(
                      context,
                      colors,
                      text: ctrl.branchFilter == null
                          ? 'all_branches'.tr
                          : ctrl.branches
                                .firstWhere(
                                  (b) => b.id == ctrl.branchFilter,
                                  orElse: () => ctrl.branches.first,
                                )
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
                        onSelect: ctrl.filterByBranch,
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
                                .firstWhere(
                                  (c) => c.id == ctrl.categoryFilter,
                                  orElse: () => ctrl.categories.first,
                                )
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
                        onSelect: ctrl.filterByCategory,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s2,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GetBuilder<BreakController>(
                builder: (_) => Row(
                  children: [
                    _FilterChip(
                      label: 'all'.tr,
                      selected: ctrl.statusFilter == null,
                      onTap: () => ctrl.filterByStatus(null),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    _FilterChip(
                      label: 'under_review'.tr,
                      selected: ctrl.statusFilter == 'pending',
                      onTap: () => ctrl.filterByStatus('pending'),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    _FilterChip(
                      label: 'accepted'.tr,
                      selected: ctrl.statusFilter == 'approved',
                      onTap: () => ctrl.filterByStatus('approved'),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    _FilterChip(
                      label: 'status_postponed'.tr,
                      selected: ctrl.statusFilter == 'postponed',
                      onTap: () => ctrl.filterByStatus('postponed'),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    _FilterChip(
                      label: 'status_rejected'.tr,
                      selected: ctrl.statusFilter == 'rejected',
                      onTap: () => ctrl.filterByStatus('rejected'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadBreaks,
              child: GetBuilder<BreakController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadBreaks,
                    widget: ctrl.breaks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.coffee_outlined,
                                  size: 48,
                                  color: colors.textTertiary,
                                ),
                                const SizedBox(height: AppSpacing.s3),
                                Text(
                                  'no_break_requests'.tr,
                                  style: AppTextStyles.bodySecondary(context),
                                ),
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
                            itemCount: ctrl.breaks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _BreakTile(
                              breakItem: ctrl.breaks[i],
                              onApprove: () =>
                                  _handleApprove(context, ctrl, ctrl.breaks[i]),
                              onReject: () => _showRejectDialog(
                                context,
                                ctrl,
                                ctrl.breaks[i].id,
                              ),
                              onPostpone: () => _showPostponeDialog(
                                context,
                                ctrl,
                                ctrl.breaks[i],
                              ),
                              onCancel: () =>
                                  ctrl.cancelBreak(ctrl.breaks[i].id),
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

  // Tappable filter field that opens a bottom-sheet picker (same pattern as the
  // leaves screen) — avoids the DropdownButton "first tap does nothing" issue.
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Material(
            color: colors.canvas,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s4),
                    child: Text(
                      title,
                      style: AppTextStyles.body(
                        context,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: options.map((opt) {
                        final isSel = opt.key == selected;
                        return ListTile(
                          title: Text(
                            opt.value,
                            style: AppTextStyles.body(context),
                          ),
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
      ),
    );
  }

  // On approval the manager confirms whether the permission window is deducted
  // from the salary by the hour. The dialog starts from the value the requester
  // chose at creation time and can be changed here.
  void _handleApprove(
    BuildContext context,
    BreakController ctrl,
    BreakRequestModel item,
  ) {
    final colors = AppColors.of(context);
    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'early_leave_approve_title'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'early_leave_deduct_question'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              color: colors.textSecondary,
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
                ctrl.approveBreak(item.id, deductFromSalary: false);
              },
              child: Text('early_leave_approve_no_deduct'.tr),
            ),
            TextButton(
              onPressed: () {
                Get.back<void>();
                ctrl.approveBreak(item.id, deductFromSalary: true);
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('early_leave_approve_deduct'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    BreakController ctrl,
    int breakId,
  ) {
    final reasonCtrl = TextEditingController();
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'reject_break'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
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
                ctrl.rejectBreak(
                  breakId,
                  reason: reasonCtrl.text.trim().isNotEmpty
                      ? reasonCtrl.text.trim()
                      : null,
                );
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('reject'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostponeDialog(
    BuildContext context,
    BreakController ctrl,
    BreakRequestModel item,
  ) {
    final noteCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final startCtrl = TextEditingController();
    final endCtrl = TextEditingController();
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'postpone_break'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'break_postpone_note'.tr,
                    hintStyle: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      color: colors.textTertiary,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                TextField(
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'break_suggested_date'.tr,
                    suffixIcon: const Icon(Icons.event_outlined, size: 20),
                    hintStyle: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      color: colors.textTertiary,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      dateCtrl.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                  readOnly: true,
                ),
                const SizedBox(height: AppSpacing.s2),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'break_start_time'.tr,
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          suffixIcon: const Icon(Icons.access_time, size: 20),
                          border: const OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            startCtrl.text =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: TextField(
                        controller: endCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'break_end_time'.tr,
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          suffixIcon: const Icon(Icons.access_time, size: 20),
                          border: const OutlineInputBorder(),
                        ),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null) {
                            endCtrl.text =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
                ctrl.postponeBreak(
                  item.id,
                  note: noteCtrl.text.trim().isNotEmpty
                      ? noteCtrl.text.trim()
                      : null,
                  suggestedDate: dateCtrl.text.trim().isNotEmpty
                      ? dateCtrl.text.trim()
                      : null,
                  suggestedStartTime: startCtrl.text.trim().isNotEmpty
                      ? startCtrl.text.trim()
                      : null,
                  suggestedEndTime: endCtrl.text.trim().isNotEmpty
                      ? endCtrl.text.trim()
                      : null,
                );
              },
              child: Text('postpone_break'.tr),
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

class _BreakTile extends StatelessWidget {
  final BreakRequestModel breakItem;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPostpone;
  final VoidCallback onCancel;

  const _BreakTile({
    required this.breakItem,
    required this.onApprove,
    required this.onReject,
    required this.onPostpone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(breakItem.status, colors);

    final dateLabel =
        '${breakItem.date.day}/${breakItem.date.month}/${breakItem.date.year}';

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
                  breakItem.employeeName ?? 'employee'.tr,
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
                  breakItem.statusLabel,
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
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                breakItem.typeLabel,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              Text(
                '$dateLabel  ${breakItem.startTime} - ${breakItem.endTime}',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  color: colors.textTertiary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: colors.brandSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${breakItem.durationMinutes} ${'minutes'.tr}',
                  style: AppTextStyles.sm(
                    context,
                  ).copyWith(color: colors.brand, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (breakItem.reason != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(breakItem.reason!, style: AppTextStyles.sm(context)),
          ],
          if (breakItem.status == 'rejected' &&
              breakItem.decisionNote != null &&
              breakItem.decisionNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: AppSpacing.s4),
                Expanded(
                  child: Text(
                    breakItem.decisionNote!,
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
          if (breakItem.status == 'rejected' &&
              breakItem.decidedByName != null &&
              breakItem.decidedByName!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: colors.textTertiary),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    '${'break_rejected_by'.tr}: ${breakItem.decidedByName!}',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (breakItem.status == 'postponed' &&
              breakItem.suggestedDate != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: colors.warning),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: colors.warning),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      '${'break_suggested_time'.tr}: ${breakItem.suggestedDate!.day}/${breakItem.suggestedDate!.month}/${breakItem.suggestedDate!.year} ${breakItem.suggestedStartTime ?? ''} - ${breakItem.suggestedEndTime ?? ''}',
                      style: AppTextStyles.sm(context).copyWith(
                        color: colors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (breakItem.status == 'approved') ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(
                  breakItem.deductFromSalary
                      ? Icons.money_off
                      : Icons.check_circle_outline,
                  size: 14,
                  color: breakItem.deductFromSalary
                      ? colors.error
                      : colors.success,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    breakItem.deductFromSalary
                        ? 'early_leave_deducted'.tr
                        : 'early_leave_not_deducted'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: breakItem.deductFromSalary
                          ? colors.error
                          : colors.success,
                    ),
                  ),
                ),
              ],
            ),
            if (breakItem.decidedByName != null &&
                breakItem.decidedByName!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s1),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      '${'break_approved_by'.tr}: ${breakItem.decidedByName!}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (breakItem.status == 'pending') ...[
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
                    onPressed: onPostpone,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.warning,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('postpone_break'.tr),
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
      case 'postponed':
        return colors.warning;
      case 'cancelled':
        return colors.textTertiary;
      default:
        return colors.textTertiary;
    }
  }
}
