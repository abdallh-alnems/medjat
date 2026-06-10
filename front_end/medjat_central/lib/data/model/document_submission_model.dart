import 'document_model.dart';

/// One in-scope employee for a required-document type, paired with the document
/// they submitted (if any). [document] is null when the employee has not yet
/// uploaded the document, so the UI can show them under "not submitted".
class DocumentSubmissionModel {
  final int employeeId;
  final String employeeName;
  final String? branchName;
  final DocumentModel? document;

  DocumentSubmissionModel({
    required this.employeeId,
    required this.employeeName,
    this.branchName,
    this.document,
  });

  bool get hasDocument => document != null;

  factory DocumentSubmissionModel.fromJson(Map<String, dynamic> json) {
    final docJson = json['document'];
    return DocumentSubmissionModel(
      employeeId: (json['employee_id'] as int?) ?? 0,
      employeeName: (json['employee_name'] as String?) ?? '',
      branchName: json['branch_name'] as String?,
      document: docJson is Map<String, dynamic>
          ? DocumentModel.fromJson(docJson)
          : null,
    );
  }
}
