/// The signed-in super admin — us.
///
/// Carries the session facts the account screen shows (last login, live
/// sessions) so a panel operated by one person can still answer "is anyone else
/// signed in as me?".
class AdminModel {
  final int id;
  final String? username;
  final String? displayName;
  final String? email;
  final String role;
  final String? lastLoginAt;
  final String? lastLoginIp;
  final String? createdAt;
  final int activeSessions;

  AdminModel({
    required this.id,
    this.username,
    this.displayName,
    this.email,
    required this.role,
    this.lastLoginAt,
    this.lastLoginIp,
    this.createdAt,
    this.activeSessions = 0,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? json['role_key'] as String? ?? '',
      lastLoginAt: json['last_login_at'] as String?,
      lastLoginIp: json['last_login_ip'] as String?,
      createdAt: json['created_at'] as String?,
      activeSessions: json['active_sessions'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'email': email,
        'role': role,
        'last_login_at': lastLoginAt,
        'last_login_ip': lastLoginIp,
        'created_at': createdAt,
        'active_sessions': activeSessions,
      };

  String get displayNameOrUsername => displayName ?? username ?? 'مدير';

  bool get isSuperAdmin => role == 'superadmin';

  /// Everything below `admin` is read-only; the panel hides write actions
  /// rather than letting the backend answer with a bare 403.
  bool get canWrite => role == 'admin' || role == 'superadmin';

  String get roleLabelAr {
    switch (role) {
      case 'superadmin':
        return 'مشرف عام';
      case 'admin':
        return 'مشرف';
      case 'readonly':
        return 'اطّلاع فقط';
      default:
        return role;
    }
  }
}
