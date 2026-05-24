import 'package:get/get.dart';

class PayrollModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final int month;
  final int year;
  final double baseSalary;
  final double totalDeductions;
  final double totalOvertime;
  final double netSalary;
  final String status;
  final DateTime? generatedAt;

  PayrollModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.month,
    required this.year,
    this.baseSalary = 0,
    this.totalDeductions = 0,
    this.totalOvertime = 0,
    this.netSalary = 0,
    this.status = 'draft',
    this.generatedAt,
  });

  /// DECIMAL columns arrive from the API as strings (e.g. "10000.00"),
  /// so accept both numbers and numeric strings.
  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory PayrollModel.fromJson(Map<String, dynamic> json) {
    return PayrollModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: json['employee_name'] as String?,
      month: (json['month'] as int?) ?? 1,
      year: (json['year'] as int?) ?? 2026,
      baseSalary: _parseDouble(json['base_salary']),
      totalDeductions: _parseDouble(json['total_deductions']),
      totalOvertime: _parseDouble(json['total_overtime']),
      netSalary: _parseDouble(json['net_salary']),
      status: (json['status'] as String?) ?? 'draft',
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'] as String)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'draft':
        return 'status_draft'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'paid':
        return 'status_paid'.tr;
      default:
        return status;
    }
  }

  String get monthLabel {
    return '${'month_$month'.tr} $year';
  }
}
