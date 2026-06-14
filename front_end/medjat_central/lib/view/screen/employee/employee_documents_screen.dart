import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../data/model/document_model.dart';
import '../../../data/model/required_document_model.dart';
import '../../../logic/controller/document/employee_documents_controller.dart';

class EmployeeDocumentsScreen extends StatelessWidget {
  const EmployeeDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int employeeId =
        (Get.arguments as Map<String, dynamic>?)?['employee_id'] as int? ?? 0;
    final String employeeName =
        (Get.arguments as Map<String, dynamic>?)?['employee_name'] as String? ??
            '';
    final ctrl = Get.put(EmployeeDocumentsController(employeeId: employeeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(employeeName.isNotEmpty ? employeeName : 'documents'.tr),
      ),
      body: GetBuilder<EmployeeDocumentsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadAll,
            widget: RefreshIndicator(
              onRefresh: ctrl.loadAll,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.s4),
                children: [
                  Row(
                    children: [
                      Text(
                        'document_status_summary'.tr,
                        style: AppTextStyles.h3(context),
                      ),
                      const Spacer(),
                      if (ctrl.missingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s2,
                            vertical: AppSpacing.s1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.of(context).warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            '${ctrl.missingCount} ${'document_missing'.tr}',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.of(context).warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  ...ctrl.requiredDocuments.map((req) {
                    final doc = ctrl.getDocument(req.id);
                    return _DocumentCard(
                      requiredDoc: req,
                      document: doc,
                      hasDocument: ctrl.hasDocument(req.id),
                      onUpload: () => _pickAndUpload(context, ctrl, req),
                      onTap: doc != null
                          ? () => _showDocActions(context, ctrl, doc)
                          : null,
                    );
                  }),
                  const SizedBox(height: AppSpacing.s7),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context,
      EmployeeDocumentsController ctrl, RequiredDocumentModel req) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      await ctrl.uploadFile(file, req.id);
    }
  }

  void _showDocActions(BuildContext context,
      EmployeeDocumentsController ctrl, DocumentModel doc) {
    final colors = AppColors.of(context);

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(doc.name, style: AppTextStyles.h3(context)),
            if (doc.originalName != null) ...[
              const SizedBox(height: AppSpacing.s1),
              Text(doc.originalName!,
                  style: AppTextStyles.bodySecondary(context)),
            ],
            if (doc.notes != null && doc.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(doc.notes!,
                  style: AppTextStyles.sm(context)),
            ],
            const SizedBox(height: AppSpacing.s4),
            if (doc.filePath != null || doc.fileUrl != null)
              ListTile(
                leading: Icon(Icons.visibility_outlined, color: colors.brand),
                title: Text('view_document'.tr),
                onTap: () {
                  Get.back<void>();
                  ctrl.openDocument(doc.id,
                      mimeType: doc.mimeType, originalName: doc.originalName);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text('edit_notes'.tr),
                onTap: () {
                  Get.back<void>();
                  _showEditNotesDialog(context, ctrl, doc);
              },
            ),
            // Employee self-submissions arrive as 'pending'; admin uploads as
            // 'uploaded'. Both can be approved or rejected.
            if (doc.status == 'uploaded' || doc.status == 'pending')
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: colors.success),
                title: Text('document_verify'.tr),
                onTap: () {
                  Get.back<void>();
                  ctrl.verifyDocument(doc.id);
                },
              ),
            if (doc.status == 'uploaded' || doc.status == 'pending')
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: colors.error),
                title: Text('document_reject'.tr),
                onTap: () {
                  Get.back<void>();
                  _showRejectDialog(context, ctrl, doc);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.error),
              title: Text('delete'.tr),
                onTap: () {
                  Get.back<void>();
                  ctrl.deleteDocument(doc.id);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showEditNotesDialog(BuildContext context,
      EmployeeDocumentsController ctrl, DocumentModel doc) {
    final notesCtl = TextEditingController(text: doc.notes ?? '');
    String? expiresAt = doc.expiryDate != null
        ? '${doc.expiryDate!.year}-${doc.expiryDate!.month.toString().padLeft(2, '0')}-${doc.expiryDate!.day.toString().padLeft(2, '0')}'
        : null;

    Get.defaultDialog<void>(
      title: 'edit_document'.tr,
      titleStyle: AppTextStyles.h3(context),
      content: StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notesCtl,
                decoration: InputDecoration(
                  labelText: 'notes'.tr,
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.s3),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  expiresAt != null
                      ? '${'expires_at'.tr}: $expiresAt'
                      : 'set_expiry_date'.tr,
                  style: AppTextStyles.bodySecondary(context),
                ),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: dialogCtx,
                    initialDate: doc.expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      expiresAt =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
            ],
          );
        },
      ),
      textConfirm: 'save'.tr,
      textCancel: 'cancel'.tr,
      onConfirm: () {
        ctrl.updateDocument(
          doc.id,
          notes: notesCtl.text.trim(),
          expiresAt: expiresAt,
        );
        Get.back<void>();
      },
    );
  }

  void _showRejectDialog(BuildContext context,
      EmployeeDocumentsController ctrl, DocumentModel doc) {
    final reasonCtl = TextEditingController();

    Get.defaultDialog<void>(
      title: 'document_reject'.tr,
      titleStyle: AppTextStyles.h3(context),
      content: TextField(
        controller: reasonCtl,
        decoration: InputDecoration(
          labelText: 'rejection_reason'.tr,
          isDense: true,
        ),
        maxLines: 3,
      ),
      textConfirm: 'reject'.tr,
      textCancel: 'cancel'.tr,
      buttonColor: AppColors.of(context).error,
      confirmTextColor: Colors.white,
      onConfirm: () {
        if (reasonCtl.text.trim().isNotEmpty) {
          ctrl.rejectDocument(doc.id, reasonCtl.text.trim());
        }
        Get.back<void>();
      },
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final RequiredDocumentModel requiredDoc;
  final DocumentModel? document;
  final bool hasDocument;
  final VoidCallback onUpload;
  final VoidCallback? onTap;

  const _DocumentCard({
    required this.requiredDoc,
    this.document,
    required this.hasDocument,
    required this.onUpload,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Row(
            children: [
              _buildStatusIcon(colors),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requiredDoc.name,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasDocument && document != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _statusText(),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: _statusColor(colors),
                        ),
                      ),
                      if (document!.expiryDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${'expires'.tr} ${document!.expiryDate!.year}-${document!.expiryDate!.month.toString().padLeft(2, '0')}-${document!.expiryDate!.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        'document_missing'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.warning,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasDocument)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2,
                    vertical: AppSpacing.s1,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(colors).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    document?.statusLabel ?? '',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _statusColor(colors),
                    ),
                  ),
                )
              else
                OutlinedButton(
                  onPressed: onUpload,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('upload'.tr,
                      style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(AppColorScheme colors) {
    if (!hasDocument) {
      return Icon(Icons.error_outline, size: 22, color: colors.warning);
    }
    switch (document?.status ?? '') {
      case 'uploaded':
        return document?.verifiedAt != null
            ? Icon(Icons.check_circle_outline, size: 22, color: colors.success)
            : Icon(Icons.hourglass_top, size: 22, color: colors.warning);
      case 'pending':
        return Icon(Icons.hourglass_top, size: 22, color: colors.warning);
      case 'expired':
        return Icon(Icons.warning_amber_rounded, size: 22, color: colors.error);
      case 'rejected':
        return Icon(Icons.cancel_outlined, size: 22, color: colors.error);
      default:
        return Icon(Icons.description_outlined, size: 22, color: colors.textTertiary);
    }
  }

  Color _statusColor(AppColorScheme colors) {
    switch (document?.status ?? '') {
      case 'uploaded':
        return document?.verifiedAt != null ? colors.success : colors.warning;
      case 'pending':
        return colors.warning;
      case 'expired':
        return colors.error;
      case 'rejected':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }

  String _statusText() {
    switch (document?.status ?? '') {
      case 'uploaded':
        return document?.verifiedAt != null
            ? 'document_verified'.tr
            : 'status_under_review'.tr;
      case 'pending':
        return 'status_under_review'.tr;
      case 'expired':
        return 'status_expired'.tr;
      case 'rejected':
        return document?.rejectedReason != null
            ? '${'status_rejected'.tr}: ${document!.rejectedReason}'
            : 'status_rejected'.tr;
      default:
        return '';
    }
  }
}
