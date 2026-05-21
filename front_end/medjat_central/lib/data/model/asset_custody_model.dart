import 'package:get/get.dart';

class AssetCustodyModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final String type;
  final String name;
  final String? description;
  final double? value;
  final String currency;
  final String? serialNo;
  final int quantity;
  final String? assignPhotoUrl;
  final String? returnPhotoUrl;
  final String status;
  final String? notes;
  final String? returnNote;
  final String? rejectionReason;
  final DateTime assignedAt;
  final DateTime? returnedAt;

  AssetCustodyModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.type = 'equipment',
    this.name = '',
    this.description,
    this.value,
    this.currency = 'SAR',
    this.serialNo,
    this.quantity = 1,
    this.assignPhotoUrl,
    this.returnPhotoUrl,
    this.status = 'assigned',
    this.notes,
    this.returnNote,
    this.rejectionReason,
    required this.assignedAt,
    this.returnedAt,
  });

  factory AssetCustodyModel.fromJson(Map<String, dynamic> json) {
    return AssetCustodyModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: json['employee_name'] as String?,
      type: (json['type'] as String?) ?? 'equipment',
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      value: json['value'] != null ? double.tryParse('${json['value']}') : null,
      currency: (json['currency'] as String?) ?? 'SAR',
      serialNo: json['serial_no'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      assignPhotoUrl: json['assign_photo_url'] as String?,
      returnPhotoUrl: json['return_photo_url'] as String?,
      status: (json['status'] as String?) ?? 'assigned',
      notes: json['notes'] as String?,
      returnNote: json['return_note'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      assignedAt: json['assigned_at'] != null
          ? (DateTime.tryParse(json['assigned_at'] as String) ?? DateTime.now())
          : DateTime.now(),
      returnedAt: json['returned_at'] != null
          ? DateTime.tryParse(json['returned_at'] as String)
          : null,
    );
  }

  String get typeLabel => 'asset_type_$type'.tr;

  String get statusLabel {
    switch (status) {
      case 'assigned':
        return 'asset_status_assigned'.tr;
      case 'return_requested':
        return 'asset_status_return_requested'.tr;
      case 'returned':
        return 'asset_status_returned'.tr;
      default:
        return status;
    }
  }
}
