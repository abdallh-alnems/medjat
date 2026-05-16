class UserModel {
  final int id;
  final int tenantId;
  final int branchId;
  final String name;
  final String email;
  final String? phone;
  final String? photoUrl;
  final String roleKey;
  final List<String> permissions;
  final String? employeeCode;
  final String? jobTitle;
  final String? branchName;

  UserModel({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.name,
    required this.email,
    this.phone,
    this.photoUrl,
    required this.roleKey,
    this.permissions = const [],
    this.employeeCode,
    this.jobTitle,
    this.branchName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      tenantId: json['tenant_id'] ?? 0,
      branchId: json['branch_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      photoUrl: json['photo_url'],
      roleKey: json['role_key'] ?? '',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      employeeCode: json['employee_code'],
      jobTitle: json['job_title'],
      branchName: json['branch_name'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'name': name,
        'email': email,
        'phone': phone,
        'photo_url': photoUrl,
        'role_key': roleKey,
        'permissions': permissions,
        'employee_code': employeeCode,
        'job_title': jobTitle,
        'branch_name': branchName,
      };
}
