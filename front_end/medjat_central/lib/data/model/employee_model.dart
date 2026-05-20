import 'package:get/get.dart';

class EmployeeModel {
  final int id;
  final int branchId;
  final String name;
  final String? phone;
  final String? photoUrl;
  final String? employeeCode;
  final String? jobTitle;
  final int baseSalary;
  final String status;
  final String? branchName;
  final DateTime? hireDate;
  final String workStartTime;
  final String workEndTime;
  final int? shiftId;
  final String? shiftName;
  final String? shiftStart;
  final String? shiftEnd;
  final String? shiftColor;
  final String? activationCode;
  final String? activationExpiresAt;
  final String biometricEnrollmentStatus;

  EmployeeModel({
    required this.id,
    required this.branchId,
    required this.name,
    this.phone,
    this.photoUrl,
    this.employeeCode,
    this.jobTitle,
    this.baseSalary = 0,
    this.status = 'active',
    this.branchName,
    this.hireDate,
    this.workStartTime = '09:00:00',
    this.workEndTime = '17:00:00',
    this.shiftId,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    this.shiftColor,
    this.activationCode,
    this.activationExpiresAt,
    this.biometricEnrollmentStatus = 'not_enrolled',
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['id'] as int?) ?? 0,
      branchId: (json['branch_id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      employeeCode: json['employee_code'] as String?,
      jobTitle: json['job_title'] as String?,
      baseSalary: (json['base_salary'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'active',
      branchName: json['branch_name'] as String?,
      hireDate: json['hire_date'] != null
          ? DateTime.tryParse(json['hire_date'] as String)
          : null,
      workStartTime: (json['work_start_time'] as String?) ?? '09:00:00',
      workEndTime: (json['work_end_time'] as String?) ?? '17:00:00',
      shiftId: (json['shift_id'] as num?)?.toInt(),
      shiftName: json['shift_name'] as String?,
      shiftStart: json['shift_start'] as String?,
      shiftEnd: json['shift_end'] as String?,
      shiftColor: json['shift_color'] as String?,
      activationCode: json['activation_code'] as String?,
      activationExpiresAt: json['activation_expires_at'] as String?,
      biometricEnrollmentStatus: (json['biometric_enrollment_status'] as String?) ?? 'not_enrolled',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'employee_active'.tr;
      case 'pending_activation':
        return 'pending_activation'.tr;
      case 'inactive':
        return 'status_inactive'.tr;
      case 'suspended':
        return 'employee_suspended'.tr;
      case 'terminated':
        return 'employee_terminated'.tr;
      case 'on_leave':
        return 'employee_on_leave'.tr;
      default:
        return status;
    }
  }
}
