import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../data/model/dashboard_model.dart';
import '../../../logic/controller/dashboard/dashboard_controller.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/notification/notification_controller.dart';
import '../../../logic/controller/live_attendance/live_attendance_controller.dart';
import '../../../core/services/locale_service.dart';
import '../../../logic/controller/dashboard/status_employees_controller.dart';
import '../../widget/dashboard/stat_card.dart';

/// Formats a money amount with thousands separators + the currency label.
/// Latin digits (en) keep it consistent with the rest of the numeric UI.
final NumberFormat _kMoneyFmt = NumberFormat('#,##0', 'en');
String _money(num v) => '${_kMoneyFmt.format(v)} ${'currency_egp'.tr}';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<DashboardController>();
    final auth = Get.find<AuthController>();
    final colors = AppColors.of(context);

    try {
      final notifCtrl = Get.find<NotificationController>();
      notifCtrl.loadNotifications();
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${'welcome_greeting'.tr} ${auth.user?.name.split(' ').first ?? 'admin'.tr}',
          style: AppTextStyles.h3(context),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: _NotificationBadge(colors: colors),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.loadDashboard,
        child: GetBuilder<DashboardController>(
          builder: (_) {
            // First load → skeleton; once we have data keep showing it (a
            // refresh won't blank the screen). Errors only when there's no data.
            if (ctrl.dashboard == null) {
              if (ctrl.status == StatusRequest.loading ||
                  ctrl.status == StatusRequest.none) {
                return const _DashboardSkeleton();
              }
              return HandlingDataRequest(
                statusRequest: ctrl.status,
                onRetry: ctrl.loadDashboard,
                widget: _DashboardContent(ctrl: ctrl),
              );
            }
            return _DashboardContent(ctrl: ctrl);
          },
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final AppColorScheme colors;
  const _NotificationBadge({required this.colors});

  @override
  Widget build(BuildContext context) {
    NotificationController? notifCtrl;
    try {
      notifCtrl = Get.find<NotificationController>();
    } catch (_) {}

    final Widget badge = notifCtrl == null
        ? _badge(0)
        : Obx(() => _badge(notifCtrl!.unreadCount.value));
    return Semantics(
      button: true,
      label: 'notifications'.tr,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => Get.toNamed<void>(AppRoutes.notifications),
        radius: 24,
        child: SizedBox(width: 44, height: 44, child: Center(child: badge)),
      ),
    );
  }

  Widget _badge(int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.notifications_outlined,
          size: 26,
          color: colors.textSecondary,
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final DashboardController ctrl;
  const _DashboardContent({required this.ctrl});

  void _navigateToStatus(
    BuildContext context, {
    required EmployeeStatusFilter filter,
    required String title,
  }) {
    Get.toNamed<void>(
      AppRoutes.statusEmployees,
      arguments: {'filter': filter, 'title': title},
    );
  }

  /// The unified today-attendance grid. [inside]/[out]/[notIn] come from the
  /// live board (null when the viewer can't see live data); when present, the
  /// "present" card also shows the inside-now count and a checked-out /
  /// not-arrived row is appended with a last-updated caption.
  Widget _attendanceGrid(
    BuildContext context, {
    required DashboardModel? d,
    required String Function(int) pct,
    int? inside,
    int? out,
    int? notIn,
    DateTime? lastUpdated,
  }) {
    final colors = AppColors.of(context);
    final present = d?.presentToday ?? 0;
    final presentSubtitle = inside != null
        ? '${pct(present)} · ${'present_now'.tr} $inside'
        : pct(present);

    Widget cell({
      required String title,
      required int value,
      required IconData icon,
      required Color color,
      required String subtitle,
      EmployeeStatusFilter? filter,
      double? trend,
    }) {
      return StatCard(
        title: title,
        value: '$value',
        icon: icon,
        color: color,
        subtitle: subtitle,
        compact: true,
        trend: trend,
        onTap: filter == null
            ? null
            : () => _navigateToStatus(context, filter: filter, title: title),
      );
    }

    Widget gridRow(List<Widget> cells) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s2),
            Expanded(child: cells[i]),
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        gridRow([
          cell(
            title: 'present'.tr,
            value: present,
            icon: Icons.check_circle_outline,
            color: colors.success,
            subtitle: presentSubtitle,
            trend: (d != null && d.presentYesterday > 0)
                ? d.attendanceTrend
                : null,
            filter: EmployeeStatusFilter.present,
          ),
          cell(
            title: 'absent'.tr,
            value: d?.absentToday ?? 0,
            icon: Icons.cancel_outlined,
            color: colors.error,
            subtitle: pct(d?.absentToday ?? 0),
            filter: EmployeeStatusFilter.absent,
          ),
        ]),
        const SizedBox(height: AppSpacing.s2),
        gridRow([
          cell(
            title: 'late'.tr,
            value: d?.lateToday ?? 0,
            icon: Icons.access_time,
            color: colors.warning,
            subtitle: pct(d?.lateToday ?? 0),
            filter: EmployeeStatusFilter.late,
          ),
          cell(
            title: 'on_leave'.tr,
            value: d?.onLeaveToday ?? 0,
            icon: Icons.beach_access_outlined,
            color: colors.accentWarm,
            subtitle: pct(d?.onLeaveToday ?? 0),
            filter: EmployeeStatusFilter.leave,
          ),
        ]),
        if (out != null && notIn != null) ...[
          const SizedBox(height: AppSpacing.s2),
          gridRow([
            cell(
              title: 'status_out'.tr,
              value: out,
              icon: Icons.logout,
              color: colors.brand,
              subtitle: pct(out),
              filter: EmployeeStatusFilter.checkedOut,
            ),
            cell(
              title: 'status_not_in'.tr,
              value: notIn,
              icon: Icons.hourglass_empty,
              color: colors.textSecondary,
              subtitle: pct(notIn),
              filter: EmployeeStatusFilter.notArrived,
            ),
          ]),
        ],
        if (lastUpdated != null) ...[
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.sync, size: 12, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.s1),
              Text(
                '${'last_updated'.tr}: ${DateFormat('HH:mm').format(lastUpdated)}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Lays widgets out two per row, equal height, with a blank slot for an odd
  /// trailing item so card widths stay uniform.
  Widget _twoColumnGrid(List<Widget> cells) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: AppSpacing.s2));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cells[i]),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: i + 1 < cells.length ? cells[i + 1] : const SizedBox(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  /// The action queue: one card per pending approval area, shown only when its
  /// count is above zero. Each card opens its module.
  Widget _needsAttention(BuildContext context, DashboardModel? d) {
    final colors = AppColors.of(context);
    final cards = <Widget>[];

    void add(
      int count,
      String titleKey,
      IconData icon,
      Color color, {
      String? route,
      String subtitleKey = 'awaiting_action',
    }) {
      if (count <= 0) return;
      cards.add(
        StatCard(
          title: titleKey.tr,
          value: '$count',
          icon: icon,
          color: color,
          subtitle: subtitleKey.tr,
          compact: true,
          onTap: route == null ? null : () => Get.toNamed<void>(route),
        ),
      );
    }

    add(
      d?.pendingLeaves ?? 0,
      'pending_leaves',
      Icons.pending_actions_outlined,
      colors.warning,
      route: AppRoutes.leaveManage,
    );
    add(
      d?.pendingBreaks ?? 0,
      'pending_breaks',
      Icons.free_breakfast_outlined,
      colors.warning,
      route: AppRoutes.breakManage,
    );
    add(
      d?.pendingLetters ?? 0,
      'pending_letters',
      Icons.description_outlined,
      colors.brand,
      route: AppRoutes.letters,
    );
    add(
      d?.pendingLoans ?? 0,
      'pending_loans',
      Icons.account_balance_wallet_outlined,
      colors.accentWarm,
      route: AppRoutes.loans,
    );
    add(
      d?.assetsToReturn ?? 0,
      'assets_to_return',
      Icons.inventory_2_outlined,
      colors.error,
      route: AppRoutes.assets,
    );
    add(
      d?.expiringCompliance ?? 0,
      'expiring_compliance',
      Icons.event_busy_outlined,
      colors.error,
      route: AppRoutes.expiringCompliance,
      subtitleKey: 'expiring_soon',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(context, labelKey: 'needs_attention'),
        const SizedBox(height: AppSpacing.s3),
        if (cards.isEmpty) _AllClearCard() else _twoColumnGrid(cards),
      ],
    );
  }

  /// Section header: the quiet label, an optional trailing caption (e.g. the
  /// month), and a "company-wide" note when a customization is active — since
  /// these sections aren't scoped by the branch/shift/category filter.
  Widget _sectionHeader(
    BuildContext context, {
    required String labelKey,
    String? trailing,
  }) {
    final colors = AppColors.of(context);
    final companyWide = ctrl.activeFilterCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(labelKey),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.s2),
              Text('· $trailing', style: AppTextStyles.xs(context)),
            ],
          ],
        ),
        if (companyWide) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: colors.textTertiary),
              const SizedBox(width: 4),
              Text(
                'company_wide_note'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Payroll summary plus this month's expense total, when either is available.
  List<Widget> _financials(BuildContext context, DashboardModel? d) {
    final colors = AppColors.of(context);
    final hasPayroll = d?.payroll != null && d?.payroll?.isEmpty == false;
    final hasExpenses = (d?.monthlyExpenses ?? 0) > 0;
    if (!hasPayroll && !hasExpenses) return const [];

    final monthLabel = DateFormat(
      'MMMM yyyy',
      Get.find<LocaleService>().currentLocale.languageCode,
    ).format(DateTime.now());

    return [
      const SizedBox(height: AppSpacing.s6),
      _sectionHeader(context, labelKey: 'financials', trailing: monthLabel),
      const SizedBox(height: AppSpacing.s3),
      if (hasPayroll) _PayrollSummaryCard(payroll: d!.payroll!),
      if (hasPayroll && hasExpenses) const SizedBox(height: AppSpacing.s2),
      if (hasExpenses)
        StatCard(
          title: 'monthly_expenses'.tr,
          value: _money(d?.monthlyExpenses ?? 0),
          icon: Icons.receipt_long_outlined,
          color: colors.accentWarm,
          compact: true,
          onTap: () => Get.toNamed<void>(AppRoutes.expenses),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = ctrl.dashboard;
    final locale = Get.find<LocaleService>().currentLocale.languageCode;
    final now = DateFormat('EEEE، d MMMM yyyy', locale).format(DateTime.now());
    final auth = Get.find<AuthController>();
    final canCompare =
        (auth.user?.isGeneralManager == true ||
            auth.user?.canViewReports == true) &&
        (d?.branchStats.length ?? 0) > 1;
    final showLive =
        auth.user?.isGeneralManager == true ||
        auth.user?.canViewReports == true;
    final hasFilters = ctrl.hasAnyFilterOptions;
    final headcount = d?.totalEmployees ?? 0; // whole-company (first-run check)
    final active = d?.activeInScope ?? 0; // in-scope active (rate/percent base)
    final filtersActive = ctrl.activeFilterCount > 0;
    // First-run when the company has no employees at all; otherwise a filter
    // that matched nobody.
    final showEmpty =
        d != null && (headcount == 0 || (active == 0 && filtersActive));
    // Each tally's share of the in-scope active employees.
    String pct(int v) =>
        active > 0 ? '${(v / active * 100).toStringAsFixed(1)}%' : '—';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasFilters)
            _CustomizeBar(ctrl: ctrl, dateLabel: now)
          else
            Text(now, style: AppTextStyles.sm(context)),

          // First-run / empty state: no employees (or a filter that matched
          // nobody) means every metric is zero, so guide the user instead of
          // showing a wall of zeros.
          if (showEmpty)
            _DashboardEmptyState(
              hasActiveFilters: headcount > 0,
              onClearFilters: ctrl.clearFilters,
            )
          else ...[
            // Today's attendance — one uniform card grid. "Present" carries its
            // live "inside now" count; checked-out and not-arrived get their own
            // cards. Wrapped in the live controller so the now-values refresh.
            const _SectionLabel('attendance_today'),
            const SizedBox(height: AppSpacing.s3),
            if (showLive)
              GetBuilder<LiveAttendanceController>(
                builder: (lc) => _attendanceGrid(
                  context,
                  d: d,
                  pct: pct,
                  inside: lc.summary.inside,
                  out: lc.summary.out,
                  notIn: lc.summary.notIn,
                  lastUpdated: lc.lastUpdated,
                ),
              )
            else
              _attendanceGrid(context, d: d, pct: pct),

            // Needs attention — an action queue of pending approval counts.
            const SizedBox(height: AppSpacing.s6),
            _needsAttention(context, d),

            // Financials — payroll totals and this month's expenses.
            ..._financials(context, d),
            if (d?.branchStats.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.s6),
              const _SectionLabel('branch_performance'),
              const SizedBox(height: AppSpacing.s3),
              ...d!.branchStats.map((b) => _BranchStatTile(stats: b)),
            ],
            if (canCompare) ...[
              const SizedBox(height: AppSpacing.s6),
              _BranchComparisonSection(ctrl: ctrl),
            ],
          ],
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

/// A compact bar with a "Customize" button (badged with the active filter
/// count) plus chips summarising the currently applied customizations. Tapping
/// the button opens [_FilterPanel] where branch, shift and category can be
/// combined freely.
class _CustomizeBar extends StatelessWidget {
  final DashboardController ctrl;
  final String dateLabel;
  const _CustomizeBar({required this.ctrl, required this.dateLabel});

  String? _branchName(int id) {
    for (final b in ctrl.branches) {
      if ((b['id'] as num?)?.toInt() == id) return b['name'] as String?;
    }
    return null;
  }

  String? _shiftName(int id) {
    for (final s in ctrl.shifts) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  String? _categoryName(int id) {
    for (final c in ctrl.categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = ctrl.activeFilterCount;

    final chips = <Widget>[];
    if (ctrl.selectedBranchId != null) {
      chips.add(
        _FilterChip(
          icon: Icons.account_tree_outlined,
          label: _branchName(ctrl.selectedBranchId!) ?? 'all_branches'.tr,
          onRemove: () => ctrl.applyFilters(
            shiftId: ctrl.selectedShiftId,
            categoryId: ctrl.selectedCategoryId,
          ),
        ),
      );
    }
    if (ctrl.selectedShiftId != null) {
      chips.add(
        _FilterChip(
          icon: Icons.schedule_outlined,
          label: _shiftName(ctrl.selectedShiftId!) ?? 'shift'.tr,
          onRemove: () => ctrl.applyFilters(
            branchId: ctrl.selectedBranchId,
            categoryId: ctrl.selectedCategoryId,
          ),
        ),
      );
    }
    if (ctrl.selectedCategoryId != null) {
      chips.add(
        _FilterChip(
          icon: Icons.category_outlined,
          label: _categoryName(ctrl.selectedCategoryId!) ?? 'all_categories'.tr,
          onRemove: () => ctrl.applyFilters(
            branchId: ctrl.selectedBranchId,
            shiftId: ctrl.selectedShiftId,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(dateLabel, style: AppTextStyles.sm(context))),
            const SizedBox(width: AppSpacing.s3),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => _openPanel(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: count > 0 ? colors.brand : colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: count > 0 ? colors.brand : colors.borderHairline,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.tune,
                      size: 20,
                      color: count > 0 ? Colors.white : colors.textSecondary,
                    ),
                    if (count > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: colors.brand,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...chips,
              TextButton(
                onPressed: ctrl.clearFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'clear_filters'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _openPanel(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterPanel(ctrl: ctrl),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.s3,
        right: AppSpacing.s2,
        top: 6,
        bottom: 6,
      ),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.brand.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.brand),
          const SizedBox(width: AppSpacing.s2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.brand,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Icon(Icons.close, size: 14, color: colors.brand),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet panel that lets the user pick any combination of branch,
/// shift and category, then apply them together.
class _FilterPanel extends StatefulWidget {
  final DashboardController ctrl;
  const _FilterPanel({required this.ctrl});

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late int? _branchId = widget.ctrl.selectedBranchId;
  late int? _shiftId = widget.ctrl.selectedShiftId;
  late int? _categoryId = widget.ctrl.selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ctrl = widget.ctrl;
    final shifts = ctrl.shiftsForBranch(_branchId);

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s4,
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
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text('customize_view'.tr, style: AppTextStyles.h2(context)),
          const SizedBox(height: AppSpacing.s4),
          if (ctrl.branches.isNotEmpty) ...[
            _PanelLabel(text: 'branch'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _branchId,
              hint: 'all_branches'.tr,
              icon: Icons.account_tree_outlined,
              items: ctrl.branches.map((b) {
                final id = (b['id'] as num?)?.toInt();
                return DropdownMenuItem<int?>(
                  value: id,
                  child: Text((b['name'] as String?) ?? ''),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                _branchId = v;
                // Reset shift if it no longer belongs to the chosen branch.
                if (_shiftId != null &&
                    !ctrl.shiftsForBranch(v).any((s) => s.id == _shiftId)) {
                  _shiftId = null;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (shifts.isNotEmpty) ...[
            _PanelLabel(text: 'shift'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _shiftId,
              hint: 'all_shifts'.tr,
              icon: Icons.schedule_outlined,
              items: shifts
                  .map(
                    (s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _shiftId = v),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (ctrl.categories.isNotEmpty) ...[
            _PanelLabel(text: 'category'.tr),
            const SizedBox(height: AppSpacing.s2),
            _FilterDropdown<int?>(
              value: _categoryId,
              hint: 'all_categories'.tr,
              icon: Icons.category_outlined,
              items: ctrl.categories
                  .map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _branchId = null;
                      _shiftId = null;
                      _categoryId = null;
                    });
                  },
                  child: Text(
                    'clear_filters'.tr,
                    style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ctrl.applyFilters(
                      branchId: _branchId,
                      shiftId: _shiftId,
                      categoryId: _categoryId,
                    );
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'apply'.tr,
                    style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
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

class _PanelLabel extends StatelessWidget {
  final String text;
  const _PanelLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'IBM Plex Sans Arabic',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                hint: Text(
                  hint,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                items: [
                  DropdownMenuItem<T>(child: Text(hint)),
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

/// A quiet, uppercase-ish section label. Hierarchy comes from weight and the
/// generous space above each section, not from a heavy heading.
class _SectionLabel extends StatelessWidget {
  final String labelKey;
  const _SectionLabel(this.labelKey);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      labelKey.tr,
      style: TextStyle(
        fontFamily: 'IBM Plex Sans Arabic',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: colors.textSecondary,
      ),
    );
  }
}

/// Calm empty state for the action queue when nothing is pending.
class _AllClearCard extends StatelessWidget {
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
          Icon(Icons.check_circle_outline, size: 18, color: colors.success),
          const SizedBox(width: AppSpacing.s2),
          Text('no_pending_tasks'.tr, style: AppTextStyles.sm(context)),
        ],
      ),
    );
  }
}

/// First-run / empty state for the dashboard. Shows a guiding message and an
/// action (add the first employee, or clear filters when a customization
/// returned no data) instead of a screen full of zeros.
class _DashboardEmptyState extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;
  const _DashboardEmptyState({
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final icon = hasActiveFilters
        ? Icons.filter_alt_off_outlined
        : Icons.groups_outlined;
    final title =
        (hasActiveFilters
                ? 'empty_no_results_title'
                : 'empty_no_employees_title')
            .tr;
    final desc =
        (hasActiveFilters ? 'empty_no_results_desc' : 'empty_no_employees_desc')
            .tr;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: colors.brand),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(title, style: AppTextStyles.h3(context)),
            const SizedBox(height: AppSpacing.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                desc,
                textAlign: TextAlign.center,
                style: AppTextStyles.sm(context),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            if (hasActiveFilters)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.close, size: 18),
                label: Text(
                  'clear_filters'.tr,
                  style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => Get.toNamed<void>(AppRoutes.employeeAdd),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'add_employee'.tr,
                  style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A pulsing placeholder shown on first load — conveys the page structure so it
/// feels faster than a bare spinner.
class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    Widget box(double w, double h, {double r = AppRadius.md}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(r),
      ),
    );

    Widget cardRow() => Row(
      children: [
        Expanded(child: box(double.infinity, 78)),
        const SizedBox(width: AppSpacing.s2),
        Expanded(child: box(double.infinity, 78)),
      ],
    );

    return Semantics(
      label: 'loading'.tr,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 0.9).animate(_c),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box(160, 14, r: AppRadius.sm),
              const SizedBox(height: AppSpacing.s5),
              box(120, 12, r: AppRadius.sm),
              const SizedBox(height: AppSpacing.s3),
              cardRow(),
              const SizedBox(height: AppSpacing.s2),
              cardRow(),
              const SizedBox(height: AppSpacing.s6),
              box(120, 12, r: AppRadius.sm),
              const SizedBox(height: AppSpacing.s3),
              cardRow(),
              const SizedBox(height: AppSpacing.s6),
              box(120, 12, r: AppRadius.sm),
              const SizedBox(height: AppSpacing.s3),
              box(double.infinity, 96, r: AppRadius.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Current-month payroll totals: a prominent net figure with a breakdown of
/// base salary, bonuses and deductions.
class _PayrollSummaryCard extends StatelessWidget {
  final PayrollSummary payroll;
  const _PayrollSummaryCard({required this.payroll});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: colors.brand,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('net_payroll'.tr, style: AppTextStyles.sm(context)),
                    const SizedBox(height: 2),
                    Text(
                      _money(payroll.totalNet),
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Divider(height: 1, color: colors.borderHairline),
          const SizedBox(height: AppSpacing.s3),
          _PayrollRow(
            label: 'base_salaries'.tr,
            value: _money(payroll.totalBase),
            color: colors.textPrimary,
          ),
          const SizedBox(height: AppSpacing.s2),
          _PayrollRow(
            label: 'bonuses'.tr,
            value: '+ ${_money(payroll.totalBonuses)}',
            color: colors.success,
          ),
          const SizedBox(height: AppSpacing.s2),
          _PayrollRow(
            label: 'deductions'.tr,
            value: '- ${_money(payroll.totalDeductions)}',
            color: colors.error,
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            '${'covers'.tr} ${payroll.employeeCount} ${'employees_count'.tr}',
            style: AppTextStyles.sm(context),
          ),
        ],
      ),
    );
  }
}

class _PayrollRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PayrollRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BranchStatTile extends StatelessWidget {
  final BranchStats stats;
  const _BranchStatTile({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
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
                  stats.branchName,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Text(
                  '${stats.present} ${'present_of'.tr} ${stats.totalEmployees}',
                  style: AppTextStyles.sm(context),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stats.attendanceRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: stats.attendanceRate >= 80
                      ? colors.success
                      : stats.attendanceRate >= 50
                      ? colors.warning
                      : colors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BranchComparisonSection extends StatelessWidget {
  final DashboardController ctrl;
  const _BranchComparisonSection({required this.ctrl});

  static const _metricKeys = <BranchMetric, String>{
    BranchMetric.attendanceRate: 'metric_attendance_rate',
    BranchMetric.totalPayroll: 'metric_total_payroll',
    BranchMetric.lateRate: 'metric_late_rate',
    BranchMetric.employeesCount: 'metric_employees_count',
  };

  @override
  Widget build(BuildContext context) {
    final branches = ctrl.dashboard?.branchStats ?? [];
    if (branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Text(
            'no_branches_to_compare'.tr,
            style: AppTextStyles.sm(context),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('branch_comparison'.tr, style: AppTextStyles.h2(context)),
        const SizedBox(height: AppSpacing.s2),
        Text('branch_comparison_hint'.tr, style: AppTextStyles.sm(context)),
        const SizedBox(height: AppSpacing.s4),
        _MetricSelector(ctrl: ctrl),
        const SizedBox(height: AppSpacing.s5),
        _BarChart(ctrl: ctrl),
        const SizedBox(height: AppSpacing.s5),
        Text('branch_performance'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: AppSpacing.s3),
        _BranchSummaryTable(branches: branches),
      ],
    );
  }
}

class _MetricSelector extends StatelessWidget {
  final DashboardController ctrl;
  const _MetricSelector({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: GetBuilder<DashboardController>(
          builder: (_) {
            return Row(
              children: BranchMetric.values.map((m) {
                final selected = ctrl.selectedMetric == m;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.s2),
                  child: ChoiceChip(
                    label: Text(
                      _BranchComparisonSection._metricKeys[m]!.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected ? colors.canvas : colors.textSecondary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: colors.brand,
                    backgroundColor: colors.surface,
                    side: BorderSide(
                      color: selected ? colors.brand : colors.borderHairline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    onSelected: (_) => ctrl.selectMetric(m),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final DashboardController ctrl;
  const _BarChart({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final branches = List<BranchStats>.from(ctrl.dashboard?.branchStats ?? []);
    final metric = ctrl.selectedMetric;

    if (branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s6),
          child: Text(
            'no_branches_to_compare'.tr,
            style: AppTextStyles.sm(context),
          ),
        ),
      );
    }

    branches.sort(
      (a, b) => b.valueForMetric(metric).compareTo(a.valueForMetric(metric)),
    );

    final maxVal = branches
        .map((b) => b.valueForMetric(metric))
        .reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal > 0 ? maxVal : 1.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        children: branches.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          final val = b.valueForMetric(metric);
          final fraction = val / safeMax;
          final isHighest = i == 0;
          final isLowest = i == branches.length - 1 && branches.length > 1;
          final barColor = isHighest
              ? colors.success
              : isLowest
              ? colors.error
              : colors.brand;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: _BarRow(
              name: b.branchName,
              fraction: fraction,
              label: _formatValue(val, metric),
              barColor: barColor,
              badge: isHighest
                  ? 'highest'.tr
                  : isLowest
                  ? 'lowest'.tr
                  : null,
              badgeColor: isHighest
                  ? colors.success
                  : isLowest
                  ? colors.error
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatValue(double val, BranchMetric metric) {
    switch (metric) {
      case BranchMetric.attendanceRate:
      case BranchMetric.lateRate:
        return '${val.toStringAsFixed(1)}%';
      case BranchMetric.totalPayroll:
        return _money(val);
      case BranchMetric.employeesCount:
        return '${val.toInt()} ${'employees_label'.tr}';
    }
  }
}

class _BarRow extends StatelessWidget {
  final String name;
  final double fraction;
  final String label;
  final Color barColor;
  final String? badge;
  final Color? badgeColor;

  const _BarRow({
    required this.name,
    required this.fraction,
    required this.label,
    required this.barColor,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: (badgeColor ?? colors.brand).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor ?? colors.brand,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.sunken,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: fraction.clamp(0.02, 1.0),
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: AlignmentDirectional.centerEnd,
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.s2,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BranchSummaryTable extends StatelessWidget {
  final List<BranchStats> branches;
  const _BranchSummaryTable({required this.branches});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(colors.sunken),
            headingTextStyle: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
            dataTextStyle: TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              color: colors.textPrimary,
            ),
            columnSpacing: AppSpacing.s5,
            horizontalMargin: AppSpacing.s4,
            columns: [
              DataColumn(label: Text('branch_name'.tr)),
              DataColumn(
                label: Text('metric_attendance_rate'.tr),
                numeric: true,
              ),
              DataColumn(label: Text('metric_total_payroll'.tr), numeric: true),
              DataColumn(label: Text('metric_late_rate'.tr), numeric: true),
              DataColumn(
                label: Text('metric_employees_count'.tr),
                numeric: true,
              ),
            ],
            rows: branches.map((b) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      b.branchName,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(Text('${b.attendanceRate.toStringAsFixed(1)}%')),
                  DataCell(Text(_money(b.totalPayroll))),
                  DataCell(Text('${b.effectiveLateRate.toStringAsFixed(1)}%')),
                  DataCell(Text('${b.totalEmployees}')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
