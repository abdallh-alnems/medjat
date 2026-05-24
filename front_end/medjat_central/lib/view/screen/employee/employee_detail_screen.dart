import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';
import '../../../logic/controller/employee/employee_detail_controller.dart';
import '../../../data/model/document_model.dart';
import '../../../data/model/warning_model.dart';
import '../../../data/model/performance_review_model.dart';
import '../../../data/model/attendance_model.dart';
import '../../../core/constant/routes/app_routes.dart';

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
                await ctrl.loadReviews();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    if (ctrl.employee != null &&
                        ctrl.employee!.status != 'terminated')
                      _ActivationCodeCard(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    _InfoSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    if (ctrl.canManagePayroll) ...[
                      _AdjustmentsSection(ctrl: ctrl),
                      const SizedBox(height: AppSpacing.s5),
                    ],
                    _DocumentsSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    _BiometricSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    _RecentAttendanceSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    if (ctrl.hasLeaveBalance) ...[
                      _LeaveBalanceSection(ctrl: ctrl),
                      const SizedBox(height: AppSpacing.s5),
                    ],
                    _WarningsSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s5),
                    _PerformanceReviewsSection(ctrl: ctrl),
                    const SizedBox(height: AppSpacing.s7),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_employee_attendance',
        onPressed: () => _showQuickAttendanceSheet(context, ctrl),
        backgroundColor: AppColors.of(context).brand,
        child: const Icon(Icons.timer_outlined, color: Colors.white),
      ),
    );
  }

  void _showQuickAttendanceSheet(BuildContext context, EmployeeDetailController ctrl) async {
    final attendanceCtrl = Get.find<AttendanceController>();
    final employee = ctrl.employee;
    if (employee == null) return;

    final today = DateTime.now();
    final hasRecord = attendanceCtrl.records
        .any((r) => r.employeeId == employee.id);

    if (hasRecord) {
      Get.snackbar('manual_check_in'.tr, 'attendance_recorded_today'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    TimeOfDay checkIn = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay checkOut = const TimeOfDay(hour: 17, minute: 0);

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = AppColors.of(context);
          return Container(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s4,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
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
                  Text('manual_check_in'.tr, style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(employee.name,
                      style: AppTextStyles.bodySecondary(context)),
                  const SizedBox(height: AppSpacing.s4),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('check_in'.tr, style: AppTextStyles.h3(context)),
                            const SizedBox(height: AppSpacing.s2),
                            InkWell(
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: sheetCtx,
                                  initialTime: checkIn,
                                );
                                if (t != null) setSheetState(() => checkIn = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s3),
                                decoration: BoxDecoration(
                                  color: colors.sunken,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: colors.borderHairline),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.login, size: 18, color: colors.textSecondary),
                                    const SizedBox(width: AppSpacing.s2),
                                    Text(
                                      '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.brand,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('check_out'.tr, style: AppTextStyles.h3(context)),
                            const SizedBox(height: AppSpacing.s2),
                            InkWell(
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: sheetCtx,
                                  initialTime: checkOut,
                                );
                                if (t != null) setSheetState(() => checkOut = t);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s3),
                                decoration: BoxDecoration(
                                  color: colors.sunken,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: colors.borderHairline),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, size: 18, color: colors.textSecondary),
                                    const SizedBox(width: AppSpacing.s2),
                                    Text(
                                      '${checkOut.hour.toString().padLeft(2, '0')}:${checkOut.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.brand,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await attendanceCtrl.recordManualAttendance(
                          employeeId: employee.id,
                          branchId: employee.branchId,
                          date: today,
                          checkInTime: checkIn,
                          checkOutTime: checkOut,
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                        child: Text('save'.tr),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
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
                        color: _employeeStatusColor(e?.status ?? '', colors)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        e?.statusLabel ?? '',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _employeeStatusColor(e?.status ?? '', colors),
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
    final isActiveEmployee = ctrl.employee?.status == 'active';
    final hasCode = ctrl.hasActiveCode;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.brand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_outlined, color: colors.brand, size: 22),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Text(
                  'activation_code'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (isActiveEmployee && ctrl.deviceBound)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'employee_active'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          if (hasCode) ...[
            _CodeRow(ctrl: ctrl, colors: colors),
            const SizedBox(height: AppSpacing.s2),
            _ExpiryLine(ctrl: ctrl, colors: colors),
            const SizedBox(height: AppSpacing.s3),
            _ActionRow(ctrl: ctrl, colors: colors),
          ] else if (isActiveEmployee) ...[
            _DeviceInfo(ctrl: ctrl, colors: colors),
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmDeviceReset(context, ctrl),
                icon: Icon(Icons.phonelink_setup, size: 18, color: colors.brand),
                label: Text('reset_device_title'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brand,
                  side: BorderSide(color: colors.brand),
                ),
              ),
            ),
          ] else ...[
            Text(
              'no_active_code'.tr,
              style: AppTextStyles.bodySecondary(context),
            ),
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ctrl.generateActivationCode,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('generate_activation_code'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDeviceReset(
      BuildContext context, EmployeeDetailController ctrl) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('reset_device_title'.tr),
        content: Text('reset_device_warning'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text('reset_device_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ctrl.generateActivationCode();
    }
  }
}

class _CodeRow extends StatelessWidget {
  final EmployeeDetailController ctrl;
  final AppColorScheme colors;
  const _CodeRow({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              ctrl.activationCode ?? '',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: colors.brand,
              ),
            ),
          ),
          IconButton(
            tooltip: 'copy_code'.tr,
            icon: Icon(Icons.content_copy, size: 18, color: colors.brand),
            onPressed: ctrl.copyCodeToClipboard,
          ),
        ],
      ),
    );
  }
}

class _ExpiryLine extends StatelessWidget {
  final EmployeeDetailController ctrl;
  final AppColorScheme colors;
  const _ExpiryLine({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    final remaining = ctrl.activationRemaining;
    if (remaining == null) {
      return const SizedBox.shrink();
    }
    final isExpired = remaining <= Duration.zero;
    final color = isExpired
        ? colors.error
        : (remaining.inHours < 2 ? colors.warning : colors.textSecondary);

    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: color),
        const SizedBox(width: AppSpacing.s2),
        Text(
          isExpired
              ? 'code_expired'.tr
              : 'code_expires_in'.trParams(
                  {'duration': _formatDuration(remaining)},
                ),
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      return 'duration_hours_minutes'.trParams({
        'hours': d.inHours.toString(),
        'minutes': (d.inMinutes % 60).toString(),
      });
    }
    return 'duration_minutes'.trParams({'minutes': d.inMinutes.toString()});
  }
}

class _ActionRow extends StatelessWidget {
  final EmployeeDetailController ctrl;
  final AppColorScheme colors;
  const _ActionRow({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: ctrl.shareCodeViaWhatsApp,
            icon: const Icon(Icons.share, size: 18),
            label: Text('share_via_whatsapp'.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        OutlinedButton.icon(
          onPressed: ctrl.generateActivationCode,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text('regenerate_code'.tr),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.brand,
            side: BorderSide(color: colors.brand),
          ),
        ),
      ],
    );
  }
}

class _DeviceInfo extends StatelessWidget {
  final EmployeeDetailController ctrl;
  final AppColorScheme colors;
  const _DeviceInfo({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (!ctrl.deviceBound) {
      return Text(
        'no_device_bound'.tr,
        style: AppTextStyles.bodySecondary(context),
      );
    }
    final platform = ctrl.devicePlatform == 'ios'
        ? 'device_platform_ios'.tr
        : 'device_platform_android'.tr;
    final lastUsed = ctrl.deviceLastUsedAt;
    final lastUsedLabel = lastUsed == null
        ? '—'
        : '${lastUsed.year}-${lastUsed.month.toString().padLeft(2, '0')}-${lastUsed.day.toString().padLeft(2, '0')} ${lastUsed.hour.toString().padLeft(2, '0')}:${lastUsed.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.smartphone, size: 16, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.s2),
            Text(
              ctrl.deviceModel?.isNotEmpty == true
                  ? '${ctrl.deviceModel} · $platform'
                  : platform,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s1),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 22),
          child: Text(
            'device_last_seen'.trParams({'date': lastUsedLabel}),
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              color: colors.textTertiary,
            ),
          ),
        ),
      ],
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
        _InfoRow(
            label: 'base_salary'.tr,
            value:
                '${e.baseSalary.toStringAsFixed(e.baseSalary == e.baseSalary.roundToDouble() ? 0 : 2)} ج.م'),
        _InfoRow(label: 'branch'.tr, value: e.branchName ?? '—'),
        _InfoRow(
            label: 'hire_date'.tr,
            value: e.hireDate != null
                ? '${e.hireDate!.year}-${e.hireDate!.month.toString().padLeft(2, '0')}-${e.hireDate!.day.toString().padLeft(2, '0')}'
                : '—'),
        if (e.bankName != null && e.bankName!.isNotEmpty ||
            e.bankAccountNumber != null && e.bankAccountNumber!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s3),
          Text('bank_info'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s2),
          _InfoRow(label: 'bank_name'.tr, value: e.bankName ?? '—'),
          _InfoRow(label: 'bank_account_number'.tr, value: e.bankAccountNumber ?? '—'),
          _InfoRow(label: 'bank_iban'.tr, value: e.bankIban ?? '—'),
          if (e.bankSwift != null && e.bankSwift!.isNotEmpty)
            _InfoRow(label: 'bank_swift'.tr, value: e.bankSwift!),
        ],
        if (e.hasComplianceInfo) ...[
          const SizedBox(height: AppSpacing.s3),
          Text('compliance_info'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s2),
          if (e.nationalId != null && e.nationalId!.isNotEmpty)
            _InfoRow(label: 'national_id'.tr, value: e.nationalId!),
          if (e.nationality != null && e.nationality!.isNotEmpty)
            _InfoRow(label: 'nationality'.tr, value: e.nationality!),
          if ((e.iqamaNumber != null && e.iqamaNumber!.isNotEmpty) ||
              e.iqamaExpiry != null)
            _ComplianceRow(
                label: 'iqama_number'.tr,
                value: e.iqamaNumber,
                expiry: e.iqamaExpiry),
          if ((e.passportNumber != null && e.passportNumber!.isNotEmpty) ||
              e.passportExpiry != null)
            _ComplianceRow(
                label: 'passport_number'.tr,
                value: e.passportNumber,
                expiry: e.passportExpiry),
          if ((e.workPermitNumber != null &&
                  e.workPermitNumber!.isNotEmpty) ||
              e.workPermitExpiry != null)
            _ComplianceRow(
                label: 'work_permit_number'.tr,
                value: e.workPermitNumber,
                expiry: e.workPermitExpiry),
          if (e.contractType != null)
            _InfoRow(
                label: 'contract_type'.tr,
                value: 'contract_${e.contractType}'.tr),
          if (e.contractEnd != null)
            _ComplianceRow(label: 'contract_end'.tr, expiry: e.contractEnd),
          if (e.healthInsuranceExpiry != null)
            _ComplianceRow(
                label: 'health_insurance_expiry'.tr,
                expiry: e.healthInsuranceExpiry),
        ],
        if (ctrl.categories.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  'employee_categories'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: AppColors.of(context).textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.s1,
                  runSpacing: AppSpacing.s1,
                  children: ctrl.categories.map((cat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.of(context).brandSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        (cat['name'] as String?) ?? '',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.of(context).brand,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
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

/// Info row for a compliance credential: optional number + colored expiry badge.
class _ComplianceRow extends StatelessWidget {
  final String label;
  final String? value;
  final DateTime? expiry;
  const _ComplianceRow({required this.label, this.value, this.expiry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (value != null && value!.isNotEmpty)
                  Text(
                    value!,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (expiry != null) _ExpiryBadge(expiry: expiry!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small chip showing an expiry date, colored by how close it is.
class _ExpiryBadge extends StatelessWidget {
  final DateTime expiry;
  const _ExpiryBadge({required this.expiry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final today = DateTime.now();
    final dayOnly = DateTime(today.year, today.month, today.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final daysLeft = expiryDay.difference(dayOnly).inDays;
    final dateStr =
        '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';

    Color color;
    String text;
    if (daysLeft < 0) {
      color = colors.error;
      text = '$dateStr · ${'expired'.tr}';
    } else if (daysLeft <= 30) {
      color = colors.warning;
      text = '$dateStr · ${'expires_in_days'.trParams({'days': '$daysLeft'})}';
    } else {
      color = colors.textSecondary;
      text = dateStr;
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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

    final e = ctrl.employee;

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
        if (e != null) ...[
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Get.toNamed<void>(
                AppRoutes.employeeDocuments,
                arguments: {'employee_id': e.id, 'employee_name': e.name},
              ),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: Text('manage_documents_button'.tr,
                  style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic')),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.brand,
                side: BorderSide(color: colors.brand),
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
        ],
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

class _BiometricSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _BiometricSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = ctrl.employee;
    if (e == null) return const SizedBox.shrink();

    final status = e.biometricEnrollmentStatus;
    final isEnrolled = status != 'not_enrolled';
    final statusLabel = status == 'face_only'
        ? 'face_enrollment'.tr
        : status == 'fingerprint_only'
            ? 'fingerprint_enrollment'.tr
            : status == 'both'
                ? '${'face_enrollment'.tr} + ${'fingerprint_enrollment'.tr}'
                : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('biometric_data'.tr, style: AppTextStyles.h3(context)),
            const Spacer(),
            if (isEnrolled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'enrolled'.tr,
                  style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 11, color: colors.success, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Row(
            children: [
              Icon(Icons.fingerprint, size: 22, color: isEnrolled ? colors.success : colors.textTertiary),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEnrolled ? statusLabel : 'biometric_data_desc'.tr,
                      style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_left, size: 20, color: colors.textTertiary),
                onPressed: () => Get.toNamed<void>(
                  AppRoutes.biometricEnrollment,
                  arguments: {'employee_id': e.id, 'employee_name': e.name},
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
            final displayDate = r.date ??
                (r.checkIn != null
                    ? '${r.checkIn!.year}-${r.checkIn!.month.toString().padLeft(2, '0')}-${r.checkIn!.day.toString().padLeft(2, '0')}'
                    : null);
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
                      displayDate ?? '',
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
                  if (r.status == 'absent' &&
                      ctrl.canManageLeaves &&
                      displayDate != null) ...[
                    const SizedBox(width: AppSpacing.s2),
                    InkWell(
                      onTap: () => _showConvertAbsenceSheet(context, r),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s2,
                          vertical: AppSpacing.s1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentWarm.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                              color: colors.accentWarm.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz,
                                size: 14, color: colors.accentWarm),
                            const SizedBox(width: AppSpacing.s1),
                            Text(
                              'convert_to_leave'.tr,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colors.accentWarm,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showConvertAbsenceSheet(
      BuildContext context, AttendanceRecordModel record) {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedType = 'annual';

    final leaveTypes = [
      ('annual', 'leave_type_annual'),
      ('sick', 'leave_type_sick'),
      ('unpaid', 'leave_type_unpaid'),
    ];

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = AppColors.of(context);
          final isLoading = ctrl.conversionStatus == StatusRequest.loading;

          return Container(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s4,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
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
                    Text('convert_absence_title'.tr,
                        style: AppTextStyles.h2(context)),
                    const SizedBox(height: AppSpacing.s2),
                    Text(ctrl.employee?.name ?? '',
                        style: AppTextStyles.bodySecondary(context)),
                    const SizedBox(height: AppSpacing.s4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.s2),
                        Text(
                          '${'selected_absence_date'.tr}: ',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                        Text(
                          record.date ?? '',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'select_leave_type'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.sunken,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          isExpanded: true,
                          icon: Icon(Icons.arrow_drop_down,
                              color: colors.textSecondary),
                          items: leaveTypes.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.$1,
                              child: Text(
                                e.$2.tr,
                                style: const TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setSheetState(() => selectedType = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'conversion_reason'.tr,
                        hintText: 'enter_conversion_reason'.tr,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'reason_required'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                Get.back();
                                await ctrl.convertAbsenceToLeave(
                                  date: record.date!,
                                  type: selectedType,
                                  reason: reasonCtrl.text.trim(),
                                );
                              },
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.swap_horiz),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s2),
                          child: Text('convert_to_leave'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
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

Color _employeeStatusColor(String status, AppColorScheme colors) {
  switch (status) {
    case 'active':
      return colors.success;
    case 'pending_activation':
      return colors.warning;
    case 'on_leave':
      return colors.accentWarm;
    case 'suspended':
      return colors.error;
    case 'terminated':
      return colors.textTertiary;
    default:
      return colors.textTertiary;
  }
}

class _AdjustmentsSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _AdjustmentsSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('adjustments'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: AppSpacing.s3),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showAdjustmentSheet(
                  context,
                  isDeduction: true,
                ),
                icon: Icon(Icons.remove_circle_outline, size: 18, color: colors.error),
                label: Text('add_deduction'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showAdjustmentSheet(
                  context,
                  isDeduction: false,
                ),
                icon: Icon(Icons.add_circle_outline, size: 18, color: colors.success),
                label: Text('add_bonus'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.success,
                  side: BorderSide(color: colors.success),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAdjustmentSheet(BuildContext context, {required bool isDeduction}) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = AppColors.of(context);
          final isLoading = ctrl.adjustmentStatus == StatusRequest.loading;

          return Container(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s4,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
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
                    Text(
                      isDeduction ? 'add_deduction'.tr : 'add_bonus'.tr,
                      style: AppTextStyles.h2(context),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      ctrl.employee?.name ?? '',
                      style: AppTextStyles.bodySecondary(context),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'amount'.tr,
                        hintText: 'enter_amount'.tr,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Geist', fontSize: 16),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'amount_required'.tr;
                        final parsed = num.tryParse(v);
                        if (parsed == null || parsed <= 0) return 'amount_must_be_positive'.tr;
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'reason'.tr,
                        hintText: 'enter_reason'.tr,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'reason_required'.tr;
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final amount = num.parse(amountCtrl.text);
                                final reason = reasonCtrl.text.trim();
                                Get.back();
                                if (isDeduction) {
                                  await ctrl.addManualDeduction(
                                    amount: amount,
                                    reason: reason,
                                  );
                                } else {
                                  await ctrl.addManualBonus(
                                    amount: amount,
                                    reason: reason,
                                  );
                                }
                              },
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                          child: Text('save'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }
}

class _LeaveBalanceSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _LeaveBalanceSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final used = ctrl.leaveUsed;
    final remaining = ctrl.leaveRemaining;
    final total = ctrl.leaveTotal;
    final progress = total > 0 ? used / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('leave_balance'.tr, style: AppTextStyles.h3(context)),
            const Spacer(),
            Text(
              '${ctrl.leaveYear}',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textTertiary,
              ),
            ),
            if (ctrl.canManageEmployees)
              IconButton(
                onPressed: () => _showEditAnnualLeaveSheet(context),
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: colors.textSecondary),
                tooltip: 'employee_annual_leave_label'.tr,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: colors.sunken,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.8 ? colors.warning : colors.brand,
                  ),
                ),
              ),
              if (ctrl.leaveCarriedOver > 0) ...[
                const SizedBox(height: AppSpacing.s3),
                Row(
                  children: [
                    Icon(Icons.sync_alt, size: 14, color: colors.textTertiary),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        'leave_carried_over_note'.trParams({
                          'days': ctrl.leaveCarriedOver.toString(),
                        }),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$used',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          'leave_used'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$remaining',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.success,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          'leave_remaining'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$total',
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Text(
                          'leave_total_annual'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditAnnualLeaveSheet(BuildContext context) {
    final colors = AppColors.of(context);
    final fieldCtrl = TextEditingController(
      text: ctrl.employee?.annualLeaveDays?.toString() ?? '',
    );

    Get.bottomSheet<void>(
      Container(
        padding: EdgeInsets.only(
          left: AppSpacing.s4,
          right: AppSpacing.s4,
          top: AppSpacing.s4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
        ),
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
            Text('employee_annual_leave_label'.tr,
                style: AppTextStyles.h2(context)),
            const SizedBox(height: AppSpacing.s2),
            Text('employee_annual_leave_hint'.tr,
                style: AppTextStyles.sm(context)),
            const SizedBox(height: AppSpacing.s4),
            TextField(
              controller: fieldCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'employee_annual_leave_label'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final text = fieldCtrl.text.trim();
                  Get.back<void>();
                  ctrl.updateAnnualLeaveDays(
                      text.isEmpty ? null : int.tryParse(text));
                },
                icon: const Icon(Icons.save_outlined),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                  child: Text('save'.tr),
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _WarningsSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _WarningsSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('warnings_log'.tr, style: AppTextStyles.h3(context)),
            const Spacer(),
            if (ctrl.canManageEmployees)
              OutlinedButton.icon(
                onPressed: () => _showAddWarningSheet(context),
                icon: Icon(Icons.add_circle_outline, size: 18, color: colors.warning),
                label: Text('add_warning'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.warning,
                  side: BorderSide(color: colors.warning),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                    vertical: AppSpacing.s1,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        if (ctrl.warnings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Text('no_warnings'.tr,
                  style: AppTextStyles.bodySecondary(context)),
            ),
          )
        else
          ...ctrl.warnings.map((w) => _WarningTile(warning: w)),
      ],
    );
  }

  void _showAddWarningSheet(BuildContext context) {
    String selectedType = 'verbal';
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = AppColors.of(context);
          final isLoading = ctrl.warningStatus == StatusRequest.loading;

          return Container(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s4,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
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
                    Text('add_warning'.tr, style: AppTextStyles.h2(context)),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      ctrl.employee?.name ?? '',
                      style: AppTextStyles.bodySecondary(context),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'select_warning_type'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    ...['verbal', 'written', 'final'].map((t) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                        child: InkWell(
                          onTap: () => setSheetState(() => selectedType = t),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.s3),
                            decoration: BoxDecoration(
                              color: selectedType == t
                                  ? colors.brandSubtle
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: selectedType == t
                                    ? colors.brand
                                    : colors.borderHairline,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedType == t
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: selectedType == t
                                      ? colors.brand
                                      : colors.textTertiary,
                                ),
                                const SizedBox(width: AppSpacing.s3),
                                Text(
                                  _warningTypeLabel(t),
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 14,
                                    fontWeight: selectedType == t
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selectedType == t
                                        ? colors.brand
                                        : colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.s3),
                    TextFormField(
                      controller: reasonCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'warning_reason'.tr,
                        hintText: 'warning_reason_hint'.tr,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'reason_required'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                final reason = reasonCtrl.text.trim();
                                Get.back();
                                await ctrl.addWarning(
                                  type: selectedType,
                                  reason: reason,
                                );
                              },
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                          child: Text('save'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  String _warningTypeLabel(String type) {
    switch (type) {
      case 'verbal':
        return 'warning_type_verbal'.tr;
      case 'written':
        return 'warning_type_written'.tr;
      case 'final':
        return 'warning_type_final'.tr;
      default:
        return type;
    }
  }
}

class _WarningTile extends StatelessWidget {
  final WarningModel warning;
  const _WarningTile({required this.warning});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typeColor = _warningColor(warning.type, colors);
    final date = warning.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s2,
              vertical: AppSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              warning.typeLabel,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.reason,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.s1),
                Row(
                  children: [
                    if (date != null)
                      Text(
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    if (warning.issuedByName != null) ...[
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        '·',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Flexible(
                        child: Text(
                          warning.issuedByName!,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _warningColor(String type, AppColorScheme colors) {
    switch (type) {
      case 'verbal':
        return colors.warning;
      case 'written':
        return colors.accentWarm;
      case 'final':
        return colors.error;
      case 'device_change':
      case 'system':
        return colors.textTertiary;
      default:
        return colors.textTertiary;
    }
  }
}

class _PerformanceReviewsSection extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _PerformanceReviewsSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('performance_reviews'.tr, style: AppTextStyles.h3(context)),
            const Spacer(),
            if (ctrl.canManageEmployees)
              OutlinedButton.icon(
                onPressed: () => _showAddReviewSheet(context),
                icon: Icon(Icons.star_outline, size: 18, color: colors.brand),
                label: Text('add_review'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brand,
                  side: BorderSide(color: colors.brand),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                    vertical: AppSpacing.s1,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s3),
        if (ctrl.reviewStatus == StatusRequest.loading)
          const Center(child: CircularProgressIndicator.adaptive())
        else if (ctrl.reviews.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s5),
              child: Text('no_reviews_yet'.tr,
                  style: AppTextStyles.bodySecondary(context)),
            ),
          )
        else
          ...ctrl.reviews.map((r) => _ReviewTile(
                review: r,
                onDelete: ctrl.canManageEmployees
                    ? () => _confirmDeleteReview(context, r.id)
                    : null,
              )),
      ],
    );
  }

  void _confirmDeleteReview(BuildContext context, int reviewId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('delete'.tr),
        content: Text('confirm_delete_review'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors(context).error,
              foregroundColor: Colors.white,
            ),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ctrl.deleteReview(reviewId);
    }
  }

  AppColorScheme colors(BuildContext context) => AppColors.of(context);

  void _showAddReviewSheet(BuildContext context) {
    int selectedRating = 3;
    final periodCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final colors = AppColors.of(context);
          final isLoading = ctrl.reviewStatus == StatusRequest.loading;

          return Container(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s4,
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
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
                    Text('add_review'.tr, style: AppTextStyles.h2(context)),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      ctrl.employee?.name ?? '',
                      style: AppTextStyles.bodySecondary(context),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'review_rating'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    _StarRating(
                      rating: selectedRating,
                      onChanged: (v) => setSheetState(() => selectedRating = v),
                      colors: colors,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      _ratingLabel(selectedRating),
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ratingColor(selectedRating, colors),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    TextFormField(
                      controller: periodCtrl,
                      decoration: InputDecoration(
                        labelText: 'review_period'.tr,
                        hintText: 'review_period_hint'.tr,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Geist', fontSize: 16),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'required'.tr;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'review_notes'.tr,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                Get.back();
                                await ctrl.addReview(
                                  rating: selectedRating,
                                  period: periodCtrl.text.trim(),
                                  notes: notesCtrl.text.trim().isEmpty
                                      ? null
                                      : notesCtrl.text.trim(),
                                );
                              },
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                          child: Text('save'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'rating_1'.tr;
      case 2:
        return 'rating_2'.tr;
      case 3:
        return 'rating_3'.tr;
      case 4:
        return 'rating_4'.tr;
      case 5:
        return 'rating_5'.tr;
      default:
        return '';
    }
  }

  Color _ratingColor(int rating, AppColorScheme colors) {
    switch (rating) {
      case 1:
        return colors.error;
      case 2:
        return colors.warning;
      case 3:
        return colors.accentWarm;
      case 4:
        return colors.success;
      case 5:
        return colors.brand;
      default:
        return colors.textTertiary;
    }
  }
}

class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final AppColorScheme colors;

  const _StarRating({
    required this.rating,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final index = i + 1;
        final filled = index <= rating;
        return GestureDetector(
          onTap: () => onChanged(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s1),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: 32,
              color: filled ? _starColor(rating, colors) : colors.textTertiary,
            ),
          ),
        );
      }),
    );
  }

  Color _starColor(int rating, AppColorScheme colors) {
    switch (rating) {
      case 1:
        return colors.error;
      case 2:
        return colors.warning;
      case 3:
        return colors.accentWarm;
      case 4:
        return colors.success;
      case 5:
        return colors.brand;
      default:
        return colors.brand;
    }
  }
}

class _ReviewTile extends StatelessWidget {
  final PerformanceReviewModel review;
  final VoidCallback? onDelete;

  const _ReviewTile({required this.review, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final date = review.createdAt;
    final ratingColor = _ratingColor(review.rating, colors);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: i < review.rating
                        ? ratingColor
                        : colors.textTertiary,
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.s1),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  review.ratingLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: ratingColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.period,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (review.notes != null && review.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    review.notes!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s1),
                Row(
                  children: [
                    if (date != null)
                      Text(
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    if (review.reviewerName != null) ...[
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        '·',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Flexible(
                        child: Text(
                          '${'reviewed_by'.tr} ${review.reviewerName!}',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null) ...[
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

  Color _ratingColor(int rating, AppColorScheme colors) {
    switch (rating) {
      case 1:
        return colors.error;
      case 2:
        return colors.warning;
      case 3:
        return colors.accentWarm;
      case 4:
        return colors.success;
      case 5:
        return colors.brand;
      default:
        return colors.textTertiary;
    }
  }
}
