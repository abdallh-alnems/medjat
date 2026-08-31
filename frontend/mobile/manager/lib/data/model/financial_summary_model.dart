import 'package:get/get.dart';

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class FinancialAdjustment {
  /// Only populated for `type == 'manual'` rows (manual_deductions /
  /// manual_bonuses). Derived rows (absence, late, loan, statutory…) leave
  /// this null — they aren't editable from the financial tab.
  final int? id;
  final String type;
  final String? date;
  final double amount;
  final String description;
  /// Username of the admin who created this manual line (null for derived
  /// entries like late/absence/overtime/statutory).
  final String? createdByName;

  /// True when a per-line override changed this computed line's amount.
  final bool overridden;

  /// The original computed amount before an override was applied (null unless
  /// [overridden]).
  final double? originalAmount;

  FinancialAdjustment({
    this.id,
    required this.type,
    this.date,
    required this.amount,
    required this.description,
    this.createdByName,
    this.overridden = false,
    this.originalAmount,
  });

  bool get isManual => type == 'manual' && id != null;

  /// Derived (computed) lines — absence/late/loan/insurance/tax/overtime… —
  /// can be edited or removed for the month via per-line overrides.
  bool get isOverridable => type != 'manual';

  factory FinancialAdjustment.fromJson(Map<String, dynamic> json) {
    return FinancialAdjustment(
      id: (json['id'] as num?)?.toInt(),
      type: (json['type'] as String?) ?? 'manual',
      date: json['date'] as String?,
      amount: _toDouble(json['amount']),
      description: (json['description'] as String?) ?? '',
      createdByName: json['created_by_name'] as String?,
      overridden: (json['overridden'] as bool?) ?? false,
      originalAmount: json['original_amount'] != null
          ? _toDouble(json['original_amount'])
          : null,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'absence':
        return 'deduction_type_absence'.tr;
      case 'late':
        return 'deduction_type_late'.tr;
      case 'early_leave':
        return 'deduction_type_early_leave'.tr;
      case 'loan':
        return 'deduction_type_loan'.tr;
      case 'social_insurance':
        return 'deduction_type_insurance'.tr;
      case 'income_tax':
        return 'deduction_type_tax'.tr;
      case 'overtime':
        return 'bonus_type_overtime'.tr;
      case 'manual':
        return 'adjustment_type_manual'.tr;
      default:
        return type;
    }
  }
}

class FinancialMonthSummary {
  final double baseSalary;
  final double totalDeductions;
  final double totalBonuses;
  final double netSalary;
  final List<FinancialAdjustment> deductions;
  final List<FinancialAdjustment> bonuses;
  final String status;
  /// True once the slip is approved/paid: the figures above are the frozen
  /// snapshot captured at approval, not a live recalculation. Drafts are live
  /// estimates and are not locked.
  final bool locked;
  final int daysInMonth;
  final int daysElapsed;
  final double proratedBaseSalary;
  final double earnedToDate;
  final String? cycleFrom;
  final String? cycleTo;
  final Map<String, int> attendance;
  final StatutoryBreakdown? statutory;
  final int? payrollId;
  final String? approvedAt;
  final String? approvedByName;
  final String? paidAt;
  final PayrollRules? rules;

  int get attPresent => attendance['present'] ?? 0;
  int get attLate => attendance['late'] ?? 0;
  int get attAbsent => attendance['absent'] ?? 0;
  int get attLeave =>
      (attendance['leave'] ?? 0) +
      (attendance['holiday'] ?? 0) +
      (attendance['weekly_off'] ?? 0);
  int get attWorkedMinutes => attendance['worked_minutes'] ?? 0;
  int get attOvertimeMinutes => attendance['overtime_minutes'] ?? 0;
  int get attLateMinutes => attendance['late_minutes'] ?? 0;

  FinancialMonthSummary({
    required this.baseSalary,
    required this.totalDeductions,
    required this.totalBonuses,
    required this.netSalary,
    required this.deductions,
    required this.bonuses,
    required this.status,
    this.locked = false,
    required this.daysInMonth,
    required this.daysElapsed,
    required this.proratedBaseSalary,
    required this.earnedToDate,
    this.cycleFrom,
    this.cycleTo,
    this.attendance = const {},
    this.statutory,
    this.payrollId,
    this.approvedAt,
    this.approvedByName,
    this.paidAt,
    this.rules,
  });

  factory FinancialMonthSummary.fromJson(Map<String, dynamic> json) {
    return FinancialMonthSummary(
      baseSalary: _toDouble(json['base_salary']),
      totalDeductions: _toDouble(json['total_deductions']),
      totalBonuses: _toDouble(json['total_bonuses']),
      netSalary: _toDouble(json['net_salary']),
      daysInMonth: (json['days_in_month'] as num?)?.toInt() ?? 0,
      daysElapsed: (json['days_elapsed'] as num?)?.toInt() ?? 0,
      proratedBaseSalary: _toDouble(json['prorated_base_salary']),
      earnedToDate: _toDouble(json['earned_to_date']),
      cycleFrom: json['cycle_from'] as String?,
      cycleTo: json['cycle_to'] as String?,
      attendance: (json['attendance'] is Map)
          ? (json['attendance'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : const {},
      statutory: json['statutory'] is Map<String, dynamic>
          ? StatutoryBreakdown.fromJson(json['statutory'] as Map<String, dynamic>)
          : null,
      payrollId: (json['payroll_id'] as num?)?.toInt(),
      approvedAt: json['approved_at'] as String?,
      approvedByName: json['approved_by_name'] as String?,
      paidAt: json['paid_at'] as String?,
      rules: json['rules'] is Map<String, dynamic>
          ? PayrollRules.fromJson(json['rules'] as Map<String, dynamic>)
          : null,
      deductions: (json['deductions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FinancialAdjustment.fromJson)
          .toList(),
      bonuses: (json['bonuses'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FinancialAdjustment.fromJson)
          .toList(),
      status: (json['status'] as String?) ?? 'draft',
      locked: (json['locked'] as bool?) ??
          (json['status'] == 'approved' || json['status'] == 'paid'),
    );
  }
}

/// Recurring monthly allowance (housing, transport, food…). Stored in its
/// own table on the backend but emitted into the bonuses_breakdown by the
/// payroll calculator as `type='allowance'` lines so payroll math stays
/// unchanged. The financial tab filters those lines out of the bonuses card
/// and renders them in a dedicated allowances card instead.
class Allowance {
  final int id;
  final int employeeId;
  final String type;
  final String? label;
  final double amount;
  final String startMonth;
  final String? endMonth;

  Allowance({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.amount,
    required this.startMonth,
    this.label,
    this.endMonth,
  });

  factory Allowance.fromJson(Map<String, dynamic> json) {
    return Allowance(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String?) ?? 'other',
      label: json['label'] as String?,
      amount: _toDouble(json['amount']),
      startMonth: (json['start_month'] as String?) ?? '',
      endMonth: json['end_month'] as String?,
    );
  }

  /// Display label: explicit user-set [label] wins, else translated [type].
  String get displayLabel {
    final l = (label ?? '').trim();
    if (l.isNotEmpty) return l;
    switch (type) {
      case 'housing':
        return 'allowance_type_housing'.tr;
      case 'transport':
        return 'allowance_type_transport'.tr;
      case 'food':
        return 'allowance_type_food'.tr;
      case 'communication':
        return 'allowance_type_communication'.tr;
      case 'other':
        return 'allowance_type_other'.tr;
      default:
        return type;
    }
  }

  /// True when this allowance is still active (no end_month, or end_month
  /// hasn't passed yet relative to the current month).
  bool isActive(String currentMonth) {
    if (startMonth.compareTo(currentMonth) > 0) return false;
    if (endMonth == null) return true;
    return endMonth!.compareTo(currentMonth) >= 0;
  }
}

/// One active or pending loan/advance with paid / remaining totals so the
/// financial tab can render a balance + schedule snapshot without an extra
/// round-trip.
class LoanSummary {
  final int id;
  final String type; // 'loan' | 'advance'
  final double totalAmount;
  final double installmentAmount;
  final int installmentsCount;
  final int installmentsPaid;
  final String startMonth; // YYYY-MM
  final String? reason;
  final String status; // 'pending' | 'active'
  final double paidAmount;
  final double remainingAmount;
  final String? nextDueMonth; // YYYY-MM
  final int remainingInstallments;

  LoanSummary({
    required this.id,
    required this.type,
    required this.totalAmount,
    required this.installmentAmount,
    required this.installmentsCount,
    required this.installmentsPaid,
    required this.startMonth,
    required this.status,
    required this.paidAmount,
    required this.remainingAmount,
    required this.remainingInstallments,
    this.reason,
    this.nextDueMonth,
  });

  factory LoanSummary.fromJson(Map<String, dynamic> json) {
    return LoanSummary(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: (json['type'] as String?) ?? 'loan',
      totalAmount: _toDouble(json['total_amount']),
      installmentAmount: _toDouble(json['installment_amount']),
      installmentsCount: (json['installments_count'] as num?)?.toInt() ?? 0,
      installmentsPaid: (json['installments_paid'] as num?)?.toInt() ?? 0,
      startMonth: (json['start_month'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      paidAmount: _toDouble(json['paid_amount']),
      remainingAmount: _toDouble(json['remaining_amount']),
      remainingInstallments:
          (json['remaining_installments'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
      nextDueMonth: json['next_due_month'] as String?,
    );
  }

  /// Localised label for the loan type.
  String get typeLabel =>
      type == 'advance' ? 'loan_type_advance'.tr : 'loan_type_loan'.tr;

  /// Localised status label.
  String get statusLabel =>
      status == 'pending' ? 'loan_status_pending'.tr : 'loan_status_active'.tr;
}

/// One entry in the base-salary change history (reconstructed from the audit
/// log). Renders in the financial tab as a small timeline so the admin can
/// see when and by whom the salary was last changed.
class SalaryChange {
  final String createdAt;
  final String? adminName;
  final double baseSalary;

  SalaryChange({
    required this.createdAt,
    required this.baseSalary,
    this.adminName,
  });

  factory SalaryChange.fromJson(Map<String, dynamic> json) {
    return SalaryChange(
      createdAt: (json['created_at'] as String?) ?? '',
      adminName: json['admin_name'] as String?,
      baseSalary: _toDouble(json['base_salary']),
    );
  }
}

/// Snapshot of the tenant's active payroll rules at calculation time. Used by
/// the rule-transparency card so the admin/employee sees exactly *how* late /
/// absence / overtime are converted to amounts. All fields nullable — missing
/// values mean the rule isn't configured (falls back to PayrollCalculator
/// defaults).
class PayrollRules {
  final String? lateType; // 'proportional' | 'fixed'
  final double? lateUnitMinutes;
  final double? lateDeductionPerUnit;
  final double? lateFixedAmount;
  final double? absenceMultiplier;
  final double? overtimeMultiplier;

  PayrollRules({
    this.lateType,
    this.lateUnitMinutes,
    this.lateDeductionPerUnit,
    this.lateFixedAmount,
    this.absenceMultiplier,
    this.overtimeMultiplier,
  });

  factory PayrollRules.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    return PayrollRules(
      lateType: json['late_type'] as String?,
      lateUnitMinutes: toDouble(json['late_unit_minutes']),
      lateDeductionPerUnit: toDouble(json['late_deduction_per_unit']),
      lateFixedAmount: toDouble(json['late_fixed_amount']),
      absenceMultiplier: toDouble(json['absence_multiplier']),
      overtimeMultiplier: toDouble(json['overtime_multiplier']),
    );
  }

  bool get hasAny =>
      lateType != null ||
      absenceMultiplier != null ||
      overtimeMultiplier != null ||
      lateDeductionPerUnit != null ||
      lateFixedAmount != null;
}

/// End-of-Service Benefits — accumulated entitlement from hire date to now,
/// computed by `v1/payroll/eosb`. When [enabled] is false the
/// tenant has the EOSB feature disabled and the card stays hidden.
class EosbInfo {
  final bool enabled;
  final String? hireDate;
  final double yearsOfService;
  final double eosbDaysPerYear;
  final double dailyWage;
  final double eosbAmount;
  final String? message;

  EosbInfo({
    required this.enabled,
    this.hireDate,
    this.yearsOfService = 0,
    this.eosbDaysPerYear = 0,
    this.dailyWage = 0,
    this.eosbAmount = 0,
    this.message,
  });

  factory EosbInfo.fromJson(Map<String, dynamic> json) {
    return EosbInfo(
      enabled: (json['enabled'] as bool?) ?? false,
      hireDate: json['hire_date'] as String?,
      yearsOfService: _toDouble(json['years_of_service']),
      eosbDaysPerYear: _toDouble(json['eosb_days_per_year']),
      dailyWage: _toDouble(json['daily_wage']),
      eosbAmount: _toDouble(json['eosb_amount']),
      message: json['message'] as String?,
    );
  }
}

/// Statutory deductions (social insurance, income tax) broken out for the
/// transparency card in the financial tab. All amounts are monthly.
class StatutoryBreakdown {
  final double insuranceEmployee;
  final double insuranceEmployer;
  final double incomeTax;
  final double taxableIncome;

  StatutoryBreakdown({
    required this.insuranceEmployee,
    required this.insuranceEmployer,
    required this.incomeTax,
    required this.taxableIncome,
  });

  factory StatutoryBreakdown.fromJson(Map<String, dynamic> json) {
    return StatutoryBreakdown(
      insuranceEmployee: _toDouble(json['insurance_employee']),
      insuranceEmployer: _toDouble(json['insurance_employer']),
      incomeTax: _toDouble(json['income_tax']),
      taxableIncome: _toDouble(json['taxable_income']),
    );
  }

  bool get hasAny =>
      insuranceEmployee > 0 || insuranceEmployer > 0 || incomeTax > 0;
}

class FinancialHistoryEntry {
  final int id;
  final String month;
  final double baseSalary;
  final double totalDeductions;
  final double totalBonuses;
  final double netSalary;
  final String status;

  FinancialHistoryEntry({
    required this.id,
    required this.month,
    required this.baseSalary,
    required this.totalDeductions,
    required this.totalBonuses,
    required this.netSalary,
    required this.status,
  });

  factory FinancialHistoryEntry.fromJson(Map<String, dynamic> json) {
    return FinancialHistoryEntry(
      id: (json['id'] as int?) ?? 0,
      month: (json['month'] as String?) ?? '',
      baseSalary: _toDouble(json['base_salary']),
      totalDeductions: _toDouble(json['total_deductions']),
      totalBonuses: _toDouble(json['total_bonuses']),
      netSalary: _toDouble(json['net_salary']),
      status: (json['status'] as String?) ?? 'draft',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'status_draft'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'paid':
        return 'status_paid'.tr;
      default:
        return status;
    }
  }
}
