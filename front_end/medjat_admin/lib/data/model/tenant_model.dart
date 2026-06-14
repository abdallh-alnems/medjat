class TenantModel {
  final int id;
  final String name;
  final String? nameAr;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;
  final int isActive;
  final String? createdAt;
  final int? employeeCount;
  final int? branchCount;

  TenantModel({
    required this.id,
    required this.name,
    this.nameAr,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
    required this.isActive,
    this.createdAt,
    this.employeeCount,
    this.branchCount,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
      ownerPhone: json['owner_phone'] as String?,
      isActive: json['is_active'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
      employeeCount: json['employee_count'] as int? ?? (json['stats'] as Map<String, dynamic>?)?['employees'] as int?,
      branchCount: json['branch_count'] as int? ?? (json['stats'] as Map<String, dynamic>?)?['branches'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_ar': nameAr,
        'owner_name': ownerName,
        'owner_email': ownerEmail,
        'owner_phone': ownerPhone,
        'is_active': isActive,
      };

  bool get isActiveTenant => isActive == 1;
}
