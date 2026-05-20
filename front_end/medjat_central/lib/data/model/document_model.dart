import 'package:get/get.dart';

class DocumentModel {
  final int id;
  final int employeeId;
  final int? requiredDocumentId;
  final String name;
  final String? fileUrl;
  final String? originalName;
  final String? filePath;
  final int? fileSize;
  final String? mimeType;
  final String status;
  final DateTime? expiryDate;
  final DateTime? uploadedAt;
  final String? notes;
  final String? rejectedReason;
  final DateTime? verifiedAt;
  final String? category;

  DocumentModel({
    required this.id,
    required this.employeeId,
    this.requiredDocumentId,
    required this.name,
    this.fileUrl,
    this.originalName,
    this.filePath,
    this.fileSize,
    this.mimeType,
    this.status = 'required',
    this.expiryDate,
    this.uploadedAt,
    this.notes,
    this.rejectedReason,
    this.verifiedAt,
    this.category,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      requiredDocumentId: json['required_document_id'] as int?,
      name: (json['document_name'] as String?) ?? (json['name'] as String?) ?? '',
      fileUrl: json['file_url'] as String?,
      originalName: json['original_name'] as String?,
      filePath: json['file_path'] as String?,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      status: (json['status'] as String?) ?? 'required',
      expiryDate: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : json['expiry_date'] != null
              ? DateTime.tryParse(json['expiry_date'] as String)
              : null,
      uploadedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : json['uploaded_at'] != null
              ? DateTime.tryParse(json['uploaded_at'] as String)
              : null,
      notes: json['notes'] as String?,
      rejectedReason: json['rejected_reason'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
      category: json['category'] as String?,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'uploaded':
        return 'status_uploaded'.tr;
      case 'required':
        return 'status_required'.tr;
      case 'expired':
        return 'status_expired'.tr;
      case 'rejected':
        return 'status_rejected'.tr;
      default:
        return status;
    }
  }
}
