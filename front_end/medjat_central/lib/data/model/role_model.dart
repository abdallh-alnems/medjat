class RoleModel {
  final int id;
  final String name;
  final String key;
  final String scope;
  final List<String> permissions;
  final int? branchId;
  final String? branchName;

  RoleModel({
    required this.id,
    required this.name,
    required this.key,
    this.scope = 'all',
    this.permissions = const [],
    this.branchId,
    this.branchName,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      scope: (json['scope'] as String?) ?? 'all',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      branchId: json['branch_id'] as int?,
      branchName: json['branch_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'scope': scope,
        'permissions': permissions,
        if (branchId != null) 'branch_id': branchId,
      };

  String get scopeLabel {
    switch (scope) {
      case 'all':
        return 'كل الفروع';
      case 'branch':
        return branchName ?? 'فرع محدد';
      default:
        return scope;
    }
  }
}
