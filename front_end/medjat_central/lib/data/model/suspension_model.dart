import 'package:get/get.dart';

/// A single work-suspension record ("موقوف عن العمل") for an employee.
class SuspensionModel {
  final int id;
  final String reason;

  /// How salary is treated during the suspension: `unpaid`, `partial`, `full`.
  final String payMode;

  /// Percentage of salary paid when [payMode] is `partial` (0–100).
  final double? payPercentage;
  final DateTime? startDate;

  /// `null` = open-ended suspension (until manually ended).
  final DateTime? endDate;

  /// `active` while in effect, `ended` once lifted/elapsed.
  final String status;
  final DateTime? endedAt;
  final String? endNote;
  final String? createdByName;
  final String? endedByName;
  final DateTime? createdAt;

  SuspensionModel({
    required this.id,
    required this.reason,
    this.payMode = 'unpaid',
    this.payPercentage,
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.endedAt,
    this.endNote,
    this.createdByName,
    this.endedByName,
    this.createdAt,
  });

  static DateTime? _parseDate(dynamic value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  static double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String && value.isNotEmpty) return double.tryParse(value);
    return null;
  }

  factory SuspensionModel.fromJson(Map<String, dynamic> json) {
    return SuspensionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      reason: (json['reason'] as String?) ?? '',
      payMode: (json['pay_mode'] as String?) ?? 'unpaid',
      payPercentage: _parseDouble(json['pay_percentage']),
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      status: (json['status'] as String?) ?? 'active',
      endedAt: _parseDate(json['ended_at']),
      endNote: json['end_note'] as String?,
      createdByName: json['created_by_name'] as String?,
      endedByName: json['ended_by_name'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  bool get isActive => status == 'active';
  bool get isOpenEnded => endDate == null;

  String get payModeLabel {
    switch (payMode) {
      case 'unpaid':
        return 'suspension_pay_unpaid'.tr;
      case 'partial':
        return 'suspension_pay_partial'.tr;
      case 'full':
        return 'suspension_pay_full'.tr;
      default:
        return payMode;
    }
  }
}
