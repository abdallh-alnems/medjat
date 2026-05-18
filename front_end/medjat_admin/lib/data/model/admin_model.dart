class AdminModel {
  final int id;
  final String? username;
  final String? displayName;
  final String? email;
  final String role;

  AdminModel({
    required this.id,
    this.username,
    this.displayName,
    this.email,
    required this.role,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String?,
      displayName: json['display_name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? json['role_key'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'email': email,
        'role': role,
      };

  String get displayNameOrUsername => displayName ?? username ?? 'مدير';
}
