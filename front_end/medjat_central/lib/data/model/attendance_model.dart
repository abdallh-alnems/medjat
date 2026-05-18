class AttendanceRecordModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final double? lateMinutes;
  final double? overtimeMinutes;
  final String? note;

  AttendanceRecordModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.checkIn,
    this.checkOut,
    this.status = 'present',
    this.lateMinutes,
    this.overtimeMinutes,
    this.note,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: json['employee_name'] as String?,
      checkIn: json['check_in'] != null
          ? DateTime.tryParse(json['check_in'] as String)
          : null,
      checkOut: json['check_out'] != null
          ? DateTime.tryParse(json['check_out'] as String)
          : null,
      status: (json['status'] as String?) ?? 'present',
      lateMinutes: (json['late_minutes'] as num?)?.toDouble(),
      overtimeMinutes: (json['overtime_minutes'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      case 'late':
        return 'متأخر';
      case 'leave':
        return 'إجازة';
      case 'half_day':
        return 'نصف يوم';
      default:
        return status;
    }
  }
}
