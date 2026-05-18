class UserModel {
  final int id;
  final int? tenantId;
  final int? branchId;
  final String name;
  final String? phone;
  final String? email;
  final String? role;
  final int? isActive;
  final String? createdAt;
  final String? tenantName;

  UserModel({
    required this.id,
    this.tenantId,
    this.branchId,
    required this.name,
    this.phone,
    this.email,
    this.role,
    this.isActive,
    this.createdAt,
    this.tenantName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      tenantId: json['tenant_id'] as int?,
      branchId: json['branch_id'] as int?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
      isActive: json['is_active'] as int?,
      createdAt: json['created_at'] as String?,
    );
  }

  bool get isActiveUser => isActive == 1;
}
