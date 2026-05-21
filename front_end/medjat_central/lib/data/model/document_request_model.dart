import 'package:get/get.dart';

class DocumentRequestModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final int? templateId;
  final String? templateNameAr;
  final String? templateNameEn;
  final String? docType;
  final String status;
  final Map<String, dynamic> extraFields;
  final String? rejectionReason;
  final bool hasPdf;
  final bool requestedByEmployee;
  final DateTime? createdAt;

  DocumentRequestModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.templateId,
    this.templateNameAr,
    this.templateNameEn,
    this.docType,
    this.status = 'pending',
    this.extraFields = const {},
    this.rejectionReason,
    this.hasPdf = false,
    this.requestedByEmployee = false,
    this.createdAt,
  });

  factory DocumentRequestModel.fromJson(Map<String, dynamic> json) {
    return DocumentRequestModel(
      id: _toInt(json['id']),
      employeeId: _toInt(json['employee_id']),
      employeeName: json['employee_name'] as String?,
      templateId: json['template_id'] != null ? _toInt(json['template_id']) : null,
      templateNameAr: json['template_name_ar'] as String?,
      templateNameEn: json['template_name_en'] as String?,
      docType: json['doc_type'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      extraFields: json['extra_fields'] is Map
          ? Map<String, dynamic>.from(json['extra_fields'] as Map)
          : const {},
      rejectionReason: json['rejection_reason'] as String?,
      hasPdf: (json['pdf_path'] != null &&
          (json['pdf_path'] as String).trim().isNotEmpty),
      requestedByEmployee: _toBool(json['requested_by_employee']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get documentName {
    final locale = Get.locale?.languageCode ?? 'ar';
    if (locale == 'en' && (templateNameEn?.trim().isNotEmpty ?? false)) {
      return templateNameEn!;
    }
    return templateNameAr ?? docType ?? 'document'.tr;
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

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) return v == '1' || v.toLowerCase() == 'true';
    return false;
  }
}
