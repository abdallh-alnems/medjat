import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../logic/controller/profile/profile_controller.dart';
import 'widgets/document_card.dart';

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
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = controller.documents[index];
        final status = doc['status']?.toString() ?? '';
        final isVerified = doc['verified_at'] != null;
        final docTypeId = doc['required_document_id'] is int
            ? doc['required_document_id'] as int
            : int.tryParse('${doc['required_document_id']}');
        final employeeDocId = doc['employee_document_id'] is int
            ? doc['employee_document_id'] as int
            : int.tryParse('${doc['employee_document_id']}');

        return DocumentCard(
          status: status,
          isVerified: isVerified,
          documentTypeName: doc['document_type_name']?.toString() ??
              doc['name']?.toString() ??
              'document'.tr,
          expiryDate: doc['expiry_date']?.toString(),
          rejectedReason: doc['rejected_reason']?.toString(),
          canUpload: status != 'uploaded',
          docTypeId: docTypeId,
          isUploading: docTypeId != null && controller.uploadingDocId == docTypeId,
          employeeDocId: employeeDocId,
          hasFile: employeeDocId != null && doc['file_path'] != null,
          isOpening: employeeDocId != null && controller.openingDocId == employeeDocId,
          onOpen: employeeDocId != null
              ? () => controller.openDocument(
                    employeeDocId,
                    originalName: doc['original_name']?.toString(),
                  )
              : null,
          onUpload: docTypeId != null
              ? () => _showUploadOptions(context, controller, docTypeId)
              : null,
        );
      },
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
    Get.back<void>();
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
