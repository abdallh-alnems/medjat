import 'dart:io';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/required_documents_data/required_documents_data.dart';
import '../../../data/model/document_model.dart';
import '../../../data/model/required_document_model.dart';

class EmployeeDocumentsController extends GetxController {
  final DocumentData _documentData = Get.find<DocumentData>();
  final RequiredDocumentsData _requiredData = Get.find<RequiredDocumentsData>();

  final int employeeId;

  EmployeeDocumentsController({required this.employeeId});

  StatusRequest status = StatusRequest.none;
  StatusRequest requiredStatus = StatusRequest.none;

  List<DocumentModel> documents = [];
  List<RequiredDocumentModel> requiredDocuments = [];
  List<DocumentModel> missingDocuments = [];

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([
      loadDocuments(),
      loadRequiredDocuments(),
    ]);
  }

  Future<void> loadDocuments() async {
    status = StatusRequest.loading;
    update();

    final response = await _documentData.getDocuments(employeeId);

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['documents'] is List) {
        documents = (body['documents'] as List)
            .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        documents = body
            .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  Future<void> loadRequiredDocuments() async {
    requiredStatus = StatusRequest.loading;
    update();

    final response = await _requiredData.getRequired();

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['required_documents'] is List) {
        requiredDocuments = (body['required_documents'] as List)
            .map((e) => RequiredDocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        requiredDocuments = body
            .map((e) => RequiredDocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      requiredStatus = StatusRequest.success;
    } else {
      requiredStatus = StatusRequest.failure;
    }
    update();
  }

  bool hasDocument(int requiredDocId) {
    return documents.any((d) =>
        d.requiredDocumentId == requiredDocId &&
        d.status != 'rejected');
  }

  DocumentModel? getDocument(int requiredDocId) {
    try {
      return documents.firstWhere((d) =>
          d.requiredDocumentId == requiredDocId &&
          d.status != 'rejected');
    } catch (_) {
      return null;
    }
  }

  int get missingCount {
    int count = 0;
    for (final req in requiredDocuments) {
      if (req.isRequired && req.isActive && !hasDocument(req.id)) {
        count++;
      }
    }
    return count;
  }

  Future<void> uploadFile(File file, int requiredDocumentId) async {
    final response = await _documentData.uploadFile(
      employeeId,
      file,
      {'document_type_id': requiredDocumentId.toString()},
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_uploaded'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> deleteDocument(int docId) async {
    final response = await _documentData.deleteDocument(employeeId, docId);
    if (response['status'] == StatusRequest.success) {
      documents.removeWhere((d) => d.id == docId);
      Get.snackbar('done'.tr, 'document_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> updateDocument(int docId, {String? notes, String? expiresAt}) async {
    final data = <String, dynamic>{};
    if (notes != null) data['notes'] = notes;
    if (expiresAt != null) data['expires_at'] = expiresAt;

    final response = await _documentData.updateDocument(docId, data);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> verifyDocument(int docId) async {
    final response = await _documentData.verifyDocument(docId);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_verified'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> rejectDocument(int docId, String reason) async {
    final response = await _documentData.rejectDocument(docId, reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_rejected'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
