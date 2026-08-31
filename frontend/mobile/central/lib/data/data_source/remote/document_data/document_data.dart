import 'dart:io';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DocumentData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getDocuments(int employeeId) async {
    return await _crud.getData(AppLinks.employeeDocuments(employeeId));
  }

  /// Downloads the raw bytes of an uploaded document file (image or PDF).
  Future<Map<String, dynamic>> downloadFile(int docId) async {
    return await _crud.getBytes(AppLinks.documentFileView(docId));
  }

  Future<Map<String, dynamic>> uploadFile(
      int employeeId, File file, Map<String, String> fields) async {
    return await _crud.postFile(
      AppLinks.employeeDocumentUpload,
      file,
      fields: {
        'employee_id': employeeId.toString(),
        ...fields,
      },
    );
  }

  Future<Map<String, dynamic>> deleteDocument(
      int employeeId, int docId) async {
    // Deletion is a POST to a dedicated endpoint: an HTTP DELETE to the
    // listing URL was silently ignored by the backend (returned the list as
    // success), so nothing was actually removed.
    return await _crud
        .deleteData(AppLinks.employeeDeleteDocument(docId));
  }

  Future<Map<String, dynamic>> updateDocument(
      int docId, Map<String, dynamic> data) async {
    return await _crud.patchData(AppLinks.employeeUpdateDocument(docId), data);
  }

  Future<Map<String, dynamic>> verifyDocument(int docId) async {
    return await _crud.postData(AppLinks.employeeVerifyDocument, {
      'document_id': docId,
    });
  }

  Future<Map<String, dynamic>> rejectDocument(int docId, String reason) async {
    return await _crud.postData(AppLinks.employeeRejectDocument, {
      'document_id': docId,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> getMissingDocuments(int employeeId) async {
    return await _crud.getData(AppLinks.employeeMissingDocuments(employeeId));
  }

  /// Requests an existing company document type from one specific employee.
  /// The backend attaches the employee to that type's required-document scope.
  Future<Map<String, dynamic>> requestDocument(
      int employeeId, int requiredDocumentId) async {
    return await _crud.postData(AppLinks.employeeRequestDocument, {
      'employee_id': employeeId,
      'required_document_id': requiredDocumentId,
    });
  }

  /// Requests a custom, ad-hoc document from one employee with hand-entered
  /// details — not tied to the company document catalog.
  Future<Map<String, dynamic>> requestCustomDocument(
    int employeeId, {
    required String name,
    String? description,
  }) async {
    return await _crud.postData(AppLinks.employeeRequestDocument, {
      'employee_id': employeeId,
      'name': name,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
  }
}
