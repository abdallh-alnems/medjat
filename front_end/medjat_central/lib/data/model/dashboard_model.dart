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
      totalEmployees: json['total_employees'] ?? 0,
      presentToday: json['present_today'] ?? 0,
      absentToday: json['absent_today'] ?? 0,
      lateToday: json['late_today'] ?? 0,
      onLeaveToday: json['on_leave_today'] ?? 0,
      branchStats: (json['branch_stats'] as List<dynamic>?)
              ?.map((e) => BranchStats.fromJson(e))
              .toList() ??
          [],
    );
  }

  double get attendanceRate =>
      totalEmployees > 0 ? (presentToday / totalEmployees) * 100 : 0;
}

class BranchStats {
  final int branchId;
  final String branchName;
  final int totalEmployees;
  final int present;
  final int absent;
  final double attendanceRate;

  BranchStats({
    required this.branchId,
    required this.branchName,
    this.totalEmployees = 0,
    this.present = 0,
    this.absent = 0,
    this.attendanceRate = 0,
  });

  factory BranchStats.fromJson(Map<String, dynamic> json) {
    return BranchStats(
      branchId: json['branch_id'] ?? 0,
      branchName: json['branch_name'] ?? '',
      totalEmployees: json['total_employees'] ?? 0,
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}
