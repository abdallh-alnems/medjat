class EmployeeModel {
  final int id;
  final int branchId;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? employeeCode;
  final String? jobTitle;
  final double baseSalary;
  final String status;
  final String? branchName;
  final DateTime? hireDate;

  EmployeeModel({
    required this.id,
    required this.branchId,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.employeeCode,
    this.jobTitle,
    this.baseSalary = 0,
    this.status = 'active',
    this.branchName,
    this.hireDate,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['id'] as int?) ?? 0,
      branchId: (json['branch_id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      employeeCode: json['employee_code'] as String?,
      jobTitle: json['job_title'] as String?,
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0,
      status: (json['status'] as String?) ?? 'active',
      branchName: json['branch_name'] as String?,
      hireDate: json['hire_date'] != null
          ? DateTime.tryParse(json['hire_date'] as String)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'inactive':
        return 'غير نشط';
      case 'suspended':
        return 'موقوف';
      default:
        return status;
    }
  }
}
