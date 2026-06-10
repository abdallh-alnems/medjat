import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
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

  // Id of the document currently being downloaded (for a spinner / disabling).
  int? openingDocId;

  /// Downloads the document file via an authenticated request and opens it in
  /// the device's default viewer (image/PDF), so the admin can review it
  /// before approving.
  Future<void> openDocument(int docId,
      {String? mimeType, String? originalName}) async {
    openingDocId = docId;
    update();

    final response = await _documentData.downloadFile(docId);
    final bytes = response['bytes'];

    openingDocId = null;
    update();

    if (response['status'] != StatusRequest.success || bytes is! List<int>) {
      Get.snackbar('error'.tr, 'document_open_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final data = Uint8List.fromList(bytes);

    // Employee self-submissions often have no stored mime_type / original_name,
    // so decide PDF-vs-image from the metadata first, then the file signature.
    final lowerName = (originalName ?? '').toLowerCase();
    final isPdf = (mimeType?.contains('pdf') ?? false) ||
        lowerName.endsWith('.pdf') ||
        (data.length >= 4 &&
            data[0] == 0x25 &&
            data[1] == 0x50 &&
            data[2] == 0x44 &&
            data[3] == 0x46);

    if (!isPdf) {
      // Images: preview in-app from memory (no temp file, no external viewer).
      unawaited(Get.dialog<void>(
        _ImagePreviewDialog(bytes: data),
        barrierColor: Colors.black87,
      ));
      return;
    }

    // PDFs: write to a temp file and open with the device's PDF viewer.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/doc_$docId.pdf');
    await file.writeAsBytes(data, flush: true);

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      Get.snackbar('error'.tr, 'document_open_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

/// Fullscreen, zoomable in-app preview for an image document — renders the
/// downloaded bytes directly so no external app is needed.
class _ImagePreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  const _ImagePreviewDialog({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Get.back<void>(),
            ),
          ),
        ],
      ),
    );
  }
}
