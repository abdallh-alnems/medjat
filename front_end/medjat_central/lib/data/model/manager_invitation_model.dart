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
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) => AdminModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'viewer',
        branchId: (json['branch_id'] as num?)?.toInt(),
        branchName: json['branch_name'] as String?,
        isActive: (json['is_active'] as num?)?.toInt() == 1,
        lastLoginAt: json['last_login_at'] as String?,
      );
}
