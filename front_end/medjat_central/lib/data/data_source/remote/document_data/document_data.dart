import 'dart:io';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DocumentData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getDocuments(int employeeId) async {
    return await _crud.getData(AppLinks.employeeDocuments(employeeId));
  }

  Future<Map<String, dynamic>> uploadDocument(
      int employeeId, Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.employeeDocuments(employeeId), data);
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
    return await _crud
        .deleteData(AppLinks.employeeDocument(employeeId, docId));
  }

  Future<Map<String, dynamic>> updateDocument(
      int docId, Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.employeeUpdateDocument, {
      'document_id': docId,
      ...data,
    });
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
}
