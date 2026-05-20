import 'package:get/get.dart';

class WarningModel {
  final int id;
  final String type;
  final String reason;
  final String? issuedByName;
  final DateTime? createdAt;

  WarningModel({
    required this.id,
    required this.type,
    required this.reason,
    this.issuedByName,
    this.createdAt,
  });

  factory WarningModel.fromJson(Map<String, dynamic> json) {
    return WarningModel(
      id: (json['id'] as int?) ?? 0,
      type: (json['type'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      issuedByName: json['issued_by_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'verbal':
        return 'warning_type_verbal'.tr;
      case 'written':
        return 'warning_type_written'.tr;
      case 'final':
        return 'warning_type_final'.tr;
      case 'device_change':
        return 'warning_type_device_change'.tr;
      case 'system':
        return 'warning_type_system'.tr;
      default:
        return type;
    }
  }
}
