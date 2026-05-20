class RequiredDocumentModel {
  final int id;
  final String name;
  final String? description;
  final int? expiryDays;
  final int notificationDaysBefore;
  final String category;
  final int sortOrder;
  final bool isRequired;
  final bool isActive;
  final String scopeType;
  final int? scopeBranchId;
  final List<int> scopeEmployeeIds;

  RequiredDocumentModel({
    required this.id,
    required this.name,
    this.description,
    this.expiryDays,
    this.notificationDaysBefore = 30,
    this.category = 'general',
    this.sortOrder = 0,
    this.isRequired = true,
    this.isActive = true,
    this.scopeType = 'all',
    this.scopeBranchId,
    this.scopeEmployeeIds = const [],
  });

  factory RequiredDocumentModel.fromJson(Map<String, dynamic> json) {
    final raw = json['scope_employee_ids'];
    final empIds = raw is List
        ? raw.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).where((v) => v > 0).toList()
        : <int>[];
    return RequiredDocumentModel(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      expiryDays: json['expiry_days'] as int?,
      notificationDaysBefore: (json['notification_days_before'] as int?) ?? 30,
      category: (json['category'] as String?) ?? 'general',
      sortOrder: (json['sort_order'] as int?) ?? 0,
      isRequired: (json['is_required'] as int?) == 1,
      isActive: (json['is_active'] as int?) == 1,
      scopeType: (json['scope_type'] as String?) ?? 'all',
      scopeBranchId: json['scope_branch_id'] as int?,
      scopeEmployeeIds: empIds,
    );
  }

  Map<String, dynamic> toCreateJson() {
    final map = <String, dynamic>{
      'name': name,
    };
    if (description != null) map['description'] = description;
    if (expiryDays != null) map['expiry_days'] = expiryDays;
    map['notification_days_before'] = notificationDaysBefore;
    map['category'] = category;
    map['sort_order'] = sortOrder;
    map['is_required'] = isRequired ? 1 : 0;
    map['scope_type'] = scopeType;
    if (scopeType == 'branch' && scopeBranchId != null) {
      map['scope_branch_id'] = scopeBranchId;
    }
    if (scopeType == 'employees') {
      map['scope_employee_ids'] = scopeEmployeeIds;
    }
    return map;
  }

  Map<String, dynamic> toUpdateJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'expiry_days': expiryDays,
      'notification_days_before': notificationDaysBefore,
      'category': category,
      'sort_order': sortOrder,
      'is_required': isRequired ? 1 : 0,
      'scope_type': scopeType,
    };
    if (scopeType == 'branch' && scopeBranchId != null) {
      map['scope_branch_id'] = scopeBranchId;
    }
    if (scopeType == 'employees') {
      map['scope_employee_ids'] = scopeEmployeeIds;
    }
    return map;
  }

  RequiredDocumentModel copyWith({
    int? id,
    String? name,
    String? description,
    int? expiryDays,
    int? notificationDaysBefore,
    String? category,
    int? sortOrder,
    bool? isRequired,
    bool? isActive,
    String? scopeType,
    int? scopeBranchId,
    List<int>? scopeEmployeeIds,
  }) {
    return RequiredDocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      expiryDays: expiryDays ?? this.expiryDays,
      notificationDaysBefore: notificationDaysBefore ?? this.notificationDaysBefore,
      category: category ?? this.category,
      sortOrder: sortOrder ?? this.sortOrder,
      isRequired: isRequired ?? this.isRequired,
      isActive: isActive ?? this.isActive,
      scopeType: scopeType ?? this.scopeType,
      scopeBranchId: scopeBranchId ?? this.scopeBranchId,
      scopeEmployeeIds: scopeEmployeeIds ?? this.scopeEmployeeIds,
    );
  }
}
