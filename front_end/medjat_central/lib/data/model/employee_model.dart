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
      id: json['id'] ?? 0,
      branchId: json['branch_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      photoUrl: json['photo_url'],
      employeeCode: json['employee_code'],
      jobTitle: json['job_title'],
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'active',
      branchName: json['branch_name'],
      hireDate: json['hire_date'] != null
          ? DateTime.tryParse(json['hire_date'])
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
