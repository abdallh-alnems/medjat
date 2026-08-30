import 'package:get/get.dart';

class AttendanceRecordModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final String? branchName;
  final String? shiftName;
  final String? shiftStart;
  final String? shiftEnd;
  final String? date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final double? lateMinutes;
  final double? overtimeMinutes;
  final String? note;
  final String? leaveType;
  final String deductionMode;
  final double? deductionValue;

  /// Which channel recorded each half of the day ('app', 'web', 'device'…).
  final String? checkInOrigin;
  final String? checkOutOrigin;

  /// Whether an image was captured. The path never leaves the server — the
  /// image is fetched by attendance id from `attendance/punch_photo.php`, which
  /// re-checks that the caller may review this employee.
  final bool hasCheckInPhoto;
  final bool hasCheckOutPhoto;

  /// One browser recorded attendance for more than one employee today.
  /// Advisory: both parties carry it and nothing was refused (spec FR-020).
  final bool sharedDeviceFlag;

  AttendanceRecordModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.branchName,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    this.date,
    this.checkIn,
    this.checkOut,
    this.status = 'present',
    this.lateMinutes,
    this.overtimeMinutes,
    this.note,
    this.leaveType,
    this.deductionMode = 'auto',
    this.deductionValue,
    this.checkInOrigin,
    this.checkOutOrigin,
    this.hasCheckInPhoto = false,
    this.hasCheckOutPhoto = false,
    this.sharedDeviceFlag = false,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String?;
    return AttendanceRecordModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: json['employee_name'] as String?,
      branchName: json['branch_name'] as String?,
      shiftName: json['shift_name'] as String?,
      shiftStart: json['shift_start'] as String?,
      shiftEnd: json['shift_end'] as String?,
      date: dateStr,
      checkIn: _combineDateTime(dateStr, json['check_in_time'] ?? json['check_in']),
      checkOut: _combineDateTime(dateStr, json['check_out_time'] ?? json['check_out']),
      status: (json['status'] as String?) ?? 'present',
      lateMinutes: (json['late_minutes'] as num?)?.toDouble(),
      overtimeMinutes: (json['overtime_minutes'] as num?)?.toDouble(),
      note: (json['note'] ?? json['notes']) as String?,
      leaveType: json['leave_type'] as String?,
      deductionMode: (json['deduction_mode'] as String?) ?? 'auto',
      deductionValue: (json['deduction_value'] as num?)?.toDouble(),
      checkInOrigin: json['check_in_origin'] as String?,
      checkOutOrigin: json['check_out_origin'] as String?,
      hasCheckInPhoto: json['has_check_in_photo'] as bool? ?? false,
      hasCheckOutPhoto: json['has_check_out_photo'] as bool? ?? false,
      sharedDeviceFlag: json['shared_device_flag'] as bool? ?? false,
    );
  }

  static DateTime? _combineDateTime(String? date, dynamic time) {
    if (time == null) return null;
    final t = time.toString();
    if (t.isEmpty) return null;
    if (t.contains('T') || t.length > 10) return DateTime.tryParse(t);
    if (date == null || date.isEmpty) return null;
    return DateTime.tryParse('${date}T$t');
  }

  String get statusLabel {
    switch (status) {
      case 'present':
        return 'status_present'.tr;
      case 'absent':
        return 'status_absent'.tr;
      case 'late':
        return 'status_late'.tr;
      case 'leave':
        return 'status_leave'.tr;
      case 'half_day':
        return 'status_half_day'.tr;
      case 'not_arrived':
        return 'status_not_arrived'.tr;
      case 'holiday':
        return 'status_holiday'.tr;
      case 'weekly_off':
        return 'status_weekly_off'.tr;
      default:
        return status;
    }
  }
}
