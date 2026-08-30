/// One client company as it appears in the list.
///
/// The old model read `name_ar`, `owner_name`, `owner_email` and `owner_phone`
/// — columns that have never existed on `tenants`, so every card showed a name
/// and nothing else. The contact fields here are the real ones (added by
/// migrations/2026_08_05_tenant_contact_and_ops.sql), and the counts come from
/// the list endpoint so you can size an account without opening it.
class TenantModel {
  final int id;
  final String name;
  final int isActive;
  final String? timezone;
  final String? currency;
  final String? createdAt;

  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;

  final int employeeCount;
  final int branchCount;
  final int adminCount;
  final String? lastAdminLoginAt;
  final String? lastAttendanceDate;

  const TenantModel({
    required this.id,
    required this.name,
    required this.isActive,
    this.timezone,
    this.currency,
    this.createdAt,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.employeeCount = 0,
    this.branchCount = 0,
    this.adminCount = 0,
    this.lastAdminLoginAt,
    this.lastAttendanceDate,
  });

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      isActive: json['is_active'] as int? ?? 0,
      timezone: json['timezone'] as String?,
      currency: json['currency'] as String?,
      createdAt: json['created_at'] as String?,
      contactName: json['contact_name'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      employeeCount: json['employee_count'] as int? ?? 0,
      branchCount: json['branch_count'] as int? ?? 0,
      adminCount: json['admin_count'] as int? ?? 0,
      lastAdminLoginAt: json['last_admin_login_at'] as String?,
      lastAttendanceDate: json['last_attendance_date'] as String?,
    );
  }

  bool get isActiveTenant => isActive == 1;

  /// Something to dial, when we bothered to record it.
  String? get callablePhone {
    final phone = contactPhone?.trim();
    return (phone != null && phone.isNotEmpty) ? phone : null;
  }
}
