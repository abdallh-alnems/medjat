import 'package:get/get.dart';

class EmployeeModel {
  final int id;
  final int branchId;
  final String name;
  final String? phone;
  final String? photoUrl;
  final String? employeeCode;
  final String? jobTitle;
  final double baseSalary;
  final String status;
  final String? branchName;
  final DateTime? hireDate;
  final String workStartTime;
  final String workEndTime;
  final int? annualLeaveDays;
  final int? shiftId;
  final String? shiftName;
  final String? shiftStart;
  final String? shiftEnd;
  final String? shiftColor;
  final String? activationCode;
  final String? activationExpiresAt;
  final String biometricEnrollmentStatus;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIban;
  final String? bankSwift;
  // Compliance / legal credentials
  final String? nationalId;
  final String? nationality;
  final String? iqamaNumber;
  final DateTime? iqamaExpiry;
  final String? passportNumber;
  final DateTime? passportExpiry;
  final String? workPermitNumber;
  final DateTime? workPermitExpiry;
  final String? contractType;
  final DateTime? contractStart;
  final DateTime? contractEnd;
  final DateTime? healthInsuranceExpiry;
  final DateTime? autoTerminateAt;

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
    this.annualLeaveDays,
    this.shiftId,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    this.shiftColor,
    this.activationCode,
    this.activationExpiresAt,
    this.biometricEnrollmentStatus = 'not_enrolled',
    this.bankName,
    this.bankAccountNumber,
    this.bankIban,
    this.bankSwift,
    this.nationalId,
    this.nationality,
    this.iqamaNumber,
    this.iqamaExpiry,
    this.passportNumber,
    this.passportExpiry,
    this.workPermitNumber,
    this.workPermitExpiry,
    this.contractType,
    this.contractStart,
    this.contractEnd,
    this.healthInsuranceExpiry,
    this.autoTerminateAt,
  });

  static DateTime? _parseDate(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  /// DECIMAL columns come back from the API as strings (e.g. "4500.50"),
  /// so accept both numbers and numeric strings.
  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['id'] as int?) ?? 0,
      branchId: (json['branch_id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      employeeCode: json['employee_code'] as String?,
      jobTitle: json['job_title'] as String?,
      baseSalary: _parseDouble(json['base_salary']),
      status: (json['status'] as String?) ?? 'active',
      branchName: json['branch_name'] as String?,
      hireDate: json['hire_date'] != null
          ? DateTime.tryParse(json['hire_date'] as String)
          : null,
      workStartTime: (json['work_start_time'] as String?) ?? '09:00:00',
      workEndTime: (json['work_end_time'] as String?) ?? '17:00:00',
      annualLeaveDays: (json['annual_leave_days'] as num?)?.toInt(),
      shiftId: (json['shift_id'] as num?)?.toInt(),
      shiftName: json['shift_name'] as String?,
      shiftStart: json['shift_start'] as String?,
      shiftEnd: json['shift_end'] as String?,
      shiftColor: json['shift_color'] as String?,
      activationCode: json['activation_code'] as String?,
      activationExpiresAt: json['activation_expires_at'] as String?,
      biometricEnrollmentStatus: (json['biometric_enrollment_status'] as String?) ?? 'not_enrolled',
      bankName: json['bank_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      bankIban: json['bank_iban'] as String?,
      bankSwift: json['bank_swift'] as String?,
      nationalId: json['national_id'] as String?,
      nationality: json['nationality'] as String?,
      iqamaNumber: json['iqama_number'] as String?,
      iqamaExpiry: _parseDate(json['iqama_expiry']),
      passportNumber: json['passport_number'] as String?,
      passportExpiry: _parseDate(json['passport_expiry']),
      workPermitNumber: json['work_permit_number'] as String?,
      workPermitExpiry: _parseDate(json['work_permit_expiry']),
      contractType: json['contract_type'] as String?,
      contractStart: _parseDate(json['contract_start']),
      contractEnd: _parseDate(json['contract_end']),
      healthInsuranceExpiry: _parseDate(json['health_insurance_expiry']),
      autoTerminateAt: _parseDate(json['auto_terminate_at']),
    );
  }

  bool get hasComplianceInfo =>
      (nationalId?.isNotEmpty ?? false) ||
      (nationality?.isNotEmpty ?? false) ||
      (iqamaNumber?.isNotEmpty ?? false) ||
      iqamaExpiry != null ||
      (passportNumber?.isNotEmpty ?? false) ||
      passportExpiry != null ||
      (workPermitNumber?.isNotEmpty ?? false) ||
      workPermitExpiry != null ||
      contractType != null ||
      contractStart != null ||
      contractEnd != null ||
      healthInsuranceExpiry != null;

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
