import 'package:get/get.dart';

class BreakRequestModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final String type;
  final bool deductFromSalary;
  final String? reason;
  final String status;
  final String? decisionNote;
  final String? decidedByName;
  final DateTime? suggestedDate;
  final String? suggestedStartTime;
  final String? suggestedEndTime;

  BreakRequestModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 0,
    this.type = 'break',
    this.deductFromSalary = false,
    this.reason,
    this.status = 'pending',
    this.decisionNote,
    this.decidedByName,
    this.suggestedDate,
    this.suggestedStartTime,
    this.suggestedEndTime,
  });

  factory BreakRequestModel.fromJson(Map<String, dynamic> json) {
    return BreakRequestModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: json['employee_name'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      startTime: (json['start_time'] as String?) ?? '00:00',
      endTime: (json['end_time'] as String?) ?? '00:00',
      durationMinutes: (json['duration_minutes'] as int?) ?? 0,
      type: (json['type'] as String?) ?? 'break',
      deductFromSalary: _parseBool(json['deduct_from_salary']),
      reason: json['reason'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      decisionNote: json['decision_note'] as String?,
      decidedByName: json['decided_by_name'] as String?,
      suggestedDate: json['suggested_date'] != null
          ? DateTime.tryParse(json['suggested_date'] as String)
          : null,
      suggestedStartTime: json['suggested_start_time'] as String?,
      suggestedEndTime: json['suggested_end_time'] as String?,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'break':
        return 'break_type_break'.tr;
      case 'permission':
        return 'break_type_permission'.tr;
      case 'prayer':
        return 'break_type_prayer'.tr;
      case 'errand':
        return 'break_type_errand'.tr;
      case 'medical':
        return 'break_type_medical'.tr;
      case 'early_leave':
        return 'break_type_early_leave'.tr;
      case 'other':
        return 'break_type_other'.tr;
      default:
        return type;
    }
  }

  static bool _parseBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'status_pending'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'rejected':
        return 'status_rejected'.tr;
      case 'postponed':
        return 'status_postponed'.tr;
      case 'cancelled':
        return 'status_cancelled'.tr;
      default:
        return status;
    }
  }
}
