import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';

class DocumentCard extends StatelessWidget {
  final String status;
  final bool isVerified;
  final String documentTypeName;
  final String? expiryDate;
  final String? rejectedReason;
  final bool canUpload;
  final int? docTypeId;
  final bool isUploading;
  final int? employeeDocId;
  final bool hasFile;
  final bool isOpening;
  final VoidCallback? onOpen;
  final VoidCallback? onUpload;

  const DocumentCard({
    super.key,
    required this.status,
    required this.isVerified,
    required this.documentTypeName,
    this.expiryDate,
    this.rejectedReason,
    required this.canUpload,
    this.docTypeId,
    required this.isUploading,
    this.employeeDocId,
    required this.hasFile,
    required this.isOpening,
    this.onOpen,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status == 'uploaded' && isVerified) {
      statusColor = Colors.green;
      statusText = 'doc_status_approved'.tr;
      statusIcon = Icons.verified;
    } else if (status == 'uploaded') {
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
                      documentTypeName,
                      style: AppTextStyles.body(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (expiryDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                          'expires_at'.trParams({'date': expiryDate!}),
                          style: AppTextStyles.xs(context)),
                    ],
                    if (status == 'rejected' && rejectedReason != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${'reject_reason'.tr}: $rejectedReason',
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
                        onPressed: onOpen,
                      ),
              ],
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
                        onPressed: onUpload,
                      ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
