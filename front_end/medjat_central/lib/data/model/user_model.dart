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
      id: (json['id'] as int?) ?? 0,
      tenantId: (json['tenant_id'] as int?) ?? 0,
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

  /// Sentinel so [copyWith] can tell "leave phone unchanged" apart from
  /// "set phone to null" (clearing it).
  static const Object _unset = Object();

  UserModel copyWith({
    String? name,
    Object? phone = _unset,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      tenantId: tenantId,
      branchId: branchId,
      name: name ?? this.name,
      email: email,
      phone: identical(phone, _unset) ? this.phone : phone as String?,
      photoUrl: photoUrl ?? this.photoUrl,
      roleKey: roleKey,
      permissions: permissions,
      employeeCode: employeeCode,
      jobTitle: jobTitle,
      branchName: branchName,
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

  /// The highest role — full access to everything. A company has no "owner";
  /// the creator simply holds this role, and it can be granted to anyone.
  bool get isGeneralManager => roleKey == 'general_manager';
  bool get isHR => roleKey == 'hr';
  bool get isManager => roleKey == 'branch_manager';
  bool get canManageEmployees =>
      isGeneralManager || isHR || permissions.contains('manage_employees');
  bool get canManageAttendance =>
      isGeneralManager ||
      isHR ||
      isManager ||
      permissions.contains('manage_attendance');
  bool get canManagePayroll =>
      isGeneralManager || isHR || permissions.contains('manage_payroll');
  bool get canViewReports =>
      isGeneralManager ||
      isHR ||
      isManager ||
      permissions.contains('view_reports');
  bool get canManageBranches =>
      isGeneralManager || permissions.contains('manage_company_settings');
  bool get canManageCompanySettings =>
      isGeneralManager || permissions.contains('manage_company_settings');
  bool get canAddManagers =>
      isGeneralManager || permissions.contains('add_managers');
  bool get canManageLeaves =>
      isGeneralManager || isHR || permissions.contains('manage_leaves');
  bool get canManageAssets =>
      isGeneralManager ||
      isHR ||
      isManager ||
      permissions.contains('manage_assets');
  bool get canManageDocuments =>
      isGeneralManager ||
      isHR ||
      isManager ||
      permissions.contains('manage_documents');
}
