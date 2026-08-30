class DashboardModel {
  final int totalEmployees;
  final int activeInScope;
  final int presentToday;
  final int presentYesterday;
  final int absentToday;
  final int lateToday;
  final int onLeaveToday;
  final int totalBranches;
  final int pendingLeaves;
  final int pendingLoans;
  final int pendingBreaks;
  final int assetsToReturn;
  final int expiringCompliance;
  final PayrollSummary? payroll;
  final List<BranchStats> branchStats;

  DashboardModel({
    this.totalEmployees = 0,
    this.activeInScope = 0,
    this.presentToday = 0,
    this.presentYesterday = 0,
    this.absentToday = 0,
    this.lateToday = 0,
    this.onLeaveToday = 0,
    this.totalBranches = 0,
    this.pendingLeaves = 0,
    this.pendingLoans = 0,
    this.pendingBreaks = 0,
    this.assetsToReturn = 0,
    this.expiringCompliance = 0,
    this.payroll,
    this.branchStats = const [],
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      totalEmployees: (json['total_employees'] as num?)?.toInt() ?? 0,
      activeInScope: (json['active_in_scope'] as num?)?.toInt() ?? 0,
      presentToday: (json['present_today'] as num?)?.toInt() ?? 0,
      presentYesterday: (json['present_yesterday'] as num?)?.toInt() ?? 0,
      absentToday: (json['absent_today'] as num?)?.toInt() ?? 0,
      lateToday: (json['late_today'] as num?)?.toInt() ?? 0,
      onLeaveToday: (json['on_leave_today'] as num?)?.toInt() ?? 0,
      totalBranches: (json['total_branches'] as num?)?.toInt() ?? 0,
      pendingLeaves: (json['pending_leaves'] as num?)?.toInt() ?? 0,
      pendingLoans: (json['pending_loans'] as num?)?.toInt() ?? 0,
      pendingBreaks: (json['pending_breaks'] as num?)?.toInt() ?? 0,
      assetsToReturn: (json['assets_to_return'] as num?)?.toInt() ?? 0,
      expiringCompliance: (json['expiring_compliance'] as num?)?.toInt() ?? 0,
      payroll: json['payroll_summary'] is Map<String, dynamic>
          ? PayrollSummary.fromJson(
              json['payroll_summary'] as Map<String, dynamic>)
          : null,
      branchStats: (json['branch_stats'] as List<dynamic>?)
              ?.map((e) => BranchStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  // Rate is over the in-scope active employees (matches the applied filter),
  // not the whole-company headcount.
  double get attendanceRate =>
      activeInScope > 0 ? (presentToday / activeInScope) * 100 : 0;

  double get attendanceRateYesterday =>
      activeInScope > 0 ? (presentYesterday / activeInScope) * 100 : 0;

  /// Change in attendance rate vs yesterday, in percentage points.
  double get attendanceTrend => attendanceRate - attendanceRateYesterday;
}

class PayrollSummary {
  final int employeeCount;
  final double totalBase;
  final double totalDeductions;
  final double totalBonuses;
  final double totalNet;

  PayrollSummary({
    this.employeeCount = 0,
    this.totalBase = 0,
    this.totalDeductions = 0,
    this.totalBonuses = 0,
    this.totalNet = 0,
  });

  bool get isEmpty => employeeCount == 0 && totalNet == 0;

  factory PayrollSummary.fromJson(Map<String, dynamic> json) {
    return PayrollSummary(
      employeeCount: (json['employee_count'] as num?)?.toInt() ?? 0,
      totalBase: (json['total_base'] as num?)?.toDouble() ?? 0,
      totalDeductions: (json['total_deductions'] as num?)?.toDouble() ?? 0,
      totalBonuses: (json['total_bonuses'] as num?)?.toDouble() ?? 0,
      totalNet: (json['total_net'] as num?)?.toDouble() ?? 0,
    );
  }
}

enum BranchMetric { attendanceRate, totalPayroll, lateRate, employeesCount }

class BranchStats {
  final int branchId;
  final String branchName;
  final int totalEmployees;
  final int present;
  final int absent;
  final double attendanceRate;
  final double totalPayroll;
  final int late;
  final double lateRate;

  BranchStats({
    required this.branchId,
    required this.branchName,
    this.totalEmployees = 0,
    this.present = 0,
    this.absent = 0,
    this.attendanceRate = 0,
    this.totalPayroll = 0,
    this.late = 0,
    this.lateRate = -1,
  });

  double get effectiveLateRate {
    if (lateRate >= 0) return lateRate;
    if (totalEmployees == 0) return 0;
    return (late / totalEmployees) * 100;
  }

  double valueForMetric(BranchMetric metric) {
    switch (metric) {
      case BranchMetric.attendanceRate:
        return attendanceRate;
      case BranchMetric.totalPayroll:
        return totalPayroll;
      case BranchMetric.lateRate:
        return effectiveLateRate;
      case BranchMetric.employeesCount:
        return totalEmployees.toDouble();
    }
  }

  factory BranchStats.fromJson(Map<String, dynamic> json) {
    final totalEmp = (json['total_employees'] as int?) ?? 0;
    final lateCount = (json['late'] as int?) ?? 0;
    final rawLateRate = (json['late_rate'] as num?)?.toDouble();
    return BranchStats(
      branchId: (json['branch_id'] as int?) ?? 0,
      branchName: (json['branch_name'] as String?) ?? '',
      totalEmployees: totalEmp,
      present: (json['present'] as int?) ?? 0,
      absent: (json['absent'] as int?) ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
      totalPayroll: (json['total_payroll'] as num?)?.toDouble() ?? 0,
      late: lateCount,
      lateRate: rawLateRate ?? -1,
    );
  }
}
