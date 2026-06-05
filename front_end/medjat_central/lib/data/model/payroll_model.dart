import 'package:get/get.dart';

class PayrollModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final int month;
  final int year;
  final double baseSalary;
  final double totalDeductions;
  final double totalBonuses;
  final double netSalary;
  /// Full-cycle projection (base − deductions + bonuses, base unprorated).
  /// Equals [netSalary] when the cycle is complete; differs in live mode
  /// where [netSalary] is the prorated earned-to-date figure.
  final double projectedNet;
  final String status;
  final DateTime? generatedAt;
  /// When the slip was marked paid, or null if it isn't paid yet. Drives the
  /// "Paid on …" line shown on paid tiles.
  final DateTime? paidAt;
  // Cycle-aware fields from the live overview endpoint. Past/legacy rows omit
  // these — daysElapsed defaulting to daysInCycle keeps progress at 100%.
  final int daysInCycle;
  final int daysElapsed;
  // Used for filtering in the payroll screen (branch / shift / category).
  final int? branchId;
  final int? shiftId;
  final List<int> categoryIds;
  // Previous-cycle saved snapshot for this employee. Null when no payroll
  // was generated for them in the prior month — in that case the tile
  // simply hides the comparison and anomaly chips.
  final double? previousNet;
  final double? previousDeductions;
  final double? previousBonuses;
  // Per-event breakdown — what each deduction / bonus is for. Used by the
  // expandable rows on the tile so users don't need to dive into the
  // employee profile just to see "why is this 4,050?".
  final List<PayrollAdjustment> deductionEvents;
  final List<PayrollAdjustment> bonusEvents;

  PayrollModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.month,
    required this.year,
    this.baseSalary = 0,
    this.totalDeductions = 0,
    this.totalBonuses = 0,
    this.netSalary = 0,
    this.projectedNet = 0,
    this.status = 'draft',
    this.generatedAt,
    this.paidAt,
    this.daysInCycle = 0,
    this.daysElapsed = 0,
    this.branchId,
    this.shiftId,
    this.categoryIds = const [],
    this.previousNet,
    this.previousDeductions,
    this.previousBonuses,
    this.deductionEvents = const [],
    this.bonusEvents = const [],
  });

  /// DECIMAL columns arrive from the API as strings (e.g. "10000.00"),
  /// so accept both numbers and numeric strings.
  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory PayrollModel.fromJson(Map<String, dynamic> json) {
    int month;
    int year;
    final rawMonth = json['month'];
    if (rawMonth is String && rawMonth.contains('-')) {
      // Backend returns "YYYY-MM" for the live overview.
      final parts = rawMonth.split('-');
      year = int.tryParse(parts[0]) ?? DateTime.now().year;
      month = int.tryParse(parts[1]) ?? 1;
    } else {
      month = (rawMonth is int) ? rawMonth : int.tryParse('$rawMonth') ?? 1;
      year = (json['year'] as int?) ?? DateTime.now().year;
    }

    return PayrollModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: json['employee_name'] as String?,
      month: month,
      year: year,
      baseSalary: _parseDouble(json['base_salary']),
      totalDeductions: _parseDouble(json['total_deductions']),
      totalBonuses: _parseDouble(json['total_bonuses']),
      netSalary: _parseDouble(json['net_salary']),
      projectedNet: _parseDouble(json['projected_net'] ?? json['net_salary']),
      status: (json['status'] as String?) ?? 'draft',
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'] as String)
          : null,
      paidAt: json['paid_at'] is String
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      daysInCycle: (json['days_in_cycle'] as num?)?.toInt() ?? 0,
      daysElapsed: (json['days_elapsed'] as num?)?.toInt() ?? 0,
      branchId: (json['branch_id'] as num?)?.toInt(),
      shiftId: (json['shift_id'] as num?)?.toInt(),
      categoryIds: (json['category_ids'] is List)
          ? (json['category_ids'] as List)
              .whereType<num>()
              .map((e) => e.toInt())
              .toList()
          : const [],
      previousNet: json['previous_net'] == null
          ? null
          : _parseDouble(json['previous_net']),
      previousDeductions: json['previous_deductions'] == null
          ? null
          : _parseDouble(json['previous_deductions']),
      previousBonuses: json['previous_bonuses'] == null
          ? null
          : _parseDouble(json['previous_bonuses']),
      deductionEvents: _parseEvents(json['deductions_breakdown']),
      bonusEvents: _parseEvents(json['bonuses_breakdown']),
    );
  }

  static List<PayrollAdjustment> _parseEvents(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => PayrollAdjustment.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  /// Difference of this cycle's projected net vs the previous cycle's saved
  /// net. Null when there's no previous data to compare against.
  double? get netDeltaVsPrevious {
    final pn = previousNet;
    if (pn == null) return null;
    return projectedNet - pn;
  }

  /// Returns an anomaly category that the tile should flag, or null when
  /// nothing looks unusual. Compares the full-cycle projection so a partial
  /// month doesn't look like a "net drop" just because it isn't over yet.
  ///
  /// - `deduction_spike`: deductions jumped vs the prior month (≥50% more,
  ///   or any deductions where there were none before).
  /// - `net_drop`: projected net is materially lower than last month
  ///   (≥30% drop) even before deductions normalise.
  String? get anomalyKind {
    final pd = previousDeductions;
    if (pd != null) {
      if (pd == 0 && totalDeductions > 0) return 'deduction_spike';
      if (pd > 0 && (totalDeductions - pd) / pd >= 0.5) {
        return 'deduction_spike';
      }
    }
    final pn = previousNet;
    if (pn != null && pn > 0) {
      if ((projectedNet - pn) / pn <= -0.3) return 'net_drop';
    }
    return null;
  }

  double get cycleProgress {
    if (daysInCycle <= 0) return 0;
    return (daysElapsed / daysInCycle).clamp(0, 1).toDouble();
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'status_draft'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'paid':
        return 'status_paid'.tr;
      case 'live':
        return 'status_live'.tr;
      default:
        return status;
    }
  }

  String get monthLabel {
    return '${'month_$month'.tr} $year';
  }
}

/// A single line in a payroll's deduction / bonus breakdown — used by the
/// expandable rows on the payroll tile.
class PayrollAdjustment {
  final String type;
  final String? date;
  final double amount;
  final String description;

  const PayrollAdjustment({
    required this.type,
    this.date,
    required this.amount,
    required this.description,
  });

  factory PayrollAdjustment.fromJson(Map<String, dynamic> json) {
    double amount;
    final raw = json['amount'];
    if (raw is num) {
      amount = raw.toDouble();
    } else if (raw is String) {
      amount = double.tryParse(raw) ?? 0;
    } else {
      amount = 0;
    }
    return PayrollAdjustment(
      type: (json['type'] as String?) ?? 'manual',
      date: json['date']?.toString(),
      amount: amount,
      description: (json['description'] as String?) ?? '',
    );
  }
}
