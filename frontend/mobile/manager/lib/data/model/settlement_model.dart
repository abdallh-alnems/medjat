import 'package:get/get.dart';

double _d(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;

/// A custom editable settlement line — a free-form earning or deduction HR adds.
class SettlementLineItem {
  String label;
  String kind; // 'earning' | 'deduction'
  double amount;

  SettlementLineItem({
    this.label = '',
    this.kind = 'earning',
    this.amount = 0,
  });

  factory SettlementLineItem.fromJson(Map<String, dynamic> json) {
    return SettlementLineItem(
      label: (json['label'] as String?) ?? '',
      kind: (json['kind'] as String?) == 'deduction' ? 'deduction' : 'earning',
      amount: _d(json['amount']),
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'kind': kind,
        'amount': amount,
      };

  bool get isDeduction => kind == 'deduction';
}

/// The computed/saved end-of-service settlement figures. Used both for the
/// suggested (server-computed) values and the saved draft, so the screen can
/// edit a single mutable object.
class SettlementModel {
  int? id;
  String reason;
  String? notes;
  String lastWorkingDay;
  String? hireDate;

  double baseSalary;
  double dailyRate;
  double yearsOfService;

  // Earnings
  double pendingSalary;
  double gratuityDays;
  double gratuityAmount;
  double leaveBalanceDays;
  double leaveEncashment;
  double otherAdditions;

  // Deductions
  double outstandingLoans;
  double otherDeductions;

  List<SettlementLineItem> lineItems;

  String status; // draft | approved | paid (saved); 'new' when not yet saved
  String? approvedByName;
  String? approvedAt;
  String? paidAt;

  SettlementModel({
    this.id,
    this.reason = 'resignation',
    this.notes,
    this.lastWorkingDay = '',
    this.hireDate,
    this.baseSalary = 0,
    this.dailyRate = 0,
    this.yearsOfService = 0,
    this.pendingSalary = 0,
    this.gratuityDays = 0,
    this.gratuityAmount = 0,
    this.leaveBalanceDays = 0,
    this.leaveEncashment = 0,
    this.otherAdditions = 0,
    this.outstandingLoans = 0,
    this.otherDeductions = 0,
    List<SettlementLineItem>? lineItems,
    this.status = 'new',
    this.approvedByName,
    this.approvedAt,
    this.paidAt,
  }) : lineItems = lineItems ?? [];

  /// Build from a saved settlement row.
  factory SettlementModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['line_items'];
    return SettlementModel(
      id: (json['id'] as num?)?.toInt(),
      reason: (json['reason'] as String?) ?? 'resignation',
      notes: json['notes'] as String?,
      lastWorkingDay: (json['last_working_day'] as String?) ?? '',
      hireDate: json['hire_date'] as String?,
      baseSalary: _d(json['base_salary']),
      dailyRate: _d(json['daily_rate']),
      yearsOfService: _d(json['years_of_service']),
      pendingSalary: _d(json['pending_salary']),
      gratuityDays: _d(json['gratuity_days']),
      gratuityAmount: _d(json['gratuity_amount']),
      leaveBalanceDays: _d(json['leave_balance_days']),
      leaveEncashment: _d(json['leave_encashment']),
      otherAdditions: _d(json['other_additions']),
      outstandingLoans: _d(json['outstanding_loans']),
      otherDeductions: _d(json['other_deductions']),
      lineItems: rawItems is List
          ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(SettlementLineItem.fromJson)
              .toList()
          : [],
      status: (json['status'] as String?) ?? 'draft',
      approvedByName: json['approved_by_name'] as String?,
      approvedAt: json['approved_at'] as String?,
      paidAt: json['paid_at'] as String?,
    );
  }

  /// Build the editable figures from the server-computed suggestion. Keeps the
  /// status as 'new' (nothing saved yet).
  factory SettlementModel.fromSuggested(
    Map<String, dynamic> s,
    String lastWorkingDay,
  ) {
    return SettlementModel(
      lastWorkingDay: lastWorkingDay,
      hireDate: s['hire_date'] as String?,
      baseSalary: _d(s['base_salary']),
      dailyRate: _d(s['daily_rate']),
      yearsOfService: _d(s['years_of_service']),
      pendingSalary: _d(s['pending_salary']),
      gratuityDays: _d(s['gratuity_days']),
      gratuityAmount: _d(s['gratuity_amount']),
      leaveBalanceDays: _d(s['leave_balance_days']),
      leaveEncashment: _d(s['leave_encashment']),
      otherAdditions: _d(s['other_additions']),
      outstandingLoans: _d(s['outstanding_loans']),
      otherDeductions: _d(s['other_deductions']),
    );
  }

  /// Overwrite only the auto-computed figures with a fresh suggestion (used
  /// when the last working day changes), preserving reason/notes/custom lines.
  void applySuggested(Map<String, dynamic> s) {
    hireDate = s['hire_date'] as String? ?? hireDate;
    baseSalary = _d(s['base_salary']);
    dailyRate = _d(s['daily_rate']);
    yearsOfService = _d(s['years_of_service']);
    pendingSalary = _d(s['pending_salary']);
    gratuityDays = _d(s['gratuity_days']);
    gratuityAmount = _d(s['gratuity_amount']);
    leaveBalanceDays = _d(s['leave_balance_days']);
    leaveEncashment = _d(s['leave_encashment']);
    outstandingLoans = _d(s['outstanding_loans']);
  }

  Map<String, dynamic> toPayload(int employeeId) => {
        'employee_id': employeeId,
        'reason': reason,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        'last_working_day': lastWorkingDay,
        'hire_date': hireDate,
        'base_salary': baseSalary,
        'daily_rate': dailyRate,
        'years_of_service': yearsOfService,
        'pending_salary': pendingSalary,
        'gratuity_days': gratuityDays,
        'gratuity_amount': gratuityAmount,
        'leave_balance_days': leaveBalanceDays,
        'leave_encashment': leaveEncashment,
        'other_additions': otherAdditions,
        'outstanding_loans': outstandingLoans,
        'other_deductions': otherDeductions,
        'line_items': lineItems.map((e) => e.toJson()).toList(),
      };

  double get customEarnings => lineItems
      .where((e) => !e.isDeduction)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get customDeductions => lineItems
      .where((e) => e.isDeduction)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalEarnings =>
      pendingSalary + gratuityAmount + leaveEncashment + otherAdditions +
      customEarnings;

  double get totalDeductions =>
      outstandingLoans + otherDeductions + customDeductions;

  double get netAmount => totalEarnings - totalDeductions;

  bool get isDraft => status == 'draft' || status == 'new';
  bool get isSaved => id != null;
  bool get isApproved => status == 'approved' || status == 'paid';
  bool get isPaid => status == 'paid';

  String get reasonLabel => 'settlement_reason_$reason'.tr;
  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'settlement_status_approved'.tr;
      case 'paid':
        return 'settlement_status_paid'.tr;
      default:
        return 'settlement_status_draft'.tr;
    }
  }
}
