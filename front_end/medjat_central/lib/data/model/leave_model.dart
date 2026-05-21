import 'package:get/get.dart';

class LeaveModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final String type;
  final DateTime startDate;
  final DateTime? endDate;
  final String? reason;
  final String? rejectionReason;
  final String status;

  LeaveModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.type = 'annual',
    required this.startDate,
    this.endDate,
    this.reason,
    this.rejectionReason,
    this.status = 'pending',
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: json['employee_name'] as String?,
      type: (json['type'] as String?) ?? 'annual',
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : DateTime.now(),
      endDate:
          json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
      reason: json['reason'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      status: (json['status'] as String?) ?? 'pending',
    );
  }

  String get typeLabel {
    switch (type) {
      case 'annual':
        return 'leave_annual'.tr;
      case 'sick':
        return 'leave_sick'.tr;
      case 'personal':
        return 'leave_personal'.tr;
      case 'unpaid':
        return 'leave_unpaid'.tr;
      case 'weekly_off':
        return 'leave_weekly_off'.tr;
      case 'converted_from_absence':
        return 'leave_absence_conversion'.tr;
      default:
        return type;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'status_pending'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'rejected':
        return 'status_rejected'.tr;
      default:
        return status;
    }
  }
}
