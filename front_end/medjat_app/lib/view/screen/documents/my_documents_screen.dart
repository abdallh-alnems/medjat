import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/profile/profile_controller.dart';

class MyDocumentsScreen extends StatelessWidget {
  const MyDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => ProfileController());
    return Scaffold(
      appBar: AppBar(title: Text('my_documents'.tr)),
      body: GetBuilder<ProfileController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status,
            widget: _buildContent(context, controller),
            onRetry: () => controller.loadProfile(),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileController controller) {
    if (controller.documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open,
                size: 48, color: AppColors.textTertiary(context)),
            const SizedBox(height: 16),
            Text('no_documents'.tr,
                style: AppTextStyles.bodySecondary(context)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.documents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = controller.documents[index];
        return _documentCard(context, controller, doc);
      },
    );
  }

  Widget _documentCard(
      BuildContext context, ProfileController controller, Map<String, dynamic> doc) {
    final status = doc['status']?.toString() ?? '';
    final isVerified = doc['verified_at'] != null;
    final docTypeId = doc['required_document_id'] is int
        ? doc['required_document_id'] as int
        : int.tryParse('${doc['required_document_id']}');
    final isUploading =
        docTypeId != null && controller.uploadingDocId == docTypeId;

    // The employee can (re)upload unless the file is currently 'uploaded'
    // (locked while awaiting review or after approval). Covers required,
    // rejected, expired, and any not-yet-submitted state.
    final canUpload = status != 'uploaded';

    // The uploaded file the employee can view (the employee_document row).
    final employeeDocId = doc['employee_document_id'] is int
        ? doc['employee_document_id'] as int
        : int.tryParse('${doc['employee_document_id']}');
    final hasFile = employeeDocId != null && doc['file_path'] != null;
    final isOpening =
        employeeDocId != null && controller.openingDocId == employeeDocId;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'uploaded' && isVerified) {
      // Approved by admin.
      statusColor = Colors.green;
      statusText = 'doc_status_approved'.tr;
      statusIcon = Icons.verified;
    } else if (status == 'uploaded') {
      // Submitted, awaiting admin review.
      statusColor = Colors.blue;
      statusText = 'doc_status_under_review'.tr;
      statusIcon = Icons.hourglass_top;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'doc_status_rejected'.tr;
      statusIcon = Icons.cancel;
    } else if (status == 'expired') {
      statusColor = Colors.red;
      statusText = 'expired'.tr;
      statusIcon = Icons.error;
    } else {
      // 'required' (or any not-yet-uploaded state).
      statusColor = Colors.orange;
      statusText = 'doc_status_required'.tr;
      statusIcon = Icons.upload_file;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc['document_type_name']?.toString() ??
                          doc['name']?.toString() ??
                          'document'.tr,
                      style: AppTextStyles.body(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (doc['expiry_date'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          'expires_at'
                              .trParams({'date': '${doc['expiry_date']}'}),
                          style: AppTextStyles.xs(context)),
                    ],
                    if (status == 'rejected' &&
                        doc['rejected_reason'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${'reject_reason'.tr}: ${doc['rejected_reason']}',
                        style: AppTextStyles.xs(context)
                            .copyWith(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // View the uploaded file.
              if (hasFile) ...[
                const SizedBox(width: 2),
                isOpening
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: 'view_document'.tr,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => controller.openDocument(
                          employeeDocId,
                          originalName: doc['original_name']?.toString(),
                        ),
                      ),
              ],
              // Upload / re-upload via an icon (no text label).
              if (canUpload && docTypeId != null) ...[
                const SizedBox(width: 2),
                isUploading
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.upload_file),
                        color: statusColor,
                        tooltip: (status == 'rejected' || status == 'expired')
                            ? 'reupload_document'.tr
                            : 'upload_document'.tr,
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            _showUploadOptions(context, controller, docTypeId),
                      ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadOptions(
      BuildContext context, ProfileController controller, int docTypeId) {
    Get.bottomSheet<void>(
      Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        clipBehavior: Clip.antiAlias,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SafeArea(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('from_camera'.tr),
                onTap: () =>
                    _pickAndUpload(controller, docTypeId, _Source.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('from_gallery'.tr),
                onTap: () =>
                    _pickAndUpload(controller, docTypeId, _Source.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: Text('from_files'.tr),
                onTap: () =>
                    _pickAndUpload(controller, docTypeId, _Source.file),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(
      ProfileController controller, int docTypeId, _Source source) async {
    Get.back<void>(); // close the options sheet
    File? file;

    if (source == _Source.file) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        file = File(result.files.single.path!);
      }
    } else {
      final picked = await ImagePicker().pickImage(
        source: source == _Source.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) file = File(picked.path);
    }

    if (file != null) {
      await controller.submitDocument(docTypeId, file);
    }
  }
}

enum _Source { camera, gallery, file }
