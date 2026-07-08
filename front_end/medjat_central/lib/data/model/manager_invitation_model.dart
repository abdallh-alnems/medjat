class ManagerInvitationModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? branchId;
  final String? branchName;
  final String expiresAt;
  final String? acceptedAt;
  final String? cancelledAt;
  final String createdAt;

  ManagerInvitationModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.branchId,
    this.branchName,
    required this.expiresAt,
    this.acceptedAt,
    this.cancelledAt,
    required this.createdAt,
  });

  factory ManagerInvitationModel.fromJson(Map<String, dynamic> json) =>
      ManagerInvitationModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'viewer',
        branchId: (json['branch_id'] as num?)?.toInt(),
        branchName: json['branch_name'] as String?,
        expiresAt: json['expires_at'] as String? ?? '',
        acceptedAt: json['accepted_at'] as String?,
        cancelledAt: json['cancelled_at'] as String?,
        createdAt: json['created_at'] as String? ?? '',
      );

  String get statusKey {
    if (cancelledAt != null) return 'cancelled';
    if (acceptedAt != null) return 'accepted';
    if (DateTime.tryParse(expiresAt)?.isBefore(DateTime.now()) ?? false) {
      return 'expired';
    }
    return 'pending';
  }
}

class AdminModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final int? branchId;
  final String? branchName;
  final bool isActive;
  final String? lastLoginAt;

  /// Whether the signed-in admin outranks this one and may manage them
  /// (edit / suspend / remove). Computed by the backend (`list_admins.php`).
  /// Defaults to true so older payloads keep the previous behaviour.
  final bool canManage;

  AdminModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.branchId,
    this.branchName,
    this.isActive = true,
    this.lastLoginAt,
    this.canManage = true,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) => AdminModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'viewer',
        branchId: (json['branch_id'] as num?)?.toInt(),
        branchName: json['branch_name'] as String?,
        isActive: _parseBool(json['is_active']),
        lastLoginAt: json['last_login_at'] as String?,
        canManage: json.containsKey('can_manage')
            ? _parseBool(json['can_manage'])
            : true,
      );

  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v.toInt() == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  /// Date-only portion of the last login, or null if never signed in.
  String? get lastLoginShort {
    final v = lastLoginAt;
    if (v == null || v.isEmpty) return null;
    return v.length >= 16 ? v.substring(0, 16) : v;
  }
}
