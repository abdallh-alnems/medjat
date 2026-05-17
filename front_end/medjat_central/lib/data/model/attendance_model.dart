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
      id: json['id'] ?? 0,
      employeeId: json['employee_id'] ?? 0,
      employeeName: json['employee_name'],
      checkIn: json['check_in'] != null
          ? DateTime.tryParse(json['check_in'])
          : null,
      checkOut: json['check_out'] != null
          ? DateTime.tryParse(json['check_out'])
          : null,
      status: json['status'] ?? 'present',
      lateMinutes: (json['late_minutes'] as num?)?.toDouble(),
      overtimeMinutes: (json['overtime_minutes'] as num?)?.toDouble(),
      note: json['note'],
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
