import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../data/model/document_model.dart';
import '../../../data/model/document_submission_model.dart';
import '../../../logic/controller/document/required_document_submissions_controller.dart';

/// Shows everyone a required-document type applies to, split into who submitted
/// it and who hasn't, and lets the admin review / approve / reject each one.
class RequiredDocumentSubmissionsScreen extends StatelessWidget {
  const RequiredDocumentSubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final int requiredDocumentId = (args?['required_document_id'] as int?) ?? 0;
    final String documentName = (args?['document_name'] as String?) ?? '';

    final ctrl = Get.put(RequiredDocumentSubmissionsController(
      requiredDocumentId: requiredDocumentId,
      documentName: documentName,
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(documentName.isNotEmpty ? documentName : 'documents'.tr),
      ),
      body: GetBuilder<RequiredDocumentSubmissionsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.load,
            widget: RefreshIndicator(
              onRefresh: ctrl.load,
              child: ctrl.submissions.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text('doc_no_scope_employees'.tr,
                              style: AppTextStyles.bodySecondary(context)),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      children: [
                        _summary(context, ctrl),
                        const SizedBox(height: AppSpacing.s4),
                        ...ctrl.submissions.map((s) => _SubmissionTile(
                              submission: s,
                              onTap: s.hasDocument
                                  ? () => _showActions(context, ctrl, s)
                                  : null,
                            )),
                        const SizedBox(height: AppSpacing.s7),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary(
      BuildContext context, RequiredDocumentSubmissionsController ctrl) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('doc_submissions_summary'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s2),
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: [
              _chip(context, 'doc_submitted'.tr,
                  '${ctrl.submittedCount}/${ctrl.submissions.length}', colors.brand),
              if (ctrl.verifiedCount > 0)
                _chip(context, 'document_verified'.tr,
                    '${ctrl.verifiedCount}', colors.success),
              if (ctrl.pendingCount > 0)
                _chip(context, 'status_under_review'.tr,
                    '${ctrl.pendingCount}', colors.warning),
              if (ctrl.rejectedCount > 0)
                _chip(context, 'status_rejected'.tr,
                    '${ctrl.rejectedCount}', colors.error),
              if (ctrl.notSubmittedCount > 0)
                _chip(context, 'doc_not_submitted'.tr,
                    '${ctrl.notSubmittedCount}', colors.textTertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  void _showActions(BuildContext context,
      RequiredDocumentSubmissionsController ctrl, DocumentSubmissionModel s) {
    final colors = AppColors.of(context);
    final doc = s.document!;
    final isVerified = doc.status == 'uploaded' && doc.verifiedAt != null;
    // While awaiting review the admin can accept or reject (reject = decline a
    // not-yet-approved file, needs a reason). Once accepted there is nothing to
    // reject — the destructive action becomes "remove" (delete the submission).
    final isUnderReview = doc.status == 'pending' ||
        (doc.status == 'uploaded' && doc.verifiedAt == null);

    Get.bottomSheet<void>(
      // Material (not a plain DecoratedBox) so the ListTiles below can paint
      // their ink splashes / background onto a Material ancestor.
      Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
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
            Text(s.employeeName, style: AppTextStyles.h3(context)),
            if (doc.rejectedReason != null && doc.rejectedReason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              Text('${'rejection_reason'.tr}: ${doc.rejectedReason}',
                  style: AppTextStyles.sm(context)),
            ],
            const SizedBox(height: AppSpacing.s3),
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
            if (isVerified)
              ListTile(
                leading: Icon(Icons.verified_outlined, color: colors.success),
                title: Text('document_verified'.tr),
                enabled: false,
              ),
            if (isUnderReview)
              ListTile(
                leading: Icon(Icons.check_circle_outline, color: colors.success),
                title: Text('document_verify'.tr),
                onTap: () {
                  Get.back<void>();
                  ctrl.verifyDocument(doc.id);
                },
              ),
            if (isUnderReview)
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: colors.error),
                title: Text('document_reject'.tr),
                onTap: () {
                  Get.back<void>();
                  _showRejectDialog(context, ctrl, doc);
                },
              ),
            if (isVerified)
              ListTile(
                leading: Icon(Icons.delete_outline, color: colors.error),
                title: Text('remove'.tr),
                onTap: () {
                  Get.back<void>();
                  _showRemoveDialog(context, ctrl, s);
                },
              ),
          ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showRejectDialog(BuildContext context,
      RequiredDocumentSubmissionsController ctrl, DocumentModel doc) {
    final reasonCtl = TextEditingController();
    Get.defaultDialog(
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
        final reason = reasonCtl.text.trim();
        // A rejection must carry a reason; without one the backend rejects the
        // request and nothing visibly happens — surface that instead.
        if (reason.isEmpty) {
          Get.snackbar('error'.tr, 'rejection_reason'.tr,
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
        ctrl.rejectDocument(doc.id, reason);
        Get.back();
      },
    );
  }

  void _showRemoveDialog(BuildContext context,
      RequiredDocumentSubmissionsController ctrl, DocumentSubmissionModel s) {
    Get.defaultDialog(
      title: 'remove'.tr,
      titleStyle: AppTextStyles.h3(context),
      middleText: '${'confirm_delete'.tr} ${s.employeeName}',
      textConfirm: 'remove'.tr,
      textCancel: 'cancel'.tr,
      buttonColor: AppColors.of(context).error,
      confirmTextColor: Colors.white,
      onConfirm: () {
        Get.back();
        ctrl.removeDocument(s.employeeId, s.document!.id);
      },
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final DocumentSubmissionModel submission;
  final VoidCallback? onTap;

  const _SubmissionTile({required this.submission, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final doc = submission.document;
    final isVerified =
        doc?.status == 'uploaded' && doc?.verifiedAt != null;

    Color statusColor;
    String statusLabel;
    IconData icon;
    if (doc == null) {
      statusColor = colors.textTertiary;
      statusLabel = 'doc_not_submitted'.tr;
      icon = Icons.remove_circle_outline;
    } else if (doc.status == 'rejected') {
      statusColor = colors.error;
      statusLabel = 'status_rejected'.tr;
      icon = Icons.cancel_outlined;
    } else if (doc.status == 'expired') {
      statusColor = colors.error;
      statusLabel = 'status_expired'.tr;
      icon = Icons.warning_amber_rounded;
    } else if (isVerified) {
      statusColor = colors.success;
      statusLabel = 'document_verified'.tr;
      icon = Icons.check_circle_outline;
    } else {
      statusColor = colors.warning;
      statusLabel = 'status_under_review'.tr;
      icon = Icons.hourglass_top;
    }

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
              Icon(icon, size: 22, color: statusColor),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submission.employeeName,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (submission.branchName != null &&
                        submission.branchName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        submission.branchName!,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.s1),
                Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
