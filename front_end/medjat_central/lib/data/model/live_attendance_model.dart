/// Derived presence state for a single employee on the live board.
enum LiveStatus { inside, out, notIn, absent, leave, unknown }

LiveStatus liveStatusFromString(String? raw) {
  switch (raw) {
    case 'in':
      return LiveStatus.inside;
    case 'out':
      return LiveStatus.out;
    case 'not_in':
      return LiveStatus.notIn;
    case 'absent':
      return LiveStatus.absent;
    case 'leave':
      return LiveStatus.leave;
    default:
      return LiveStatus.unknown;
  }
}

class LiveAttendanceEntry {
  final int employeeId;
  final String name;
  final String? jobTitle;
  final int? branchId;
  final String? branchName;
  final LiveStatus status;
  final String? checkInTime;
  final String? checkOutTime;
  final int lateMinutes;
  final bool isLate;
  final String? checkInMethod;
  final bool isOffline;

  LiveAttendanceEntry({
    required this.employeeId,
    required this.name,
    this.jobTitle,
    this.branchId,
    this.branchName,
    this.status = LiveStatus.unknown,
    this.checkInTime,
    this.checkOutTime,
    this.lateMinutes = 0,
    this.isLate = false,
    this.checkInMethod,
    this.isOffline = false,
  });

  factory LiveAttendanceEntry.fromJson(Map<String, dynamic> json) {
    return LiveAttendanceEntry(
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      jobTitle: json['job_title'] as String?,
      branchId: (json['branch_id'] as num?)?.toInt(),
      branchName: json['branch_name'] as String?,
      status: liveStatusFromString(json['derived_status'] as String?),
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      lateMinutes: (json['late_minutes'] as num?)?.toInt() ?? 0,
      isLate: (json['is_late'] as bool?) ?? false,
      checkInMethod: json['check_in_method'] as String?,
      isOffline: (json['is_offline'] as bool?) ?? false,
    );
  }
}

class LiveAttendanceSummary {
  final int total;
  final int inside;
  final int out;
  final int notIn;
  final int absent;
  final int leave;
  final int late;

  LiveAttendanceSummary({
    this.total = 0,
    this.inside = 0,
    this.out = 0,
    this.notIn = 0,
    this.absent = 0,
    this.leave = 0,
    this.late = 0,
  });

  factory LiveAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return LiveAttendanceSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      inside: (json['in'] as num?)?.toInt() ?? 0,
      out: (json['out'] as num?)?.toInt() ?? 0,
      notIn: (json['not_in'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
      leave: (json['leave'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
    );
  }
}
