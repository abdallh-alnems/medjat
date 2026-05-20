int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _parseDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class AttendanceReportRow {
  final int employeeId;
  final String employeeName;
  final String? jobTitle;
  final String? branchName;
  final int daysPresent;
  final int daysLate;
  final int daysAbsent;
  final int daysLeave;
  final int daysRecorded;
  final int totalMinutesWorked;

  AttendanceReportRow({
    required this.employeeId,
    required this.employeeName,
    this.jobTitle,
    this.branchName,
    this.daysPresent = 0,
    this.daysLate = 0,
    this.daysAbsent = 0,
    this.daysLeave = 0,
    this.daysRecorded = 0,
    this.totalMinutesWorked = 0,
  });

  factory AttendanceReportRow.fromJson(Map<String, dynamic> json) =>
      AttendanceReportRow(
        employeeId: _parseInt(json['employee_id']),
        employeeName: json['employee_name'] as String? ?? '',
        jobTitle: json['job_title'] as String?,
        branchName: json['branch_name'] as String?,
        daysPresent: _parseInt(json['days_present']),
        daysLate: _parseInt(json['days_late']),
        daysAbsent: _parseInt(json['days_absent']),
        daysLeave: _parseInt(json['days_leave']),
        daysRecorded: _parseInt(json['days_recorded']),
        totalMinutesWorked: _parseInt(json['total_minutes_worked']),
      );

  int get hoursWorked => totalMinutesWorked ~/ 60;
}

class AttendanceReportSummary {
  final int totalPresent;
  final int totalLate;
  final int totalAbsent;
  final int totalLeave;
  final int employeesWithRecords;

  AttendanceReportSummary({
    this.totalPresent = 0,
    this.totalLate = 0,
    this.totalAbsent = 0,
    this.totalLeave = 0,
    this.employeesWithRecords = 0,
  });

  factory AttendanceReportSummary.fromJson(Map<String, dynamic> json) =>
      AttendanceReportSummary(
        totalPresent: _parseInt(json['total_present']),
        totalLate: _parseInt(json['total_late']),
        totalAbsent: _parseInt(json['total_absent']),
        totalLeave: _parseInt(json['total_leave']),
        employeesWithRecords: _parseInt(json['employees_with_records']),
      );
}

class PayrollReportRow {
  final int id;
  final int employeeId;
  final String employeeName;
  final String? jobTitle;
  final String? branchName;
  final double baseSalary;
  final double totalDeductions;
  final double totalBonuses;
  final int overtimeTotalMinutes;
  final double netSalary;
  final String status;

  PayrollReportRow({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.jobTitle,
    this.branchName,
    this.baseSalary = 0,
    this.totalDeductions = 0,
    this.totalBonuses = 0,
    this.overtimeTotalMinutes = 0,
    this.netSalary = 0,
    this.status = 'draft',
  });

  factory PayrollReportRow.fromJson(Map<String, dynamic> json) =>
      PayrollReportRow(
        id: _parseInt(json['id']),
        employeeId: _parseInt(json['employee_id']),
        employeeName: json['employee_name'] as String? ?? '',
        jobTitle: json['job_title'] as String?,
        branchName: json['branch_name'] as String?,
        baseSalary: _parseDouble(json['base_salary']),
        totalDeductions: _parseDouble(json['total_deductions']),
        totalBonuses: _parseDouble(json['total_bonuses']),
        overtimeTotalMinutes: _parseInt(json['overtime_total_minutes']),
        netSalary: _parseDouble(json['net_salary']),
        status: json['status'] as String? ?? 'draft',
      );
}

class PayrollReportSummary {
  final int employeeCount;
  final int draftCount;
  final int approvedCount;
  final int paidCount;
  final double totalBase;
  final double totalDeductions;
  final double totalBonuses;
  final int totalOvertimeMinutes;
  final double totalNet;

  PayrollReportSummary({
    this.employeeCount = 0,
    this.draftCount = 0,
    this.approvedCount = 0,
    this.paidCount = 0,
    this.totalBase = 0,
    this.totalDeductions = 0,
    this.totalBonuses = 0,
    this.totalOvertimeMinutes = 0,
    this.totalNet = 0,
  });

  factory PayrollReportSummary.fromJson(Map<String, dynamic> json) =>
      PayrollReportSummary(
        employeeCount: _parseInt(json['employee_count']),
        draftCount: _parseInt(json['draft_count']),
        approvedCount: _parseInt(json['approved_count']),
        paidCount: _parseInt(json['paid_count']),
        totalBase: _parseDouble(json['total_base']),
        totalDeductions: _parseDouble(json['total_deductions']),
        totalBonuses: _parseDouble(json['total_bonuses']),
        totalOvertimeMinutes: _parseInt(json['total_overtime_minutes']),
        totalNet: _parseDouble(json['total_net']),
      );
}

class EmployeesReportRow {
  final int employeeId;
  final String employeeName;
  final String? jobTitle;
  final String? phone;
  final double baseSalary;
  final String? hireDate;
  final String status;
  final String? branchName;
  final String? shiftName;
  final int daysPresent;
  final int daysLate;
  final int daysAbsent;
  final int daysLeave;
  final int totalMinutesWorked;

  EmployeesReportRow({
    required this.employeeId,
    required this.employeeName,
    this.jobTitle,
    this.phone,
    this.baseSalary = 0,
    this.hireDate,
    this.status = 'active',
    this.branchName,
    this.shiftName,
    this.daysPresent = 0,
    this.daysLate = 0,
    this.daysAbsent = 0,
    this.daysLeave = 0,
    this.totalMinutesWorked = 0,
  });

  factory EmployeesReportRow.fromJson(Map<String, dynamic> json) =>
      EmployeesReportRow(
        employeeId: _parseInt(json['employee_id']),
        employeeName: json['employee_name'] as String? ?? '',
        jobTitle: json['job_title'] as String?,
        phone: json['phone'] as String?,
        baseSalary: _parseDouble(json['base_salary']),
        hireDate: json['hire_date'] as String?,
        status: json['status'] as String? ?? 'active',
        branchName: json['branch_name'] as String?,
        shiftName: json['shift_name'] as String?,
        daysPresent: _parseInt(json['days_present']),
        daysLate: _parseInt(json['days_late']),
        daysAbsent: _parseInt(json['days_absent']),
        daysLeave: _parseInt(json['days_leave']),
        totalMinutesWorked: _parseInt(json['total_minutes_worked']),
      );
}

class EmployeesReportSummary {
  final int totalEmployees;
  final int activeCount;
  final int onLeaveCount;
  final int pendingCount;
  final int suspendedCount;
  final double totalSalaries;
  final int branchCount;

  EmployeesReportSummary({
    this.totalEmployees = 0,
    this.activeCount = 0,
    this.onLeaveCount = 0,
    this.pendingCount = 0,
    this.suspendedCount = 0,
    this.totalSalaries = 0,
    this.branchCount = 0,
  });

  factory EmployeesReportSummary.fromJson(Map<String, dynamic> json) =>
      EmployeesReportSummary(
        totalEmployees: _parseInt(json['total_employees']),
        activeCount: _parseInt(json['active_count']),
        onLeaveCount: _parseInt(json['on_leave_count']),
        pendingCount: _parseInt(json['pending_count']),
        suspendedCount: _parseInt(json['suspended_count']),
        totalSalaries: _parseDouble(json['total_salaries']),
        branchCount: _parseInt(json['branch_count']),
      );
}

class LeavesReportRow {
  final int id;
  final int employeeId;
  final String employeeName;
  final String? branchName;
  final String type;
  final String startDate;
  final String endDate;
  final String? reason;
  final String status;

  LeavesReportRow({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.branchName,
    this.type = 'annual',
    required this.startDate,
    required this.endDate,
    this.reason,
    this.status = 'pending',
  });

  factory LeavesReportRow.fromJson(Map<String, dynamic> json) => LeavesReportRow(
        id: _parseInt(json['id']),
        employeeId: _parseInt(json['employee_id']),
        employeeName: json['employee_name'] as String? ?? '',
        branchName: json['branch_name'] as String?,
        type: json['type'] as String? ?? 'annual',
        startDate: json['start_date'] as String? ?? '',
        endDate: json['end_date'] as String? ?? '',
        reason: json['reason'] as String?,
        status: json['status'] as String? ?? 'pending',
      );
}

class LeavesReportSummary {
  final int totalLeaves;
  final int pendingCount;
  final int approvedCount;
  final int rejectedCount;
  final int annualCount;
  final int sickCount;
  final int personalCount;
  final int unpaidCount;
  final int convertedCount;
  final int employeesOnLeave;

  LeavesReportSummary({
    this.totalLeaves = 0,
    this.pendingCount = 0,
    this.approvedCount = 0,
    this.rejectedCount = 0,
    this.annualCount = 0,
    this.sickCount = 0,
    this.personalCount = 0,
    this.unpaidCount = 0,
    this.convertedCount = 0,
    this.employeesOnLeave = 0,
  });

  factory LeavesReportSummary.fromJson(Map<String, dynamic> json) =>
      LeavesReportSummary(
        totalLeaves: _parseInt(json['total_leaves']),
        pendingCount: _parseInt(json['pending_count']),
        approvedCount: _parseInt(json['approved_count']),
        rejectedCount: _parseInt(json['rejected_count']),
        annualCount: _parseInt(json['annual_count']),
        sickCount: _parseInt(json['sick_count']),
        personalCount: _parseInt(json['personal_count']),
        unpaidCount: _parseInt(json['unpaid_count']),
        convertedCount: _parseInt(json['converted_count']),
        employeesOnLeave: _parseInt(json['employees_on_leave']),
      );
}
