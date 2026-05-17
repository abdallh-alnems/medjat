class LeaveModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final String type;
  final DateTime startDate;
  final DateTime? endDate;
  final String? reason;
  final String status;

  LeaveModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.type = 'single',
    required this.startDate,
    this.endDate,
    this.reason,
    this.status = 'pending',
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      id: json['id'] ?? 0,
      employeeId: json['employee_id'] ?? 0,
      employeeName: json['employee_name'],
      type: json['type'] ?? 'single',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : DateTime.now(),
      endDate:
          json['end_date'] != null ? DateTime.tryParse(json['end_date']) : null,
      reason: json['reason'],
      status: json['status'] ?? 'pending',
    );
  }

  String get typeLabel {
    switch (type) {
      case 'recurring':
        return 'متكررة';
      case 'single':
        return 'مرة واحدة';
      case 'absence_conversion':
        return 'تحويل غياب';
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'مقبولة';
      case 'rejected':
        return 'مرفوضة';
      default:
        return status;
    }
  }
}
