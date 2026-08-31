class EmployeeCategoryModel {
  final int id;
  final String name;
  final String? description;
  final String? color;
  final bool isActive;
  final int employeeCount;

  EmployeeCategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.isActive = true,
    this.employeeCount = 0,
  });

  factory EmployeeCategoryModel.fromJson(Map<String, dynamic> json) {
    return EmployeeCategoryModel(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      color: json['color'] as String?,
      isActive: (json['is_active'] as int?) == 1,
      employeeCount: (json['employee_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toCreateJson() {
    final map = <String, dynamic>{'name': name};
    if (description != null) map['description'] = description;
    if (color != null) map['color'] = color;
    return map;
  }

  Map<String, dynamic> toUpdateJson() {
    final map = <String, dynamic>{'id': id};
    map['name'] = name;
    map['description'] = description;
    map['color'] = color;
    map['is_active'] = isActive ? 1 : 0;
    return map;
  }

  EmployeeCategoryModel copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    bool? isActive,
    int? employeeCount,
  }) {
    return EmployeeCategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      employeeCount: employeeCount ?? this.employeeCount,
    );
  }
}
