class UserModel {
  final int id;
  final int tenantId;
  final String? tenantName;
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
    this.tenantName,
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
      id: (json['id'] as int?) ?? 0,
      tenantId: (json['tenant_id'] as int?) ?? 0,
      tenantName: json['tenant_name'] as String?,
      branchId: (json['branch_id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      roleKey: (json['role_key'] as String?) ?? '',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      employeeCode: json['employee_code'] as String?,
      jobTitle: json['job_title'] as String?,
      branchName: json['branch_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'tenant_name': tenantName,
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
