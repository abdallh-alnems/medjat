import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../view/widget/pdf_preview_screen.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/required_documents_data/required_documents_data.dart';
import '../../../data/model/document_submission_model.dart';

/// Drives the "who submitted this document type" screen: loads every in-scope
/// employee for one required document and lets the admin review (open the file)
/// and approve / reject submissions in place.
class RequiredDocumentSubmissionsController extends GetxController {
  final RequiredDocumentsData _requiredData = Get.find<RequiredDocumentsData>();
  final DocumentData _documentData = Get.find<DocumentData>();

  final int requiredDocumentId;
  final String documentName;

  RequiredDocumentSubmissionsController({
    required this.requiredDocumentId,
    required this.documentName,
  });

  StatusRequest status = StatusRequest.none;
  List<DocumentSubmissionModel> submissions = [];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final response = await _requiredData.getSubmissions(requiredDocumentId);

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
      if (body is Map && body['submissions'] is List) {
        submissions = (body['submissions'] as List)
            .map((e) =>
                DocumentSubmissionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  // ── Derived counts for the summary header ──
  int get submittedCount => submissions.where((s) => s.hasDocument).length;
  int get verifiedCount => submissions
      .where((s) => s.document?.status == 'uploaded' && s.document?.verifiedAt != null)
      .length;
  int get pendingCount => submissions
      .where((s) =>
          s.hasDocument &&
          (s.document?.status == 'pending' ||
              (s.document?.status == 'uploaded' &&
                  s.document?.verifiedAt == null)))
      .length;
  int get rejectedCount =>
      submissions.where((s) => s.document?.status == 'rejected').length;
  int get notSubmittedCount =>
      submissions.where((s) => !s.hasDocument).length;

  Future<void> verifyDocument(int docId) async {
    final response = await _documentData.verifyDocument(docId);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_verified'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await load();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// Removes an already-accepted submission entirely (so the employee shows as
  /// "not submitted" again and can re-upload). This is a removal, not a
  /// rejection, so it carries no rejection reason.
  Future<void> removeDocument(int employeeId, int docId) async {
    final response = await _documentData.deleteDocument(employeeId, docId);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await load();
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
      await load();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // Id of the document currently being downloaded (for a spinner / disabling).
  int? openingDocId;

  /// Downloads the document file via an authenticated request and opens it in
  /// the device's default viewer so the admin can review it before deciding.
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
      // Images: preview in-app from memory (no temp file, no external viewer) —
      // matches the employee-profile documents tab behaviour.
      unawaited(Get.dialog<void>(
        _ImagePreviewDialog(bytes: data),
        barrierColor: Colors.black87,
      ));
      return;
    }

    // PDFs: preview in-app (no external viewer).
    unawaited(
        Get.to<void>(() => PdfPreviewScreen(bytes: data, title: originalName)));
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
