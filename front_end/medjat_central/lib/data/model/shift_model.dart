class ShiftModel {
  final int id;
  final int tenantId;
  final int? branchId;
  final String? branchName;
  final String name;
  final String startTime;
  final String endTime;
  final String? color;
  final bool isActive;
  final int employeeCount;

  ShiftModel({
    required this.id,
    required this.tenantId,
    this.branchId,
    this.branchName,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.color,
    this.isActive = true,
    this.employeeCount = 0,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) => ShiftModel(
        id: (json['id'] as num).toInt(),
        tenantId: (json['tenant_id'] as num).toInt(),
        branchId: (json['branch_id'] as num?)?.toInt(),
        branchName: json['branch_name'] as String?,
        name: json['name'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
        color: json['color'] as String?,
        isActive: (json['is_active'] as num?)?.toInt() == 1,
        employeeCount: (json['employee_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'name': name,
        'start_time': startTime,
        'end_time': endTime,
        'color': color,
        'is_active': isActive ? 1 : 0,
      };
}
