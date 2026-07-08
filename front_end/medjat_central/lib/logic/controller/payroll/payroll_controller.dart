import 'dart:async';

import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/model/payroll_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class PayrollController extends GetxController {
  final PayrollData _payrollData = Get.find<PayrollData>();

  StatusRequest status = StatusRequest.none;
  List<PayrollModel> payrolls = [];
  String searchQuery = '';
  /// One of: 'name', 'net', 'deduction', 'bonus'.
  String sortBy = 'name';
  /// Sort direction. true = ascending (A→Z / lowest first "من الأقل"),
  /// false = descending (Z→A / highest first "من الأعلى").
  bool sortAscending = true;
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int? branchFilter;
  int? shiftFilter;
  int? categoryFilter;
  /// Status to keep when set: one of 'paid', 'approved', 'draft', 'live'.
  /// Null shows every status. Purely client-side — the live overview already
  /// carries each row's status, so toggling this never refetches.
  String? statusFilter;
  /// When true the list is rendered with a header per branch and a subtotal
  /// row at the bottom of each group. Driven by a toolbar toggle.
  bool groupByBranch = false;

  void toggleGroupByBranch() {
    groupByBranch = !groupByBranch;
    update();
  }

  /// Builds the row sequence for the screen. With grouping off, returns the
  /// flat `filteredPayrolls`. With grouping on, returns headers, tiles, and
  /// branch subtotals interleaved. Headers / subtotals are tagged map rows
  /// so the screen's itemBuilder can dispatch.
  List<dynamic> get displayRows {
    final base = filteredPayrolls;
    if (!groupByBranch) return base;

    // Stable grouping on branch_id. Order respects the existing sort —
    // branches appear in the order their first member appears.
    final byBranch = <int?, List<PayrollModel>>{};
    final order = <int?>[];
    for (final p in base) {
      if (!byBranch.containsKey(p.branchId)) {
        byBranch[p.branchId] = [];
        order.add(p.branchId);
      }
      byBranch[p.branchId]!.add(p);
    }

    final rows = <dynamic>[];
    for (final bid in order) {
      final group = byBranch[bid]!;
      final net = group.fold<double>(0, (s, p) => s + p.netSalary);
      rows.add({'_kind': 'header', 'branch_id': bid, 'count': group.length});
      rows.addAll(group);
      rows.add({'_kind': 'subtotal', 'branch_id': bid, 'net': net});
    }
    return rows;
  }
  /// Tenant-default cycle start day (1-28). Drives the picker label and
  /// the date-range hint shown under the month.
  int cycleStartDay = 1;
  /// ISO currency code from tenant settings (EGP, SAR, AED, USD…). Drives
  /// the symbol shown next to amounts.
  String currency = 'EGP';
  /// Earliest hire date among active employees, or null if no one has a hire
  /// date recorded. Caps how far back the picker can navigate.
  DateTime? minHireDate;
  /// Saved totals for the previous label month (only present when payroll
  /// was actually generated for that cycle). Used by the summary card for
  /// the delta arrow.
  PayrollPeriodSummary? previousSummary;
  /// True once the controller has anchored on the default cycle (the latest
  /// *completed* cycle — see [defaultLabelMonth]). Until then loadPayrolls may
  /// auto-correct from the calendar-month seed.
  bool _anchoredOnCurrentCycle = false;

  /// Whether the cycle immediately preceding the (still-open) selected cycle
  /// has every payable employee marked `paid`. The in-advance disburse of an
  /// open cycle is blocked until this is true, so an earlier month is always
  /// paid before a later one. Only computed while [isSelectedCycleOpen].
  bool? _previousSettled;

  /// The `prevLabelMonth|branch` key that [_previousSettled] was computed for,
  /// so a stale answer is never trusted for the wrong selection and we don't
  /// refetch needlessly.
  String? _prevSettledKey;

  /// Monotonically increasing id assigned to every `loadPayrolls` call.
  /// When a slow response arrives after a newer call started, we compare
  /// its captured id against this counter and discard it — protects against
  /// the user rapidly toggling filters and a late response overwriting the
  /// correct state.
  int _loadId = 0;

  /// Add a manual deduction or bonus to an employee, then refresh so the
  /// row's live calculation reflects it immediately. `kind` is 'deduction'
  /// or 'bonus'.
  Future<bool> addAdjustment({
    required int employeeId,
    required String kind,
    required double amount,
    required String reason,
  }) async {
    if (amount <= 0 || reason.trim().isEmpty || employeeId <= 0) return false;
    final response = kind == 'deduction'
        ? await _payrollData.addManualDeduction(
            employeeId: employeeId,
            amount: amount,
            reason: reason.trim(),
          )
        : await _payrollData.addManualBonus(
            employeeId: employeeId,
            amount: amount,
            reason: reason.trim(),
          );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'adjustment_added'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadPayrolls();
      return true;
    }
    Get.snackbar('error'.tr, 'adjustment_add_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  /// Selected label month as "YYYY-MM" — the address the live/disburse
  /// endpoints expect.
  String get _selectedMonthStr =>
      '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';

  /// Human-readable label of the selected month (e.g. "يونيو 2026"), matching
  /// the month-picker formatting. Shown in the disburse confirmation so the
  /// admin sees exactly which month is being paid.
  String get selectedMonthLabel => '${'month_$selectedMonth'.tr} $selectedYear';

  /// True when the selected cycle hasn't ended yet (today falls before its
  /// last day). Disbursing now pays the full month in advance and freezes the
  /// figures, so the UI surfaces a warning before confirming.
  bool get isSelectedCycleOpen {
    final end = cycleWindowTo(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return today.isBefore(endDay);
  }

  /// Disburse one employee's salary for the selected month: walks the
  /// generate → approve → pay state machine in a single call, then refreshes
  /// so the tile flips to "paid". Returns true on success.
  Future<bool> disburseOne(int employeeId) async {
    if (employeeId <= 0) return false;
    if (disburseBlockedByPrevious) {
      Get.snackbar('cannot_disburse'.tr,
          'disburse_prev_required'.trParams({'month': previousLabelMonthStr}),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    final response =
        await _payrollData.disburseEmployee(employeeId, _selectedMonthStr);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'disburse_done'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadPayrolls();
      return true;
    }
    Get.snackbar('error'.tr, 'disburse_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  /// Disburse every in-scope employee's salary for the selected month. Honors
  /// the active branch filter so "pay this branch" pays exactly the rows the
  /// user is viewing. Already-paid slips are skipped server-side.
  Future<bool> disburseMonth() async {
    if (disburseBlockedByPrevious) {
      Get.snackbar('cannot_disburse'.tr,
          'disburse_prev_required'.trParams({'month': previousLabelMonthStr}),
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    final response = await _payrollData.disburseAll(_selectedMonthStr,
        branchId: branchFilter);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'disburse_all_done'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadPayrolls();
      return true;
    }
    Get.snackbar('error'.tr, 'disburse_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  /// True when the cycle is named after its end month (most days fall there).
  /// With a 30/31-day month this is the case once `cycleStartDay >= 17`.
  bool get cycleLabeledByEndMonth => cycleStartDay >= 17;

  /// Selected label month as a DateTime (day = 1 of that month).
  DateTime get selectedDate => DateTime(selectedYear, selectedMonth);

  /// Start date (inclusive) of the cycle whose label month is the picked one.
  DateTime cycleWindowFrom(DateTime labelMonth) {
    if (cycleStartDay <= 1) {
      return DateTime(labelMonth.year, labelMonth.month);
    }
    // End-labeled cycles start in the prior month; start-labeled cycles
    // start in the label month itself.
    final offset = cycleLabeledByEndMonth ? -1 : 0;
    return DateTime(labelMonth.year, labelMonth.month + offset, cycleStartDay);
  }

  /// End date (inclusive) of the cycle whose label month is the picked one.
  DateTime cycleWindowTo(DateTime labelMonth) {
    if (cycleStartDay <= 1) {
      return DateTime(labelMonth.year, labelMonth.month + 1, 0);
    }
    final offset = cycleLabeledByEndMonth ? 0 : 1;
    return DateTime(labelMonth.year, labelMonth.month + offset, cycleStartDay - 1);
  }

  /// Label month of the cycle that contains today — what the picker should
  /// land on by default (and after `cycleStartDay` arrives from the server).
  DateTime currentCycleLabelMonth() => cycleLabelContaining(DateTime.now());

  /// Label month of the cycle that contains [date] (independent of "today").
  DateTime cycleLabelContaining(DateTime date) {
    if (cycleStartDay <= 1) return DateTime(date.year, date.month);
    final startMonthOffset = date.day >= cycleStartDay ? 0 : -1;
    final labelOffset = cycleLabeledByEndMonth ? 1 : 0;
    return DateTime(date.year, date.month + startMonthOffset + labelOffset);
  }

  /// Oldest label month the picker is allowed to reach. Anchored on the
  /// earliest hire date (the cycle that contains it). Null when no employee
  /// has a hire date recorded — in that case the picker is uncapped.
  DateTime? minReachableMonth() {
    final h = minHireDate;
    if (h == null) return null;
    return cycleLabelContaining(h);
  }

  /// Label month the picker defaults to on open: the latest cycle whose last
  /// day has already passed. Companies pay the month that just ended, so we
  /// land on the completed cycle instead of the still-open current one. Clamped
  /// to the earliest reachable month so a brand-new tenant isn't sent before
  /// its first cycle.
  DateTime defaultLabelMonth() {
    final current = currentCycleLabelMonth();
    final end = cycleWindowTo(current);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(end.year, end.month, end.day);
    // Still inside the current cycle → step back to the completed predecessor.
    final target = today.isBefore(endDay)
        ? DateTime(current.year, current.month - 1)
        : current;
    final floor = minReachableMonth();
    if (floor != null && target.isBefore(floor)) return floor;
    return target;
  }

  /// Label month immediately before the selected one (its predecessor cycle).
  DateTime get previousLabelMonth => DateTime(selectedYear, selectedMonth - 1);

  /// Previous label month as "YYYY-MM".
  String get previousLabelMonthStr =>
      '${previousLabelMonth.year}-'
      '${previousLabelMonth.month.toString().padLeft(2, '0')}';

  /// True when disburse must be refused because the selected cycle is still
  /// open (would be paid in advance) and its predecessor isn't fully paid yet.
  /// Completed cycles are never blocked. While the predecessor's paid state is
  /// still being verified we hold (return true) so nothing slips through.
  bool get disburseBlockedByPrevious {
    if (!isSelectedCycleOpen) return false;
    final key = '$previousLabelMonthStr|${branchFilter ?? 'all'}';
    if (_prevSettledKey != key) return true;
    return !(_previousSettled ?? false);
  }

  /// Jump the picker to the previous label month (used by the "pay last month
  /// first" prompt).
  void goToPreviousMonth() =>
      changeMonth(previousLabelMonth.month, previousLabelMonth.year);

  /// While the selected cycle is open, fetch its predecessor and record whether
  /// every payable employee there is already `paid`. A month before the
  /// earliest reachable cycle carries no obligation, so it counts as settled.
  /// Keyed so it runs once per (prev month + branch) and skips silent polls.
  Future<void> _refreshPreviousSettled() async {
    if (!isSelectedCycleOpen) return;
    final key = '$previousLabelMonthStr|${branchFilter ?? 'all'}';
    if (key == _prevSettledKey) return;
    final floor = minReachableMonth();
    if (floor != null && previousLabelMonth.isBefore(floor)) {
      _previousSettled = true;
      _prevSettledKey = key;
      update();
      return;
    }
    final response = await _payrollData.getPayrollLive(
      previousLabelMonth.month,
      previousLabelMonth.year,
      branchId: branchFilter,
    );
    if (response['status'] == StatusRequest.success) {
      final items = _extractItems(_unwrapPayload(response['data']));
      _previousSettled =
          items.isEmpty || items.every((p) => p.status == 'paid');
      _prevSettledKey = key;
      update();
    }
  }

  /// Rows matching search + branch/shift/category, *before* the status
  /// filter and sort. The status counts below derive from this set so a
  /// figure like "3 paid" stays stable while the user toggles the status
  /// filter itself.
  Iterable<PayrollModel> get _scopedPayrolls {
    final q = searchQuery.trim().toLowerCase();
    Iterable<PayrollModel> rows = payrolls;
    if (q.isNotEmpty) {
      rows = rows.where((p) =>
          (p.employeeName ?? '').toLowerCase().contains(q));
    }
    if (branchFilter != null) {
      rows = rows.where((p) => p.branchId == branchFilter);
    }
    if (shiftFilter != null) {
      rows = rows.where((p) => p.shiftId == shiftFilter);
    }
    if (categoryFilter != null) {
      rows = rows.where((p) => p.categoryIds.contains(categoryFilter));
    }
    return rows;
  }

  List<PayrollModel> get filteredPayrolls {
    Iterable<PayrollModel> rows = _scopedPayrolls;
    if (statusFilter != null) {
      // Two-state filter: 'paid' → paid only; 'unpaid' → anything not paid.
      rows = statusFilter == 'paid'
          ? rows.where((p) => p.status == 'paid')
          : rows.where((p) => p.status != 'paid');
    }
    final list = rows.toList();
    list.sort((a, b) {
      int cmp;
      switch (sortBy) {
        case 'net':
          cmp = a.netSalary.compareTo(b.netSalary);
          break;
        case 'deduction':
          cmp = a.totalDeductions.compareTo(b.totalDeductions);
          break;
        case 'bonus':
          cmp = a.totalBonuses.compareTo(b.totalBonuses);
          break;
        case 'name':
        default:
          cmp = (a.employeeName ?? '').compareTo(b.employeeName ?? '');
          break;
      }
      return sortAscending ? cmp : -cmp;
    });
    return list;
  }

  bool get hasActiveFilters =>
      branchFilter != null ||
      shiftFilter != null ||
      categoryFilter != null ||
      statusFilter != null;

  /// How many of the in-scope rows are already marked paid. Drives the
  /// "X paid" badge on the summary card. Computed off [_scopedPayrolls] so
  /// it ignores the status filter (you still see "3 paid" while viewing
  /// only the unpaid rows).
  int get paidCount =>
      _scopedPayrolls.where((p) => p.status == 'paid').length;

  /// Total in-scope rows (regardless of status) — the denominator for the
  /// paid badge ("3 / 12 paid").
  int get scopedCount => _scopedPayrolls.length;

  // ── Aggregates for the summary card ────────────────────────────────
  // All computed off the *filtered* list so the summary reacts to filters.

  /// Sum of earned-to-date for visible rows (the "live" total).
  double get totalNet =>
      filteredPayrolls.fold<double>(0, (s, p) => s + p.netSalary);

  /// Sum of full-cycle projection — apples-to-apples vs the previous
  /// (completed) cycle's saved total.
  double get totalProjectedNet =>
      filteredPayrolls.fold<double>(0, (s, p) => s + p.projectedNet);

  double get totalDeductions =>
      filteredPayrolls.fold<double>(0, (s, p) => s + p.totalDeductions);

  double get totalBonuses =>
      filteredPayrolls.fold<double>(0, (s, p) => s + p.totalBonuses);

  /// Sum of base salary for visible rows (before deductions/bonuses).
  double get totalBase =>
      filteredPayrolls.fold<double>(0, (s, p) => s + p.baseSalary);

  /// Difference of full-cycle projection vs the previous cycle's saved net.
  /// Null when no previous-cycle data is available, or when active filters
  /// make the comparison meaningless (shift/category scope can't be matched
  /// on the backend's saved totals).
  double? get netDeltaVsPrevious {
    if (!previousSummaryApplies) return null;
    final prev = previousSummary;
    if (prev == null || prev.totalNet == 0) return null;
    return totalProjectedNet - prev.totalNet;
  }

  void onSearch(String query) {
    searchQuery = query;
    update();
  }

  void setSortBy(String key) {
    if (sortBy == key) return;
    sortBy = key;
    // Sensible default direction per field: names A→Z, amounts highest-first.
    sortAscending = key == 'name';
    update();
  }

  /// Manually set the sort direction (true = ascending "من الأقل").
  void setSortAscending(bool asc) {
    if (sortAscending == asc) return;
    sortAscending = asc;
    update();
  }

  /// Apply branch / shift / category from the filter sheet at once. Pass
  /// `null` for any dimension that should be cleared.
  ///
  /// Branch changes trigger a backend refetch so the live rows AND the
  /// previous-cycle summary are scoped to the selected branch (otherwise
  /// the delta arrow would compare a branch subset against an all-branches
  /// total). Shift/category filtering stays client-side — the backend
  /// doesn't know about them, so the delta is hidden whenever either is
  /// active (see [previousSummaryApplies]).
  void applyFilters({
    int? branchId,
    int? shiftId,
    int? categoryId,
    String? status,
  }) {
    final branchChanged = branchFilter != branchId;
    branchFilter = branchId;
    shiftFilter = shiftId;
    categoryFilter = categoryId;
    statusFilter = status;
    if (branchChanged) {
      loadPayrolls();
    } else {
      update();
    }
  }

  void clearFilters() {
    final branchWasSet = branchFilter != null;
    branchFilter = null;
    shiftFilter = null;
    categoryFilter = null;
    statusFilter = null;
    if (branchWasSet) {
      loadPayrolls();
    } else {
      update();
    }
  }

  /// True only when the previous-cycle summary scope matches the visible
  /// rows' scope — i.e., no client-side-only filter (shift/category) is
  /// active. Status filter doesn't affect totals semantically (it's a
  /// display filter for which rows to render), so it's ignored here.
  bool get previousSummaryApplies =>
      shiftFilter == null && categoryFilter == null;

  bool get canManagePayroll {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManagePayroll ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Background timer for the polling-based "realtime" refresh. Fires every
  /// 60 seconds and triggers a silent reload, so adjustments made by other
  /// admins show up without a manual refresh.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 60);

  @override
  void onInit() {
    super.onInit();
    loadPayrolls();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  void _poll() {
    if (status == StatusRequest.loading) return;
    // Silent: don't flip status to loading so the list stays visible while
    // the request is in flight — polling shouldn't feel like a UI event.
    loadPayrolls(silent: true);
  }

  Future<void> loadPayrolls({bool silent = false}) async {
    final myId = ++_loadId;
    if (!silent) {
      status = StatusRequest.loading;
      update();
    }

    final response = await _payrollData.getPayrollLive(
      selectedMonth,
      selectedYear,
      branchId: branchFilter,
    );

    // A newer load started while this one was in flight — discard our
    // result so the user's most-recent intent wins.
    if (myId != _loadId) return;

    if (response['status'] == StatusRequest.success) {
      final payload = _unwrapPayload(response['data']);
      payrolls = _extractItems(payload);
      if (payload is Map) {
        final raw = payload['cycle_start_day'];
        if (raw is num) {
          cycleStartDay = raw.toInt().clamp(1, 28);
        }
        final hire = payload['min_hire_date'];
        minHireDate = hire is String ? DateTime.tryParse(hire) : null;
        final cur = payload['currency'];
        if (cur is String && cur.isNotEmpty) currency = cur;
        final prev = payload['previous_summary'];
        previousSummary = prev is Map<String, dynamic>
            ? PayrollPeriodSummary.fromJson(prev)
            : null;
      } else {
        previousSummary = null;
      }
      status = StatusRequest.success;

      // First successful load: snap from the calendar-month seed to the cycle
      // the picker should actually open on — the latest *completed* cycle, so
      // the admin lands on the month that just ended rather than the still-open
      // current one. Re-fetch once for that month; the recursive call gets its
      // own myId, so we return immediately to avoid a stale double-update.
      if (!_anchoredOnCurrentCycle) {
        _anchoredOnCurrentCycle = true;
        final target = defaultLabelMonth();
        if (target.year != selectedYear || target.month != selectedMonth) {
          selectedMonth = target.month;
          selectedYear = target.year;
          update();
          await loadPayrolls();
          return;
        }
      }

      // Gate the in-advance disburse of an open cycle behind its predecessor.
      // No-op (and no extra fetch) for completed cycles or an unchanged
      // selection, so silent polls stay cheap.
      unawaited(_refreshPreviousSettled());
    } else if (!silent) {
      // A user-triggered load that failed — surface the error so they can
      // retry. Silent polls swallow failures and keep the previous data
      // on screen until the next tick.
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  dynamic _unwrapPayload(dynamic raw) {
    if (raw is Map && raw['data'] is Map) return raw['data'];
    return raw;
  }

  List<PayrollModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PayrollModel.fromJson)
        .toList();
  }

  void changeMonth(int month, int year) {
    selectedMonth = month;
    selectedYear = year;
    loadPayrolls();
  }
}

/// Saved totals for a label month, as returned alongside the live overview
/// when comparing the picked cycle to the one before it.
class PayrollPeriodSummary {
  final String month;
  final int employeeCount;
  final double totalNet;
  final double totalDeductions;
  final double totalBonuses;

  const PayrollPeriodSummary({
    required this.month,
    required this.employeeCount,
    required this.totalNet,
    required this.totalDeductions,
    required this.totalBonuses,
  });

  factory PayrollPeriodSummary.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }
    return PayrollPeriodSummary(
      month: (json['month'] as String?) ?? '',
      employeeCount: (json['employee_count'] as num?)?.toInt() ?? 0,
      totalNet: d(json['total_net']),
      totalDeductions: d(json['total_deductions']),
      totalBonuses: d(json['total_bonuses']),
    );
  }
}
