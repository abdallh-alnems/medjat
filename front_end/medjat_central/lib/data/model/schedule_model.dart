// Weekly rotating-shift roster models. The week grid payload contains the employees
// (rows), the 7 dates (columns), the shift palette, and the filled-in ScheduleCells
// keyed by employee + date.

class RosterEmployee {
  final int id;
  final String name;
  final String? jobTitle;
  final int? branchId;
  final String? branchName;
  final String shiftType; // 'fixed' | 'rotating'

  RosterEmployee({
    required this.id,
    required this.name,
    this.jobTitle,
    this.branchId,
    this.branchName,
    this.shiftType = 'fixed',
  });

  factory RosterEmployee.fromJson(Map<String, dynamic> json) => RosterEmployee(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        jobTitle: json['job_title'] as String?,
        branchId: (json['branch_id'] as num?)?.toInt(),
        branchName: json['branch_name'] as String?,
        shiftType: json['shift_type'] as String? ?? 'fixed',
      );
}

class ScheduleCell {
  final int employeeId;
  final String workDate; // YYYY-MM-DD
  final int? shiftId; // null = rest day
  final String status; // 'draft' | 'published'
  final String? shiftName;
  final String? startTime;
  final String? endTime;
  final String? color;

  ScheduleCell({
    required this.employeeId,
    required this.workDate,
    this.shiftId,
    this.status = 'draft',
    this.shiftName,
    this.startTime,
    this.endTime,
    this.color,
  });

  bool get isRest => shiftId == null;
  bool get isDraft => status == 'draft';

  factory ScheduleCell.fromJson(Map<String, dynamic> json) => ScheduleCell(
        employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
        workDate: json['work_date'] as String? ?? '',
        shiftId: (json['shift_id'] as num?)?.toInt(),
        status: json['status'] as String? ?? 'draft',
        shiftName: json['shift_name'] as String?,
        startTime: json['start_time'] as String?,
        endTime: json['end_time'] as String?,
        color: json['color'] as String?,
      );
}
