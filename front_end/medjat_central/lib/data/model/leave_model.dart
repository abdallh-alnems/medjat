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
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectedByName;
  final int? branchId;
  final String? branchName;
  final List<int> categoryIds;
  final DateTime? createdAt;

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
    this.approvedByName,
    this.approvedAt,
    this.rejectedByName,
    this.branchId,
    this.branchName,
    this.categoryIds = const [],
    this.createdAt,
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
      approvedByName: json['approved_by_name'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'] as String)
          : null,
      rejectedByName: json['rejected_by_name'] as String?,
      branchId: json['branch_id'] as int?,
      branchName: json['branch_name'] as String?,
      categoryIds: _parseCategoryIds(json['category_ids']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static List<int> _parseCategoryIds(dynamic raw) {
    if (raw == null) return const [];
    return raw
        .toString()
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
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
