import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/employee/employee_detail_controller.dart';
import '../../../data/model/document_model.dart';

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int employeeId =
        (Get.arguments as Map<String, dynamic>?)?['id'] as int? ?? 0;
    final ctrl = Get.put(
      EmployeeDetailController(employeeId: employeeId),
    );

    return Scaffold(
      appBar: AppBar(title: Text('employee_profile'.tr)),
      body: GetBuilder<EmployeeDetailController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadEmployee,
            widget: RefreshIndicator(
              onRefresh: () async {
                await ctrl.loadEmployee();
                await ctrl.loadAttendance();
                await ctrl.loadDocuments();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    if (ctrl.activationCode != null)
                      _ActivationCodeCard(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    _InfoSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    _DocumentsSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    _RecentAttendanceSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s7),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ProfileHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = ctrl.employee;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colors.brandSubtle,
            backgroundImage:
                e?.photoUrl != null ? NetworkImage(e!.photoUrl!) : null,
            child: e?.photoUrl == null
                ? Text(
                    e?.name.isNotEmpty == true ? e!.name[0] : '?',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: colors.brand,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e?.name ?? '',
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (e?.jobTitle != null) ...[
                  const SizedBox(height: 2),
                  Text(e!.jobTitle!, style: AppTextStyles.bodySecondary(context)),
                ],
                const SizedBox(height: AppSpacing.s1),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s2,
                        vertical: AppSpacing.s1,
                      ),
                      decoration: BoxDecoration(
                        color: (e?.status == 'active'
                                ? colors.success
                                : colors.error)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        e?.statusLabel ?? '',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: e?.status == 'active'
                              ? colors.success
                              : colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationCodeCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ActivationCodeCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.brand),
      ),
      child: Row(
        children: [
          Icon(Icons.key_outlined, color: colors.brand, size: 22),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'activation_code'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                Text(
                  ctrl.activationCode ?? '',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: colors.brand,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: ctrl.generateActivationCode,
            child: Text('generate_new'.tr),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _InfoSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final e = ctrl.employee;
    if (e == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('info'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: AppSpacing.s3),
        _InfoRow(label: 'phone_number'.tr, value: e.phone ?? '—'),
        _InfoRow(label: 'email'.tr, value: e.email ?? '—'),
        _InfoRow(
            label: 'base_salary'.tr,
            value: '${e.baseSalary.toStringAsFixed(0)} ج.م'),
        _InfoRow(label: 'branch'.tr, value: e.branchName ?? '—'),
        _InfoRow(
            label: 'hire_date'.tr,
            value: e.hireDate != null
                ? '${e.hireDate!.year}-${e.hireDate!.month.toString().padLeft(2, '0')}-${e.hireDate!.day.toString().padLeft(2, '0')}'
                : '—'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _DocumentsSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('documents'.tr, style: AppTextStyles.h3(context)),
            const Spacer(),
            Text(
              '${ctrl.documents.where((d) => d.status == 'uploaded').length}/${ctrl.documents.length}',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.brand,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        if (ctrl.documentsStatus == StatusRequest.loading)
          const Center(child: CircularProgressIndicator.adaptive())
        else if (ctrl.documents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Text('no_documents'.tr,
                  style: AppTextStyles.bodySecondary(context)),
            ),
          )
        else
          ...ctrl.documents.map((doc) => _DocumentTile(
                document: doc,
                onDelete: () => ctrl.deleteDocument(doc.id),
              )),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onDelete;
  const _DocumentTile({required this.document, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(document.status, colors);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Icon(
            document.status == 'uploaded'
                ? Icons.description_outlined
                : Icons.error_outline,
            size: 22,
            color: statusColor,
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (document.expiryDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${'expires'.tr} ${document.expiryDate!.year}-${document.expiryDate!.month.toString().padLeft(2, '0')}-${document.expiryDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontFamily: 'Geist',
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
              horizontal: AppSpacing.s2,
              vertical: AppSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              document.statusLabel,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
          if (document.status == 'uploaded') ...[
            const SizedBox(width: AppSpacing.s2),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: colors.error),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'uploaded':
        return colors.success;
      case 'required':
        return colors.warning;
      case 'expired':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }
}

class _RecentAttendanceSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _RecentAttendanceSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('recent_attendance'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: AppSpacing.s3),
        if (ctrl.attendanceStatus == StatusRequest.loading)
          const Center(child: CircularProgressIndicator.adaptive())
        else if (ctrl.attendanceRecords.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Text('no_attendance_records'.tr,
                  style: AppTextStyles.bodySecondary(context)),
            ),
          )
        else
          ...ctrl.attendanceRecords.take(10).map((r) {
            final statusColor = _statusColor(r.status, colors);
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s2),
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.borderHairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${r.checkIn?.year ?? ''}-${(r.checkIn?.month ?? 1).toString().padLeft(2, '0')}-${(r.checkIn?.day ?? 1).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  if (r.checkIn != null)
                    Text(
                      '${r.checkIn!.hour.toString().padLeft(2, '0')}:${r.checkIn!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  if (r.checkIn != null && r.checkOut != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s2),
                      child: Text('—',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary)),
                    ),
                  if (r.checkOut != null)
                    Text(
                      '${r.checkOut!.hour.toString().padLeft(2, '0')}:${r.checkOut!.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.s2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2,
                      vertical: AppSpacing.s1,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      r.statusLabel,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'present':
        return colors.success;
      case 'absent':
        return colors.error;
      case 'late':
        return colors.warning;
      case 'leave':
        return colors.accentWarm;
      default:
        return colors.textTertiary;
    }
  }
}
