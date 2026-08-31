/// A company administrator — someone we might have to call.
///
/// This is the contact book, not the super-admin team: these rows come from
/// `admins`, the people who run our client companies. `tenantName` is now
/// actually parsed (it was declared and silently left null), and [lastLoginAt]
/// is the field that decides whether an account is still alive.
class UserModel {
  final int id;
  final int? tenantId;
  final int? branchId;
  final String name;
  final String? phone;
  final String? email;
  final String? role;
  final String? authProvider;
  final int? isActive;
  final String? createdAt;
  final String? lastLoginAt;
  final String? tenantName;
  final int? tenantIsActive;

  UserModel({
    required this.id,
    this.tenantId,
    this.branchId,
    required this.name,
    this.phone,
    this.email,
    this.role,
    this.authProvider,
    this.isActive,
    this.createdAt,
    this.lastLoginAt,
    this.tenantName,
    this.tenantIsActive,
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
      authProvider: json['auth_provider'] as String?,
      isActive: json['is_active'] as int?,
      createdAt: json['created_at'] as String?,
      lastLoginAt: json['last_login_at'] as String?,
      tenantName: json['tenant_name'] as String?,
      tenantIsActive: json['tenant_is_active'] as int?,
    );
  }

  bool get isActiveUser => isActive == 1;

  /// Only email/password accounts have a password with us to reset; Google and
  /// Apple sign-ins do not.
  bool get canResetPassword =>
      authProvider == 'email' && (email ?? '').trim().isNotEmpty;

  String? get callablePhone {
    final value = phone?.trim();
    return (value != null && value.isNotEmpty) ? value : null;
  }

  static const Map<String, String> _roleLabelsAr = {
    'general_manager': 'المدير العام',
    'hr': 'الموارد البشرية',
    'branch_manager': 'مدير فرع',
    'attendance': 'الحضور والانصراف',
    'viewer': 'مشاهدة فقط',
    'employee': 'موظف',
    'pending': 'قيد الانتظار',
  };

  static String labelForRole(String role) => _roleLabelsAr[role] ?? role;

  /// الاسم العربي للصلاحية، أو القيمة الأصلية إن لم تكن معروفة.
  String? get roleLabelAr {
    if (role == null) return null;
    return _roleLabelsAr[role!] ?? role;
  }
}
