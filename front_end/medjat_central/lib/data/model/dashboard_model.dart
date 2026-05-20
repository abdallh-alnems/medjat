class DashboardModel {
  final int totalEmployees;
  final int presentToday;
  final int absentToday;
  final int lateToday;
  final int onLeaveToday;
  final List<BranchStats> branchStats;

  DashboardModel({
    this.totalEmployees = 0,
    this.presentToday = 0,
    this.absentToday = 0,
    this.lateToday = 0,
    this.onLeaveToday = 0,
    this.branchStats = const [],
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      totalEmployees: (json['total_employees'] as int?) ?? 0,
      presentToday: (json['present_today'] as int?) ?? 0,
      absentToday: (json['absent_today'] as int?) ?? 0,
      lateToday: (json['late_today'] as int?) ?? 0,
      onLeaveToday: (json['on_leave_today'] as int?) ?? 0,
      branchStats: (json['branch_stats'] as List<dynamic>?)
              ?.map((e) => BranchStats.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  double get attendanceRate =>
      totalEmployees > 0 ? (presentToday / totalEmployees) * 100 : 0;
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
