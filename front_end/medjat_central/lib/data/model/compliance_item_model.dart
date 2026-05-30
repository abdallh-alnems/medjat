/// One expiring (or expired) compliance credential for an employee.
class ComplianceItem {
  final int employeeId;
  final String employeeName;
  final String? branchName;
  final String credential; // iqama | passport | work_permit | contract | health_insurance
  final String? number;
  final String expiresAt; // YYYY-MM-DD
  final int daysLeft; // negative = already expired
  final bool isExpired;

  ComplianceItem({
    required this.employeeId,
    required this.employeeName,
    this.branchName,
    required this.credential,
    this.number,
    required this.expiresAt,
    required this.daysLeft,
    required this.isExpired,
  });

  factory ComplianceItem.fromJson(Map<String, dynamic> json) => ComplianceItem(
        employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
        employeeName: (json['employee_name'] as String?) ?? '',
        branchName: json['branch_name'] as String?,
        credential: (json['credential'] as String?) ?? '',
        number: json['number'] as String?,
        expiresAt: (json['expires_at'] as String?) ?? '',
        daysLeft: (json['days_left'] as num?)?.toInt() ?? 0,
        isExpired: json['is_expired'] == true || json['is_expired'] == 1,
      );

  /// Localization key for the credential label.
  String get credentialKey => 'credential_$credential';
}
