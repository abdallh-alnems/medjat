class DocumentModel {
  final int id;
  final int employeeId;
  final String name;
  final String? fileUrl;
  final String status;
  final DateTime? expiryDate;
  final DateTime? uploadedAt;

  DocumentModel({
    required this.id,
    required this.employeeId,
    required this.name,
    this.fileUrl,
    this.status = 'required',
    this.expiryDate,
    this.uploadedAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? '',
      fileUrl: json['file_url'] as String?,
      status: (json['status'] as String?) ?? 'required',
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'] as String)
          : null,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at'] as String)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'uploaded':
        return 'مرفوعة';
      case 'required':
        return 'مطلوبة';
      case 'expired':
        return 'منتهية الصلاحية';
      default:
        return status;
    }
  }
}
