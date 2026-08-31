/// A category that may carry an attendance-method override.
/// `methods == null` means it inherits (branch/company).
class CategoryMethodOverride {
  final int id;
  final String name;
  final String? color;
  final int employeeCount;
  List<String>? methods;

  /// Browser-attendance exception: null inherits the company switch, true
  /// allows, false refuses. Three states, so this is a `bool?` and never a
  /// `bool` defaulted to false — "inherit" and "refused" are different answers.
  bool? webAttendanceAllowed;

  CategoryMethodOverride({
    required this.id,
    required this.name,
    this.color,
    this.employeeCount = 0,
    this.methods,
    this.webAttendanceAllowed,
  });

  bool get hasOverride => methods != null;

  factory CategoryMethodOverride.fromJson(Map<String, dynamic> json) {
    return CategoryMethodOverride(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      color: json['color'] as String?,
      employeeCount: (json['employee_count'] as int?) ?? 0,
      methods: (json['attendance_methods'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      webAttendanceAllowed: json['web_attendance_allowed'] as bool?,
    );
  }
}

/// An employee with an explicit attendance-method override.
class EmployeeMethodOverride {
  final int id;
  final String name;
  final String? branchName;
  List<String> methods;

  EmployeeMethodOverride({
    required this.id,
    required this.name,
    this.branchName,
    required this.methods,
  });

  factory EmployeeMethodOverride.fromJson(Map<String, dynamic> json) {
    return EmployeeMethodOverride(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      branchName: json['branch_name'] as String?,
      methods: (json['attendance_methods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}
