/// A terminated (ended-service) employee row for the re-hire screen, including
/// the summary of their last end-of-service settlement when one exists.
class TerminatedEmployeeModel {
  final int id;
  final String name;
  final String? phone;
  final String? jobTitle;
  final String? photoUrl;
  final double baseSalary;
  final String? nationalId;
  final int? branchId;
  final String? branchName;
  final DateTime? hireDate;
  final DateTime? terminatedAt;

  /// End-of-service settlement summary (null when no settlement was recorded).
  final String? settlementReason;
  final double? settlementNetAmount;
  final String? settlementStatus;
  final DateTime? settlementLastWorkingDay;

  const TerminatedEmployeeModel({
    required this.id,
    required this.name,
    this.phone,
    this.jobTitle,
    this.photoUrl,
    this.baseSalary = 0,
    this.nationalId,
    this.branchId,
    this.branchName,
    this.hireDate,
    this.terminatedAt,
    this.settlementReason,
    this.settlementNetAmount,
    this.settlementStatus,
    this.settlementLastWorkingDay,
  });

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  static double? _double(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory TerminatedEmployeeModel.fromJson(Map<String, dynamic> json) {
    return TerminatedEmployeeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      phone: json['phone'] as String?,
      jobTitle: json['job_title'] as String?,
      photoUrl: json['profile_image'] as String?,
      baseSalary: _double(json['base_salary']) ?? 0,
      nationalId: json['national_id'] as String?,
      branchId: (json['branch_id'] as num?)?.toInt(),
      branchName: json['branch_name'] as String?,
      hireDate: _date(json['hire_date']),
      terminatedAt: _date(json['terminated_at']),
      settlementReason: json['settlement_reason'] as String?,
      settlementNetAmount: _double(json['settlement_net_amount']),
      settlementStatus: json['settlement_status'] as String?,
      settlementLastWorkingDay: _date(json['settlement_last_working_day']),
    );
  }
}
