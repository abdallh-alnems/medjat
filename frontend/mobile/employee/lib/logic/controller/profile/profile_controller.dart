import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/api_messages.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/profile_data/profile_data.dart';
import '../../../view/widget/pdf_preview_screen.dart';

class ProfileController extends GetxController {
  final ProfileData _profileData = Get.find<ProfileData>();

  StatusRequest status = StatusRequest.none;
  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> warnings = [];
  Map<String, dynamic>? leaveBalance;
  List<Map<String, dynamic>> categories = [];

  // Id of the document currently being uploaded (for per-card spinners).
  int? uploadingDocId;

  // employee_document_id currently being downloaded for viewing.
  int? openingDocId;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    status = StatusRequest.loading;
    update();

    final response = await _profileData.getProfile();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        profileData = data['employee'] as Map<String, dynamic>?;
        documents = (data['documents'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        warnings = (data['warnings'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        leaveBalance = data['leave_balance'] as Map<String, dynamic>?;
        categories = (data['categories'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
      }
      status = StatusRequest.success;
    } else if (responseStatus == StatusRequest.offline) {
      status = StatusRequest.offline;
    } else {
      status = StatusRequest.failure;
    }

    update();
  }

  /// Upload a file for a required document; lands as 'pending' for admin review.
  /// Returns true on success. Refreshes the profile so the new status shows.
  Future<bool> submitDocument(int documentTypeId, File file) async {
    uploadingDocId = documentTypeId;
    update();

    final response = await _profileData.submitDocument(documentTypeId, file);
    final ok = response['status'] == StatusRequest.success;

    uploadingDocId = null;
    update();

    if (ok) {
      Get.snackbar('done'.tr, 'document_submitted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadProfile();
    } else if (response['status'] == StatusRequest.offline) {
      Get.snackbar('error'.tr, 'no_internet'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr,
          ApiMessages.of(response, fallbackKey: 'upload_failed'),
          snackPosition: SnackPosition.BOTTOM);
    }
    return ok;
  }

  /// Downloads one of the employee's own document files and shows it: images
  /// preview in-app from memory; PDFs open in the device viewer.
  Future<void> openDocument(int docId,
      {String? mimeType, String? originalName}) async {
    openingDocId = docId;
    update();

    final response = await _profileData.downloadDocument(docId);
    final bytes = response['bytes'];

    openingDocId = null;
    update();

    if (response['status'] != StatusRequest.success || bytes is! List<int>) {
      Get.snackbar('error'.tr, 'document_open_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final data = Uint8List.fromList(bytes);
    final lowerName = (originalName ?? '').toLowerCase();
    final isPdf = (mimeType?.contains('pdf') ?? false) ||
        lowerName.endsWith('.pdf') ||
        (data.length >= 4 &&
            data[0] == 0x25 &&
            data[1] == 0x50 &&
            data[2] == 0x44 &&
            data[3] == 0x46);

    if (!isPdf) {
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
