import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/payslip_pdf_exporter.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widget/month_grid_picker.dart';
import '../../../core/widget/shimmer_box.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/employee_category_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../logic/controller/branch/branch_controller.dart';
import '../../../logic/controller/category/category_controller.dart';
import '../../../logic/controller/payroll/payroll_controller.dart';
import '../../../logic/controller/shift/shift_controller.dart';
import '../../../data/model/payroll_model.dart';

Future<void> _openQuickAdjust(
    BuildContext context, PayrollController ctrl, PayrollModel p) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickAdjustSheet(ctrl: ctrl, payroll: p),
  );
}

Future<void> _exportPayslip(BuildContext context, PayrollModel p) async {
  try {
    await PayslipPdfExporter.exportAndShare(
      payroll: p,
      currencyIso: Get.find<PayrollController>().currency,
    );
  } catch (_) {
    Get.snackbar('error'.tr, 'payslip_export_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
  }
}

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<PayrollController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('payroll'.tr)),
      body: Column(
        children: [
          GetBuilder<PayrollController>(
            builder: (_) => _MonthPicker(ctrl: ctrl),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s1,
              AppSpacing.s4,
              AppSpacing.s2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: ctrl.onSearch,
                    decoration: InputDecoration(
                      hintText: 'search_employee'.tr,
                      prefixIcon: Icon(
                        Icons.search,
                        color: colors.textTertiary,
                      ),
                    ),
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                GetBuilder<PayrollController>(
                  builder: (_) => _FilterButton(ctrl: ctrl),
                ),
                const SizedBox(width: AppSpacing.s2),
                GetBuilder<PayrollController>(
                  builder: (_) => _GroupButton(ctrl: ctrl),
                ),
                const SizedBox(width: AppSpacing.s2),
                GetBuilder<PayrollController>(
                  builder: (_) => _SortButton(ctrl: ctrl),
                ),
              ],
            ),
          ),
          GetBuilder<PayrollController>(
            builder: (_) {
              if (!ctrl.hasActiveFilters) return const SizedBox.shrink();
              return _PayrollActiveFiltersBar(ctrl: ctrl);
            },
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadPayrolls,
              child: GetBuilder<PayrollController>(
                builder: (_) {
                  final rows = ctrl.displayRows;
                  final isFlatEmpty = rows.isEmpty;
                  final hasQuery = ctrl.searchQuery.trim().isNotEmpty;
                  // On the first ever fetch (no rows yet AND loading), show
                  // shimmer skeleton tiles instead of a centered spinner —
                  // it gives the user a better sense of what's coming.
                  final isFirstLoad = ctrl.status == StatusRequest.loading &&
                      ctrl.payrolls.isEmpty;
                  if (isFirstLoad) return const _PayrollSkeleton();
                  // Summary card sits at index 0; the empty-state row
                  // replaces the rest when the filtered set is empty.
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadPayrolls,
                    widget: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s4,
                        AppSpacing.s1,
                        AppSpacing.s4,
                        AppSpacing.s7,
                      ),
                      itemCount: isFlatEmpty ? 2 : rows.length + 1,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s2),
                      itemBuilder: (_, i) {
                        if (i == 0) return _PayrollSummaryCard(ctrl: ctrl);
                        if (isFlatEmpty) {
                          return _EmptyPayrolls(
                            isSearching: hasQuery || ctrl.hasActiveFilters,
                          );
                        }
                        final entry = rows[i - 1];
                        // Grouping inserts tagged map rows for branch
                        // headers and subtotals; everything else is a tile.
                        if (entry is Map && entry['_kind'] == 'header') {
                          return _BranchHeader(
                            branchId: entry['branch_id'] as int?,
                            count: entry['count'] as int,
                          );
                        }
                        if (entry is Map && entry['_kind'] == 'subtotal') {
                          return _BranchSubtotal(
                            net: entry['net'] as double,
                          );
                        }
                        final p = entry as PayrollModel;
                        return _PayrollTile(
                          payroll: p,
                          onAddAdjustment: () =>
                              _openQuickAdjust(context, ctrl, p),
                          onExportPdf: () => _exportPayslip(context, p),
                        );
                      },
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
}

class _MonthPicker extends StatelessWidget {
  final PayrollController ctrl;
  const _MonthPicker({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final from = ctrl.cycleWindowFrom(ctrl.selectedDate);
    final to = ctrl.cycleWindowTo(ctrl.selectedDate);
    final showRange = ctrl.cycleStartDay > 1;
    final current = ctrl.currentCycleLabelMonth();
    final min = ctrl.minReachableMonth();
    // Disable the "next" arrow once we're already on the cycle that
    // contains today — moving further would land on a cycle that hasn't
    // started yet.
    final canGoNext = ctrl.selectedDate.isBefore(current);
    // Disable "previous" once we've reached the cycle that contains the
    // earliest hire date — nothing useful to show before anyone was hired.
    final canGoPrev = min == null || ctrl.selectedDate.isAfter(min);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Row(
        children: [
          IconButton.outlined(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: canGoPrev
                ? () {
                    int m = ctrl.selectedMonth - 1;
                    int y = ctrl.selectedYear;
                    if (m < 1) {
                      m = 12;
                      y--;
                    }
                    ctrl.changeMonth(m, y);
                  }
                : null,
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () async {
                final picked = await showMonthGridPicker(
                  context,
                  selected: ctrl.selectedDate,
                  min: ctrl.minReachableMonth(),
                  max: ctrl.currentCycleLabelMonth(),
                );
                if (picked != null) {
                  ctrl.changeMonth(picked.month, picked.year);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${'month_${ctrl.selectedMonth}'.tr} ${ctrl.selectedYear}',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.brand,
                      ),
                    ),
                    if (showRange) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_dayMonth(from)} → ${_dayMonth(to)}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton.outlined(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: canGoNext
                ? () {
                    int m = ctrl.selectedMonth + 1;
                    int y = ctrl.selectedYear;
                    if (m > 12) {
                      m = 1;
                      y++;
                    }
                    ctrl.changeMonth(m, y);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  /// "12 مايو" — day of month + localized month name.
  static String _dayMonth(DateTime d) => '${d.day} ${'month_${d.month}'.tr}';
}

class _PayrollTile extends StatefulWidget {
  final PayrollModel payroll;
  final VoidCallback onAddAdjustment;
  final VoidCallback onExportPdf;

  const _PayrollTile({
    required this.payroll,
    required this.onAddAdjustment,
    required this.onExportPdf,
  });

  @override
  State<_PayrollTile> createState() => _PayrollTileState();
}

class _PayrollTileState extends State<_PayrollTile> {
  bool _expanded = false;
  static const String _font = 'IBM Plex Sans Arabic';

  PayrollModel get payroll => widget.payroll;
  VoidCallback get onAddAdjustment => widget.onAddAdjustment;
  VoidCallback get onExportPdf => widget.onExportPdf;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasDeductions = payroll.totalDeductions > 0;
    final hasBonuses = payroll.totalBonuses > 0;
    final canExpand = payroll.deductionEvents.isNotEmpty ||
        payroll.bonusEvents.isNotEmpty;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Material(
      color: colors.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Get.toNamed<void>(
          AppRoutes.employeeDetail
              .replaceAll(':id', '${payroll.employeeId}'),
          arguments: {'id': payroll.employeeId, 'initialTab': 2},
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.borderHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(colors),
              const SizedBox(height: AppSpacing.s3),
              _netRow(colors),
              if (hasDeductions || hasBonuses) ...[
                const SizedBox(height: AppSpacing.s3),
                _breakdownRow(colors, hasDeductions, hasBonuses),
              ],
              if (canExpand) _expandToggle(colors),
              if (_expanded && canExpand) _expandedBody(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColorScheme colors) {
    final anomaly = payroll.anomalyKind;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      payroll.employeeName ?? 'employee'.tr,
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (payroll.status == 'paid' ||
                      payroll.status == 'approved') ...[
                    const SizedBox(width: AppSpacing.s2),
                    _StatusBadge(status: payroll.status),
                  ],
                  if (anomaly != null) ...[
                    const SizedBox(width: AppSpacing.s2),
                    _AnomalyChip(kind: anomaly),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${'base_salary'.tr} ${_money(payroll.baseSalary)} ${currencyLabel(Get.find<PayrollController>().currency)}',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  color: colors.textTertiary,
                ),
              ),
              if (payroll.status == 'paid' && payroll.paidAt != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.event_available_outlined,
                        size: 12, color: colors.success),
                    const SizedBox(width: 4),
                    Text(
                      '${'payroll_paid_at'.tr} ${_formatDate(payroll.paidAt!)}',
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 11,
                        color: colors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        _TileMenu(
          onAddAdjustment: onAddAdjustment,
          onExportPdf: onExportPdf,
        ),
      ],
    );
  }

  Widget _netRow(AppColorScheme colors) {
    final isNegative = payroll.netSalary < 0;
    final netColor = isNegative ? colors.error : colors.brand;
    final delta = payroll.netDeltaVsPrevious;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'net'.tr.replaceAll(':', '').trim(),
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ),
            Text(
              _money(payroll.netSalary),
              style: TextStyle(
                fontFamily: _font,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: netColor,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${currencyLabel(Get.find<PayrollController>().currency)}',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (delta != null) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: delta >= 0 ? colors.success : colors.error,
              ),
              const SizedBox(width: 2),
              Text(
                _money(delta.abs()),
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: delta >= 0 ? colors.success : colors.error,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'vs_prev_short'.tr,
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 10,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _breakdownRow(
      AppColorScheme colors, bool hasDeductions, bool hasBonuses) {
    return Row(
      children: [
        if (hasDeductions)
          Expanded(
            child: _AmountChip(
              icon: Icons.south_rounded,
              label: 'deductions'.tr,
              amount: _money(payroll.totalDeductions),
              color: colors.error,
            ),
          ),
        if (hasDeductions && hasBonuses) const SizedBox(width: AppSpacing.s2),
        if (hasBonuses)
          Expanded(
            child: _AmountChip(
              icon: Icons.north_rounded,
              label: 'bonuses'.tr,
              amount: _money(payroll.totalBonuses),
              color: colors.success,
            ),
          ),
      ],
    );
  }

  Widget _expandToggle(AppColorScheme colors) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded ? 'hide_details'.tr : 'show_details'.tr,
              style: TextStyle(
                fontFamily: _font,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedBody(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s2),
      child: Column(
        children: [
          if (payroll.deductionEvents.isNotEmpty)
            _eventList(
              colors,
              title: 'deductions'.tr,
              events: payroll.deductionEvents,
              color: colors.error,
              sign: '−',
            ),
          if (payroll.deductionEvents.isNotEmpty &&
              payroll.bonusEvents.isNotEmpty)
            const SizedBox(height: AppSpacing.s2),
          if (payroll.bonusEvents.isNotEmpty)
            _eventList(
              colors,
              title: 'bonuses'.tr,
              events: payroll.bonusEvents,
              color: colors.success,
              sign: '+',
            ),
        ],
      ),
    );
  }

  Widget _eventList(
    AppColorScheme colors, {
    required String title,
    required List<PayrollAdjustment> events,
    required Color color,
    required String sign,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          for (final e in events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 4, height: 4,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      e.description,
                      style: TextStyle(
                        fontFamily: _font,
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$sign${_money(e.amount)}',
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// "5 يونيو 2026" — day + localized month name + year.
  String _formatDate(DateTime d) =>
      '${d.day} ${'month_${d.month}'.tr} ${d.year}';

  /// Format an integer with thousand separators (1234567 → "1,234,567").
  String _money(double value) {
    final isNeg = value < 0;
    final s = value.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return isNeg ? '−${buf.toString()}' : buf.toString();
  }
}

class _AmountChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final Color color;

  const _AmountChip({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            amount,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final PayrollController ctrl;
  const _SortButton({required this.ctrl});

  static const _options = <Map<String, String>>[
    {'key': 'name', 'label': 'sort_name'},
    {'key': 'net', 'label': 'sort_net_salary'},
    {'key': 'deduction', 'label': 'sort_deductions'},
    {'key': 'bonus', 'label': 'sort_bonuses'},
  ];

  IconData _iconFor(String key) {
    switch (key) {
      case 'net':
        return Icons.payments_outlined;
      case 'deduction':
        return Icons.south_rounded;
      case 'bonus':
        return Icons.north_rounded;
      default:
        return Icons.sort_by_alpha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showMenu(context),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert, size: 18, color: colors.textSecondary),
              const SizedBox(width: 4),
              Icon(_iconFor(ctrl.sortBy), size: 14, color: colors.brand),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s3,
          AppSpacing.s4,
          AppSpacing.s5,
        ),
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
              child: Text('sort_by'.tr, style: AppTextStyles.h3(context)),
            ),
            const SizedBox(height: AppSpacing.s2),
            ..._options.map((opt) {
              final key = opt['key']!;
              final isSelected = ctrl.sortBy == key;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () {
                    ctrl.setSortBy(key);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                      vertical: AppSpacing.s3,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _iconFor(key),
                          size: 18,
                          color: isSelected
                              ? colors.brand
                              : colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: Text(
                            opt['label']!.tr,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? colors.brand
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, size: 18, color: colors.brand),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/* ── Filter button + filter sheet ─────────────────────────────────── */

class _FilterButton extends StatelessWidget {
  final PayrollController ctrl;
  const _FilterButton({required this.ctrl});

  int get _activeCount =>
      (ctrl.branchFilter != null ? 1 : 0) +
      (ctrl.shiftFilter != null ? 1 : 0) +
      (ctrl.categoryFilter != null ? 1 : 0) +
      (ctrl.statusFilter != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = _activeCount;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showSheet(context),
        child: Container(
          height: 48,
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: count > 0 ? colors.brand : colors.borderHairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list,
                size: 18,
                color: count > 0 ? colors.brand : colors.textSecondary,
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.brand,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    final branchCtrl = Get.find<BranchController>();
    final shiftCtrl = Get.find<ShiftController>();
    final categoryCtrl = Get.find<CategoryController>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayrollFilterPanel(
        ctrl: ctrl,
        branches: branchCtrl.branches,
        shifts: shiftCtrl.shifts,
        categories: categoryCtrl.categories,
      ),
    );
  }
}

class _PayrollFilterPanel extends StatefulWidget {
  final PayrollController ctrl;
  final List<BranchModel> branches;
  final List<ShiftModel> shifts;
  final List<EmployeeCategoryModel> categories;
  const _PayrollFilterPanel({
    required this.ctrl,
    required this.branches,
    required this.shifts,
    required this.categories,
  });

  @override
  State<_PayrollFilterPanel> createState() => _PayrollFilterPanelState();
}

class _PayrollFilterPanelState extends State<_PayrollFilterPanel> {
  late int? _branchId = widget.ctrl.branchFilter;
  late int? _shiftId = widget.ctrl.shiftFilter;
  late int? _categoryId = widget.ctrl.categoryFilter;
  late String? _status = widget.ctrl.statusFilter;

  /// Selectable payroll states, in display order. Null = every status.
  static const _statusOptions = <Map<String, String?>>[
    {'key': null, 'label': 'filter_all'},
    {'key': 'paid', 'label': 'status_paid'},
    {'key': 'approved', 'label': 'status_approved'},
    {'key': 'draft', 'label': 'status_draft'},
  ];

  List<ShiftModel> get _visibleShifts {
    if (_branchId == null) return widget.shifts;
    return widget.shifts
        .where((s) => s.branchId == null || s.branchId == _branchId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final visibleShifts = _visibleShifts;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s3,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Text('customize_view'.tr, style: AppTextStyles.h2(context)),
          const SizedBox(height: AppSpacing.s4),
          if (widget.branches.isNotEmpty) ...[
            _filterLabel(colors, 'filter_branch'.tr),
            const SizedBox(height: AppSpacing.s2),
            _filterDropdown<int?>(
              colors: colors,
              value: _branchId,
              hint: 'all_branches'.tr,
              icon: Icons.account_tree_outlined,
              items: widget.branches
                  .map((b) => DropdownMenuItem<int?>(
                        value: b.id,
                        child: Text(b.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _branchId = v;
                if (_shiftId != null &&
                    !visibleShifts.any((s) => s.id == _shiftId)) {
                  _shiftId = null;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (visibleShifts.isNotEmpty) ...[
            _filterLabel(colors, 'filter_shift'.tr),
            const SizedBox(height: AppSpacing.s2),
            _filterDropdown<int?>(
              colors: colors,
              value: _shiftId,
              hint: 'all_shifts'.tr,
              icon: Icons.schedule_outlined,
              items: visibleShifts
                  .map((s) => DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text(s.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _shiftId = v),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (widget.categories.isNotEmpty) ...[
            _filterLabel(colors, 'filter_category'.tr),
            const SizedBox(height: AppSpacing.s2),
            _filterDropdown<int?>(
              colors: colors,
              value: _categoryId,
              hint: 'all_categories'.tr,
              icon: Icons.category_outlined,
              items: widget.categories
                  .map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          _filterLabel(colors, 'filter_status'.tr),
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: _statusOptions.map((opt) {
              final key = opt['key'];
              final selected = _status == key;
              return _StatusChoiceChip(
                label: opt['label']!.tr,
                selected: selected,
                onTap: () => setState(() => _status = key),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.s4),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _branchId = null;
                    _shiftId = null;
                    _categoryId = null;
                    _status = null;
                  }),
                  child: Text(
                    'clear_filters'.tr,
                    style:
                        const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.ctrl.applyFilters(
                      branchId: _branchId,
                      shiftId: _shiftId,
                      categoryId: _categoryId,
                      status: _status,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'apply'.tr,
                    style:
                        const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterLabel(AppColorScheme colors, String text) => Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      );

  Widget _filterDropdown<T>({
    required AppColorScheme colors,
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.expand_more, size: 18),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
                hint: Text(
                  hint,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    color: colors.textTertiary,
                  ),
                ),
                items: [
                  DropdownMenuItem<T>(
                    value: null,
                    child: Text(hint),
                  ),
                  ...items,
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill toggle for one payroll status in the filter sheet. Brand-filled
/// when selected, hairline-outlined otherwise.
class _StatusChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.brand : colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
          decoration: BoxDecoration(
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
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/* ── Active filters bar (chips under the search row) ──────────────── */

class _PayrollActiveFiltersBar extends StatelessWidget {
  final PayrollController ctrl;
  const _PayrollActiveFiltersBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chips = <Widget>[];

    if (ctrl.branchFilter != null) {
      final name = _lookup(
        Get.find<BranchController>().branches,
        ctrl.branchFilter,
        (b) => b.id,
        (b) => b.name,
      );
      chips.add(_chip(colors, Icons.account_tree_outlined, name,
          () => ctrl.applyFilters(
                branchId: null,
                shiftId: ctrl.shiftFilter,
                categoryId: ctrl.categoryFilter,
                status: ctrl.statusFilter,
              )));
    }
    if (ctrl.shiftFilter != null) {
      final name = _lookup(
        Get.find<ShiftController>().shifts,
        ctrl.shiftFilter,
        (s) => s.id,
        (s) => s.name,
      );
      chips.add(_chip(colors, Icons.schedule_outlined, name,
          () => ctrl.applyFilters(
                branchId: ctrl.branchFilter,
                shiftId: null,
                categoryId: ctrl.categoryFilter,
                status: ctrl.statusFilter,
              )));
    }
    if (ctrl.categoryFilter != null) {
      final name = _lookup(
        Get.find<CategoryController>().categories,
        ctrl.categoryFilter,
        (c) => c.id,
        (c) => c.name,
      );
      chips.add(_chip(colors, Icons.category_outlined, name,
          () => ctrl.applyFilters(
                branchId: ctrl.branchFilter,
                shiftId: ctrl.shiftFilter,
                categoryId: null,
                status: ctrl.statusFilter,
              )));
    }
    if (ctrl.statusFilter != null) {
      chips.add(_chip(colors, Icons.verified_outlined,
          _statusLabel(ctrl.statusFilter!),
          () => ctrl.applyFilters(
                branchId: ctrl.branchFilter,
                shiftId: ctrl.shiftFilter,
                categoryId: ctrl.categoryFilter,
                status: null,
              )));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s2),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s2),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'status_paid'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'draft':
        return 'status_draft'.tr;
      case 'live':
        return 'status_live'.tr;
      default:
        return status;
    }
  }

  String _lookup<T>(List<T> list, int? id, int? Function(T) idOf,
      String Function(T) nameOf) {
    if (id == null) return '';
    for (final e in list) {
      if (idOf(e) == id) return nameOf(e);
    }
    return '#$id';
  }

  Widget _chip(AppColorScheme colors, IconData icon, String label,
      VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: 4),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.brand.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.brand),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 14, color: colors.brand),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Summary card (totals + status counts + prev-cycle delta) ─────── */

class _PayrollSummaryCard extends StatelessWidget {
  final PayrollController ctrl;
  const _PayrollSummaryCard({required this.ctrl});

  static String _money(double v) {
    // Group by thousands on the magnitude, then re-attach the sign so a
    // negative total renders as "−4,050" not "-,4050".
    final isNeg = v < 0;
    final s = v.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return isNeg ? '−${buf.toString()}' : buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final visible = ctrl.filteredPayrolls.length;
    final delta = ctrl.netDeltaVsPrevious;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.brand, colors.brandHover],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: total net + delta
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'payroll_total_net'.tr,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                            text: _money(ctrl.totalNet),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: '  ${currencyLabel(ctrl.currency)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (delta != null) _DeltaBadge(amount: delta),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          // Middle row: bonus / deduction mini-stats
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.north_rounded,
                  label: 'payroll_total_bonuses'.tr,
                  value: _money(ctrl.totalBonuses),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: _MiniStat(
                  icon: Icons.south_rounded,
                  label: 'payroll_total_deductions'.tr,
                  value: _money(ctrl.totalDeductions),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          const SizedBox(height: AppSpacing.s3),
          // Bottom row: employee count + paid badge
          Row(
            children: [
              Expanded(
                child: Text(
                  'payroll_employee_count'.trParams({'count': '$visible'}),
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              if (ctrl.paidCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'payroll_paid_count'.trParams({
                          'paid': '${ctrl.paidCount}',
                          'total': '${ctrl.scopedCount}',
                        }),
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  final double amount;
  const _DeltaBadge({required this.amount});

  @override
  Widget build(BuildContext context) {
    final isUp = amount >= 0;
    final absAmount = amount.abs();
    final formatted = _PayrollSummaryCard._money(absAmount);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            formatted,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'payroll_vs_prev_cycle'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Empty state for the list ─────────────────────────────────────── */

class _EmptyPayrolls extends StatelessWidget {
  final bool isSearching;
  const _EmptyPayrolls({required this.isSearching});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Column(
        children: [
          Icon(
            isSearching
                ? Icons.search_off_outlined
                : Icons.receipt_long_outlined,
            size: 48,
            color: colors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            isSearching ? 'no_employees'.tr : 'no_payrolls'.tr,
            style: AppTextStyles.bodySecondary(context),
          ),
        ],
      ),
    );
  }
}

/* ── Group-by-branch toggle ────────────────────────────────────────── */

class _GroupButton extends StatelessWidget {
  final PayrollController ctrl;
  const _GroupButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = ctrl.groupByBranch;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: ctrl.toggleGroupByBranch,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: active ? colors.brand : colors.borderHairline,
            ),
          ),
          child: Icon(
            active ? Icons.layers : Icons.layers_outlined,
            size: 18,
            color: active ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _BranchHeader extends StatelessWidget {
  final int? branchId;
  final int count;
  const _BranchHeader({required this.branchId, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    String name;
    if (branchId == null) {
      name = 'no_branch_group_label'.tr;
    } else {
      final branches = Get.find<BranchController>().branches;
      final found = branches.where((b) => b.id == branchId).toList();
      name = found.isNotEmpty ? found.first.name : '#$branchId';
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s2, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            margin: const EdgeInsets.only(right: AppSpacing.s2),
            decoration: BoxDecoration(
              color: colors.brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            'payroll_employee_count'.trParams({'count': '$count'}),
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchSubtotal extends StatelessWidget {
  final double net;
  const _BranchSubtotal({required this.net});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isNeg = net < 0;
    final s = net.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    final money = '${isNeg ? '−' : ''}${buf.toString()}';

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'branch_subtotal'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
          Text(
            '$money ${currencyLabel(Get.find<PayrollController>().currency)}',
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isNeg ? colors.error : colors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Tile overflow menu (quick adjust + PDF export) ────────────────── */

class _TileMenu extends StatelessWidget {
  final VoidCallback onAddAdjustment;
  final VoidCallback onExportPdf;
  const _TileMenu({
    required this.onAddAdjustment,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PopupMenuButton<String>(
      tooltip: '',
      iconSize: 18,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, color: colors.textSecondary, size: 18),
      onSelected: (v) {
        if (v == 'adjust') onAddAdjustment();
        if (v == 'pdf') onExportPdf();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'adjust',
          child: Row(
            children: [
              Icon(Icons.add_circle_outline,
                  size: 16, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text('add_adjustment_tooltip'.tr,
                  style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic', fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined,
                  size: 16, color: colors.textSecondary),
              const SizedBox(width: 8),
              Text('export_payslip_pdf'.tr,
                  style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic', fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

/* ── Status badge (paid / approved) ────────────────────────────────── */

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isPaid = status == 'paid';
    final color = isPaid ? colors.success : colors.brand;
    final label = isPaid ? 'status_paid'.tr : 'status_approved'.tr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.verified_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Anomaly chip (deduction spike / net drop) ─────────────────────── */

class _AnomalyChip extends StatelessWidget {
  final String kind;
  const _AnomalyChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = kind == 'deduction_spike'
        ? 'anomaly_deduction_spike'.tr
        : 'anomaly_net_drop'.tr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: colors.warning),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Quick adjustment bottom sheet ─────────────────────────────────── */

class _QuickAdjustSheet extends StatefulWidget {
  final PayrollController ctrl;
  final PayrollModel payroll;
  const _QuickAdjustSheet({required this.ctrl, required this.payroll});

  @override
  State<_QuickAdjustSheet> createState() => _QuickAdjustSheetState();
}

class _QuickAdjustSheetState extends State<_QuickAdjustSheet> {
  String _kind = 'deduction'; // or 'bonus'
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s3,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Text(
            'quick_adjust_title'.tr,
            style: AppTextStyles.h2(context),
          ),
          const SizedBox(height: 2),
          Text(
            widget.payroll.employeeName ?? '',
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          // Type toggle
          Row(
            children: [
              Expanded(child: _typeChip(colors, 'deduction', Icons.south_rounded, colors.error)),
              const SizedBox(width: AppSpacing.s2),
              Expanded(child: _typeChip(colors, 'bonus', Icons.north_rounded, colors.success)),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'adjust_amount'.tr,
              prefixIcon: Icon(Icons.attach_money,
                  color: colors.textTertiary, size: 18),
            ),
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          TextField(
            controller: _reason,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'adjust_reason'.tr,
            ),
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 15,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.brand,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('save'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(
      AppColorScheme colors, String value, IconData icon, Color color) {
    final selected = _kind == value;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => setState(() => _kind = value),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? color : colors.borderHairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                value == 'deduction'
                    ? 'adjust_type_deduction'.tr
                    : 'adjust_type_bonus'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final reason = _reason.text.trim();
    if (amount <= 0 || reason.isEmpty) return;
    setState(() => _submitting = true);
    final ok = await widget.ctrl.addAdjustment(
      employeeId: widget.payroll.employeeId,
      kind: _kind,
      amount: amount,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.of(context).pop();
  }
}

/* ── First-load shimmer skeleton ──────────────────────────────────── */

class _PayrollSkeleton extends StatelessWidget {
  const _PayrollSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4, AppSpacing.s1, AppSpacing.s4, AppSpacing.s7,
      ),
      children: [
        // Mock summary card
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.sunken,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(height: 12, width: 100),
              const SizedBox(height: 8),
              const ShimmerBox(height: 28, width: 180),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: ShimmerBox(height: 40,
                      borderRadius: BorderRadius.circular(AppRadius.md))),
                  const SizedBox(width: 8),
                  Expanded(child: ShimmerBox(height: 40,
                      borderRadius: BorderRadius.circular(AppRadius.md))),
                ],
              ),
              const SizedBox(height: 12),
              const ShimmerBox(height: 12, width: 240),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        SizedBox(
          height: 34,
          child: Row(
            children: List.generate(
              5,
              (i) => Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.s2),
                child: ShimmerBox(
                  height: 30, width: 70,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        for (int i = 0; i < 5; i++) ...[
          _TileSkeleton(colors: colors),
          const SizedBox(height: AppSpacing.s2),
        ],
      ],
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  final AppColorScheme colors;
  const _TileSkeleton({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 14, width: 140),
                    SizedBox(height: 4),
                    ShimmerBox(height: 10, width: 100),
                  ],
                ),
              ),
              ShimmerBox(
                height: 18, width: 50,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ShimmerBox(height: 10, width: 40),
              const ShimmerBox(height: 24, width: 90),
            ],
          ),
        ],
      ),
    );
  }
}

