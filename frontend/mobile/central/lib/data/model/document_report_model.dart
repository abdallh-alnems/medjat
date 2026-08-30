class DocumentReportModel {
  final int documentId;
  final int employeeId;
  final String employeeName;
  final int? branchId;
  final String? branchName;
  final int? requiredDocumentId;
  final String documentName;
  final String? category;
  final String? filePath;
  final String? originalName;
  final String status;
  final DateTime? expiresAt;

  DocumentReportModel({
    required this.documentId,
    required this.employeeId,
    required this.employeeName,
    this.branchId,
    this.branchName,
    this.requiredDocumentId,
    required this.documentName,
    this.category,
    this.filePath,
    this.originalName,
    this.status = 'required',
    this.expiresAt,
  });

  factory DocumentReportModel.fromJson(Map<String, dynamic> json) {
    return DocumentReportModel(
      documentId: (json['id'] as int?) ?? (json['document_id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: (json['employee_name'] as String?) ?? '',
      branchId: json['branch_id'] as int?,
      branchName: json['branch_name'] as String?,
      requiredDocumentId: json['required_document_id'] as int?,
      documentName: (json['document_name'] as String?) ?? '',
      category: json['category'] as String?,
      filePath: json['file_path'] as String?,
      originalName: json['original_name'] as String?,
      status: (json['status'] as String?) ?? 'required',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
    );
  }
}
