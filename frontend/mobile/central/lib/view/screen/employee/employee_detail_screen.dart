import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widget/month_grid_picker.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/employee_model.dart';
import '../../../logic/controller/employee/employee_detail_controller.dart';
import '../../../logic/controller/payroll/payroll_controller.dart';
import '../../../data/model/document_model.dart';
import '../../../data/model/required_document_model.dart';
import '../../../data/model/warning_model.dart';
import '../../../data/model/suspension_model.dart';
import '../../../data/model/performance_review_model.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/financial_summary_model.dart';
import 'widgets/employee_kiosk_card.dart';

class EmployeeDetailScreen extends StatelessWidget {
  const EmployeeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final int employeeId = args?['id'] as int? ?? 0;
    final int initialTab = args?['initialTab'] as int? ?? 0;
    final ctrl = Get.put(EmployeeDetailController(employeeId: employeeId));

    return GetBuilder<EmployeeDetailController>(
      builder: (_) {
        final canPayroll = ctrl.canManagePayroll;
        final tabs = <_TabSpec>[
          _TabSpec('tab_overview'.tr),
          _TabSpec('tab_attendance'.tr),
          if (canPayroll) _TabSpec('tab_financial'.tr),
          _TabSpec('tab_documents'.tr),
          _TabSpec('tab_warnings'.tr),
          _TabSpec('tab_reviews'.tr),
        ];

        return DefaultTabController(
          initialIndex: initialTab.clamp(0, tabs.length - 1),
          length: tabs.length,
          child: Scaffold(
            body: HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadEmployee,
              widget: NestedScrollView(
                headerSliverBuilder: (ctx, _) => [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 220,
                    title: Text('employee_profile'.tr),
                    actions: [
                      if (ctrl.canManageEmployees &&
                          ctrl.employee != null &&
                          ctrl.employee!.status != 'terminated')
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            switch (value) {
                              case 'suspend':
                                _showSuspendSheet(context, ctrl);
                                break;
                              case 'end_suspension':
                                _confirmEndSuspension(context, ctrl);
                                break;
                              case 'end_service':
                                Get.toNamed<void>(
                                  AppRoutes.employeeSettlement,
                                  arguments: {
                                    'employee_id': ctrl.employee!.id,
                                    'employee_name': ctrl.employee!.name,
                                  },
                                )?.then((_) => ctrl.loadEmployee());
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            if (!ctrl.isSuspended)
                              PopupMenuItem(
                                value: 'suspend',
                                child: Row(
                                  children: [
                                    const Icon(Icons.block, size: 20),
                                    const SizedBox(width: AppSpacing.s2),
                                    Text('suspend_employee'.tr),
                                  ],
                                ),
                              ),
                            if (ctrl.isSuspended)
                              PopupMenuItem(
                                value: 'end_suspension',
                                child: Row(
                                  children: [
                                    const Icon(Icons.play_circle_outline,
                                        size: 20),
                                    const SizedBox(width: AppSpacing.s2),
                                    Text('end_suspension'.tr),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'end_service',
                              child: Row(
                                children: [
                                  Icon(Icons.logout,
                                      size: 20,
                                      color: AppColors.of(context).error),
                                  const SizedBox(width: AppSpacing.s2),
                                  Text('end_service'.tr,
                                      style: TextStyle(
                                          color: AppColors.of(context).error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: _ProfileHeader(ctrl: ctrl),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        color: AppColors.of(context).surface,
                        child: TabBar(
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: AppColors.of(context).brand,
                          unselectedLabelColor:
                              AppColors.of(context).textSecondary,
                          indicatorColor: AppColors.of(context).brand,
                          labelStyle: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          tabs: tabs
                              .map((t) => Tab(
                                    height: 44,
                                    child: Text(t.label),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _OverviewTab(ctrl: ctrl),
                    _AttendanceTab(ctrl: ctrl),
                    if (canPayroll) _FinancialTab(ctrl: ctrl),
                    _DocumentsTab(ctrl: ctrl),
                    _WarningsTab(ctrl: ctrl),
                    _ReviewsTab(ctrl: ctrl),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabSpec {
  final String label;
  const _TabSpec(this.label);
}

/* ─────────────────────────────────────────────────────────────────────── */
/*  PROFILE HEADER                                                          */
/* ─────────────────────────────────────────────────────────────────────── */

class _ProfileHeader extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ProfileHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = ctrl.employee;
    if (e == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.brand.withValues(alpha: 0.15),
            colors.surface,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, 56, AppSpacing.s4, AppSpacing.s3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: colors.surface,
            child: CircleAvatar(
              radius: 36,
              backgroundColor: colors.brandSubtle,
              backgroundImage:
                  e.photoUrl != null ? NetworkImage(e.photoUrl!) : null,
              child: e.photoUrl == null
                  ? Text(
                      e.name.isNotEmpty ? e.name[0] : '?',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.brand,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            e.name,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (e.jobTitle != null) ...[
            const SizedBox(height: 2),
            Text(
              e.jobTitle!,
              style: AppTextStyles.sm(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.s2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: _employeeStatusColor(e.status, colors)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              e.statusLabel,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _employeeStatusColor(e.status, colors),
              ),
            ),
          ),
        ],
      ),
    );
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

/* ─────────────────────────────────────────────────────────────────────── */
/*  OVERVIEW TAB                                                            */
/* ─────────────────────────────────────────────────────────────────────── */

class _OverviewTab extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _OverviewTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: ctrl.loadEmployee,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          if (ctrl.isSuspended) ...[
            _SuspensionBanner(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (ctrl.employee != null &&
              ctrl.employee!.status != 'terminated')
            _ActivationCard(ctrl: ctrl),
          if (ctrl.employee != null &&
              ctrl.employee!.status != 'terminated')
            const SizedBox(height: AppSpacing.s4),
          if (ctrl.hasLeaveBalance) ...[
            _LeaveBalanceCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s4),
          ],
          _InfoCard(ctrl: ctrl),
          if (ctrl.employee != null &&
              ctrl.employee!.status != 'terminated') ...[
            const SizedBox(height: AppSpacing.s4),
            EmployeeKioskCard(
              employeeId: ctrl.employee!.id,
              faceEnrolledAt: ctrl.employee!.faceEnrolledAt,
              enrolledStationName: ctrl.employee!.faceEnrolledStationName,
              hasKioskCode: ctrl.employee!.hasKioskCode,
              canManage: ctrl.canManageEmployees,
            ),
          ],
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────────────────── */
/*  ACTIVATION CARD (simplified)                                            */
/* ─────────────────────────────────────────────────────────────────────── */

class _ActivationCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ActivationCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isActiveEmployee = ctrl.employee?.status == 'active';
    final hasCode = ctrl.hasActiveCode;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivationHeader(
            isActive: isActiveEmployee,
            hasCode: hasCode,
          ),
          if (isActiveEmployee)
            _ActivationActiveBody(ctrl: ctrl)
          else if (hasCode)
            _ActivationCodeBody(ctrl: ctrl)
          else
            _ActivationEmptyBody(ctrl: ctrl),
        ],
      ),
    );
  }
}

/* Header with icon, title, and status badge. */
class _ActivationHeader extends StatelessWidget {
  final bool isActive;
  final bool hasCode;
  const _ActivationHeader({required this.isActive, required this.hasCode});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (isActive) {
      badgeColor = colors.success;
      badgeText = 'employee_active_simple'.tr;
      badgeIcon = Icons.check_circle;
    } else if (hasCode) {
      badgeColor = colors.brand;
      badgeText = 'pending_activation'.tr;
      badgeIcon = Icons.pending_actions;
    } else {
      badgeColor = colors.warning;
      badgeText = 'pending_activation'.tr;
      badgeIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            colors.brand.withValues(alpha: 0.08),
            colors.brand.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s2),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.brand.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.key_rounded, size: 20, color: colors.brand),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'activation_code'.tr,
                  style: AppTextStyles.h3(context).copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 12, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* Body when employee is fully active (device bound). */
class _ActivationActiveBody extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ActivationActiveBody({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isBusy = ctrl.activationStatus == StatusRequest.loading;
    final hasDevice =
        ctrl.deviceBound && (ctrl.deviceModel ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasDevice)
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.sunken.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.borderHairline),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s2),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(Icons.smartphone,
                        size: 18, color: colors.success),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ctrl.deviceModel ?? '',
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ctrl.devicePlatform == 'ios'
                              ? 'device_platform_ios'.tr
                              : 'device_platform_android'.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (hasDevice) const SizedBox(height: AppSpacing.s3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  isBusy ? null : () => _confirmDeviceReset(context, ctrl),
              icon: Icon(Icons.phonelink_setup, size: 18, color: colors.brand),
              label: Text(
                'reset_and_create_code'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.brand,
                side: BorderSide(color: colors.brand),
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* Body when there's an active pending code. */
class _ActivationCodeBody extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ActivationCodeBody({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isBusy = ctrl.activationStatus == StatusRequest.loading;
    final remaining = ctrl.activationRemaining ?? Duration.zero;
    final isExpired = remaining <= Duration.zero;
    final progress =
        isExpired ? 0.0 : (remaining.inSeconds / (24 * 3600)).clamp(0.0, 1.0);
    final progressColor = isExpired
        ? colors.error
        : (remaining.inHours < 2 ? colors.warning : colors.brand);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero code display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4, vertical: AppSpacing.s4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  colors.brand,
                  colors.brand.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: colors.brand.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: SelectableText(
                          _formatCode(ctrl.activationCode ?? ''),
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: ctrl.copyCodeToClipboard,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s3, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.content_copy_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'copy_code'.tr,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // QR + link: same single-use token as the code above.
          if (ctrl.activationJoinLink != null &&
              ctrl.activationJoinLink!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s4),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: colors.borderHairline),
                ),
                child: QrImageView(
                  data: ctrl.activationJoinLink!,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Center(
              child: OutlinedButton.icon(
                onPressed: ctrl.copyJoinLinkToClipboard,
                icon: const Icon(Icons.link, size: 16),
                label: Text('copy_link'.tr),
                style:
                    OutlinedButton.styleFrom(foregroundColor: colors.brand),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),

          // Expiry indicator with progress bar
          Row(
            children: [
              Icon(
                isExpired ? Icons.error_outline : Icons.schedule_rounded,
                size: 16,
                color: progressColor,
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  isExpired
                      ? 'code_expired'.tr
                      : 'code_expires_in'.trParams(
                          {'duration': _formatDurationLocal(remaining)}),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.sunken,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),

          const SizedBox(height: AppSpacing.s4),

          // Actions
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isBusy
                  ? null
                  : () async {
                      final ok = await ctrl.generateActivationCode();
                      if (ok) _showCodeShareSheet(ctrl);
                    },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'regenerate_code'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.brand,
                side: BorderSide(color: colors.brand),
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Center(
            child: TextButton(
              onPressed: ctrl.shareCodeViaWhatsApp,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF25D366),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4,
                  vertical: AppSpacing.s1,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'share_via_whatsapp'.tr,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF25D366),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCode(String raw) {
    // Splits a code into two halves for easier reading (e.g., "A7B3K9" -> "A7B 3K9")
    if (raw.length <= 4) return raw;
    final mid = raw.length ~/ 2;
    return '${raw.substring(0, mid)} ${raw.substring(mid)}';
  }

  static String _formatDurationLocal(Duration d) {
    if (d.inHours >= 1) {
      return 'duration_hours_minutes'.trParams({
        'hours': d.inHours.toString(),
        'minutes': (d.inMinutes % 60).toString(),
      });
    }
    return 'duration_minutes'.trParams({'minutes': d.inMinutes.toString()});
  }
}

/* Body when no code exists yet. */
class _ActivationEmptyBody extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ActivationEmptyBody({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isBusy = ctrl.activationStatus == StatusRequest.loading;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phonelink_lock_outlined,
                size: 28, color: colors.brand),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            'no_activation_code_simple'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            'activation_code_valid_for'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              color: colors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isBusy
                  ? null
                  : () async {
                      final ok = await ctrl.generateActivationCode();
                      if (ok) _showCodeShareSheet(ctrl);
                    },
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, size: 18),
              label: Text('create_new_code'.tr),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
    final ok = await ctrl.generateActivationCode();
    if (ok) {
      // The confirmation dialog is still animating out at this point. On a fast
      // (local) server the generate request finishes before that close
      // animation does, so opening the bottom sheet here makes GetX drop it
      // (the sheet silently fails to appear). GetX's default dialog close
      // transition is 300ms, so wait a touch longer to be sure the dialog
      // route is gone before showing the share sheet.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      _showCodeShareSheet(ctrl);
    }
  }
}

/// Shows the freshly generated activation code with its QR and one-tap sharing
/// actions, so the admin knows exactly how to hand it to the employee. Reuses
/// the controller's copy / WhatsApp helpers. Safe to call from any trigger
/// (reset, regenerate, or first-time create).
void _showCodeShareSheet(EmployeeDetailController ctrl) {
  final code = ctrl.activationCode;
  if (code == null || code.isEmpty) return;
  final joinLink = ctrl.activationJoinLink;
  final phone = ctrl.employee?.phone;

  Get.bottomSheet<void>(
    Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s5, AppSpacing.s3, AppSpacing.s5, AppSpacing.s5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderHairline,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Icon(Icons.check_circle_outline,
                        size: 32, color: colors.success),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text('code_regenerated'.tr, style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'share_code_with_employee'.tr,
                    style: AppTextStyles.sm(context),
                    textAlign: TextAlign.center,
                  ),
                  // Login phone
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s5),
                    Text('login_phone'.tr,
                        style: AppTextStyles.bodySecondary(context)),
                    const SizedBox(height: AppSpacing.s2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s5,
                        vertical: AppSpacing.s3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.sunken,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_iphone, size: 18, color: colors.brand),
                          const SizedBox(width: AppSpacing.s2),
                          Text(
                            phone,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s5),
                  // Activation code
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4, vertical: AppSpacing.s4),
                    decoration: BoxDecoration(
                      color: colors.brandSubtle,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: colors.brand, width: 2),
                    ),
                    child: SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: colors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Text(
                    'single_use_hint'.tr,
                    style: AppTextStyles.sm(context),
                    textAlign: TextAlign.center,
                  ),
                  // QR for the join link (same single-use token as the code)
                  if (joinLink != null && joinLink.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s5),
                    Text('join_qr'.tr,
                        style: AppTextStyles.bodySecondary(context)),
                    const SizedBox(height: AppSpacing.s3),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: QrImageView(
                        data: joinLink,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s5),
                  Wrap(
                    spacing: AppSpacing.s3,
                    runSpacing: AppSpacing.s3,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: ctrl.copyCodeToClipboard,
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text('copy_code'.tr),
                      ),
                      if (joinLink != null && joinLink.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: ctrl.copyJoinLinkToClipboard,
                          icon: const Icon(Icons.link, size: 18),
                          label: Text('copy_link'.tr),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: ctrl.shareCodeViaWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: Text('share_via_whatsapp'.tr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  TextButton(
                    onPressed: () => Get.back<void>(),
                    child: Text('done'.tr),
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

/* ─────────────────────────────────────────────────────────────────────── */
/*  LEAVE BALANCE CARD                                                      */
/* ─────────────────────────────────────────────────────────────────────── */

class _LeaveBalanceCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _LeaveBalanceCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final used = ctrl.leaveUsed;
    final remaining = ctrl.leaveRemaining;
    final total = ctrl.leaveTotal;
    final progress = total > 0 ? used / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.beach_access_outlined,
                  size: 18, color: colors.brand),
              const SizedBox(width: AppSpacing.s2),
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
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Expanded(
                child: _LeaveStatCol(
                  value: '$used',
                  label: 'leave_used'.tr,
                  color: colors.error,
                ),
              ),
              Expanded(
                child: _LeaveStatCol(
                  value: '$remaining',
                  label: 'leave_remaining'.tr,
                  color: colors.success,
                ),
              ),
              Expanded(
                child: _LeaveStatCol(
                  value: '$total',
                  label: 'leave_total_annual'.tr,
                  color: colors.textPrimary,
                ),
              ),
            ],
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
        ],
      ),
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

class _LeaveStatCol extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _LeaveStatCol({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.s1),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 11,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────────────────────────────────────────────────────── */
/*  INFO CARD (Phone / Branch / Bank / Compliance / Categories)             */
/* ─────────────────────────────────────────────────────────────────────── */

String _formatShiftRange(String? start, String? end) {
  String trim(String? t) {
    if (t == null || t.isEmpty) return '—';
    final parts = t.split(':');
    if (parts.length < 2) return t;
    return '${parts[0]}:${parts[1]}';
  }

  return '${trim(start)} - ${trim(end)}';
}

class _InfoCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _InfoCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final e = ctrl.employee;
    if (e == null) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final hasBank = (e.bankName ?? '').isNotEmpty ||
        (e.bankAccountNumber ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colors.brand),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text('profile_overview'.tr,
                    style: AppTextStyles.h3(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (ctrl.canManageEmployees)
                IconButton(
                  onPressed: () => _showEditInfoSheet(context, ctrl),
                  icon: Icon(Icons.edit_outlined,
                      size: 18, color: colors.brand),
                  tooltip: 'edit_basic_info'.tr,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          if ((e.jobTitle ?? '').isNotEmpty)
            _InfoRow(label: 'job_title'.tr, value: e.jobTitle!),
          if ((e.employeeCode ?? '').isNotEmpty)
            _InfoRow(label: 'employee_code'.tr, value: e.employeeCode!),
          _InfoRow(label: 'phone_number'.tr, value: e.phone ?? '—'),
          _InfoRow(label: 'branch'.tr, value: e.branchName ?? '—'),
          if (ctrl.categories.isNotEmpty)
            _InfoRow(
              label: 'category'.tr,
              value: ctrl.categories
                  .map((c) => (c['name'] as String?) ?? '')
                  .where((n) => n.isNotEmpty)
                  .join('، '),
            ),
          _InfoRow(
            label: 'work_time'.tr,
            value: () {
              final range = _formatShiftRange(
                e.shiftStart ?? e.workStartTime,
                e.shiftEnd ?? e.workEndTime,
              );
              final name = e.shiftName;
              return (name != null && name.isNotEmpty)
                  ? '$range ($name)'
                  : range;
            }(),
          ),
          if (e.weeklyOffDays.isNotEmpty)
            _InfoRow(
              label: 'weekly_day_off'.tr,
              value: const [
                'saturday',
                'sunday',
                'monday',
                'tuesday',
                'wednesday',
                'thursday',
                'friday',
              ]
                  .where((d) => e.weeklyOffDays.contains(d))
                  .map((d) => 'day_$d'.tr)
                  .join('، '),
            ),
          _InfoRow(
            label: 'base_salary'.tr,
            value:
                '${e.baseSalary.toStringAsFixed(e.baseSalary == e.baseSalary.roundToDouble() ? 0 : 2)} ${'currency_egp'.tr}',
          ),
          _InfoRow(
            label: 'hire_date'.tr,
            value: e.hireDate != null
                ? '${e.hireDate!.year}-${e.hireDate!.month.toString().padLeft(2, '0')}-${e.hireDate!.day.toString().padLeft(2, '0')}'
                : '—',
          ),
          if (e.autoTerminateAt != null)
            _ComplianceRow(
                label: 'employment_ends_on'.tr, expiry: e.autoTerminateAt),
          if (hasBank) ...[
            const SizedBox(height: AppSpacing.s3),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s3),
            Text('bank_info'.tr,
                style: AppTextStyles.h3(context).copyWith(fontSize: 15)),
            const SizedBox(height: AppSpacing.s2),
            _InfoRow(label: 'bank_name'.tr, value: e.bankName ?? '—'),
            _InfoRow(
                label: 'bank_account_number'.tr,
                value: e.bankAccountNumber ?? '—'),
            _InfoRow(label: 'bank_iban'.tr, value: e.bankIban ?? '—'),
            if ((e.bankSwift ?? '').isNotEmpty)
              _InfoRow(label: 'bank_swift'.tr, value: e.bankSwift!),
          ],
          if (e.hasComplianceInfo) ...[
            const SizedBox(height: AppSpacing.s3),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s3),
            Text('compliance_info'.tr,
                style: AppTextStyles.h3(context).copyWith(fontSize: 15)),
            const SizedBox(height: AppSpacing.s2),
            if ((e.nationalId ?? '').isNotEmpty)
              _InfoRow(label: 'national_id'.tr, value: e.nationalId!),
            if ((e.nationality ?? '').isNotEmpty)
              _InfoRow(label: 'nationality'.tr, value: e.nationality!),
            if ((e.iqamaNumber ?? '').isNotEmpty || e.iqamaExpiry != null)
              _ComplianceRow(
                  label: 'iqama_number'.tr,
                  value: e.iqamaNumber,
                  expiry: e.iqamaExpiry),
            if ((e.passportNumber ?? '').isNotEmpty ||
                e.passportExpiry != null)
              _ComplianceRow(
                  label: 'passport_number'.tr,
                  value: e.passportNumber,
                  expiry: e.passportExpiry),
            if ((e.workPermitNumber ?? '').isNotEmpty ||
                e.workPermitExpiry != null)
              _ComplianceRow(
                  label: 'work_permit_number'.tr,
                  value: e.workPermitNumber,
                  expiry: e.workPermitExpiry),
            if (e.contractType != null)
              _InfoRow(
                  label: 'contract_type'.tr,
                  value: 'contract_${e.contractType}'.tr),
            if (e.contractStart != null)
              _InfoRow(
                label: 'contract_start'.tr,
                value:
                    '${e.contractStart!.year}-${e.contractStart!.month.toString().padLeft(2, '0')}-${e.contractStart!.day.toString().padLeft(2, '0')}',
              ),
            if (e.contractEnd != null)
              _ComplianceRow(label: 'contract_end'.tr, expiry: e.contractEnd),
            if (e.healthInsuranceExpiry != null)
              _ComplianceRow(
                  label: 'health_insurance_expiry'.tr,
                  expiry: e.healthInsuranceExpiry),
          ],
        ],
      ),
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
                if ((value ?? '').isNotEmpty)
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
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
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

/* ─────────────────────────────────────────────────────────────────────── */
/*  EDIT INFO SHEET                                                         */
/* ─────────────────────────────────────────────────────────────────────── */

void _showEditInfoSheet(BuildContext context, EmployeeDetailController ctrl) {
  final e = ctrl.employee;
  if (e == null) return;

  final nameCtrl = TextEditingController(text: e.name);
  final phoneCtrl = TextEditingController(text: e.phone ?? '');
  final jobTitleCtrl = TextEditingController(text: e.jobTitle ?? '');
  final salaryCtrl = TextEditingController(
    text: e.baseSalary == 0
        ? ''
        : (e.baseSalary == e.baseSalary.roundToDouble()
            ? e.baseSalary.toInt().toString()
            : e.baseSalary.toString()),
  );
  final bankNameCtrl = TextEditingController(text: e.bankName ?? '');
  final bankAccountCtrl =
      TextEditingController(text: e.bankAccountNumber ?? '');
  final bankIbanCtrl = TextEditingController(text: e.bankIban ?? '');
  final bankSwiftCtrl = TextEditingController(text: e.bankSwift ?? '');
  final nationalIdCtrl = TextEditingController(text: e.nationalId ?? '');
  final nationalityCtrl = TextEditingController(text: e.nationality ?? '');
  final iqamaCtrl = TextEditingController(text: e.iqamaNumber ?? '');
  final passportCtrl = TextEditingController(text: e.passportNumber ?? '');
  final workPermitCtrl =
      TextEditingController(text: e.workPermitNumber ?? '');

  DateTime? hireDate = e.hireDate;
  DateTime? iqamaExpiry = e.iqamaExpiry;
  DateTime? passportExpiry = e.passportExpiry;
  DateTime? workPermitExpiry = e.workPermitExpiry;
  DateTime? contractEnd = e.contractEnd;
  DateTime? healthInsuranceExpiry = e.healthInsuranceExpiry;

  final formKey = GlobalKey<FormState>();

  String fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Get.bottomSheet<void>(
    StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final colors = AppColors.of(context);

        Future<void> pickDate(
            DateTime? current, void Function(DateTime?) setter) async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: sheetCtx,
            initialDate: current ?? now,
            firstDate: DateTime(1950),
            lastDate: DateTime(now.year + 30),
          );
          if (picked != null) setSheetState(() => setter(picked));
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtl) {
            return Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.borderHairline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'edit_basic_info'.tr,
                                style: AppTextStyles.h2(context),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Get.back<void>(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Form(
                      key: formKey,
                      child: ListView(
                        controller: scrollCtl,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4,
                          AppSpacing.s3,
                          AppSpacing.s4,
                          AppSpacing.s4,
                        ),
                        children: [
                          _SectionLabel(label: 'profile_overview'.tr),
                          _FormField(
                            controller: nameCtrl,
                            label: 'name'.tr,
                            icon: Icons.person_outline,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'required'.tr
                                : null,
                          ),
                          _FormField(
                            controller: phoneCtrl,
                            label: 'phone_number'.tr,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          _FormField(
                            controller: jobTitleCtrl,
                            label: 'job_title'.tr,
                            icon: Icons.work_outline,
                          ),
                          _FormField(
                            controller: salaryCtrl,
                            label: 'base_salary'.tr,
                            icon: Icons.payments_outlined,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                          ),
                          _DateField(
                            label: 'hire_date'.tr,
                            value: hireDate,
                            onTap: () =>
                                pickDate(hireDate, (v) => hireDate = v),
                            onClear: () =>
                                setSheetState(() => hireDate = null),
                          ),

                          const SizedBox(height: AppSpacing.s4),
                          _SectionLabel(label: 'bank_info'.tr),
                          _FormField(
                            controller: bankNameCtrl,
                            label: 'bank_name'.tr,
                            icon: Icons.account_balance_outlined,
                          ),
                          _FormField(
                            controller: bankAccountCtrl,
                            label: 'bank_account_number'.tr,
                            icon: Icons.numbers_outlined,
                          ),
                          _FormField(
                            controller: bankIbanCtrl,
                            label: 'bank_iban'.tr,
                            icon: Icons.qr_code_outlined,
                          ),
                          _FormField(
                            controller: bankSwiftCtrl,
                            label: 'bank_swift'.tr,
                            icon: Icons.swap_horiz_outlined,
                          ),

                          const SizedBox(height: AppSpacing.s4),
                          _SectionLabel(label: 'compliance_info'.tr),
                          _FormField(
                            controller: nationalIdCtrl,
                            label: 'national_id'.tr,
                            icon: Icons.badge_outlined,
                          ),
                          _FormField(
                            controller: nationalityCtrl,
                            label: 'nationality'.tr,
                            icon: Icons.public_outlined,
                          ),
                          _FormField(
                            controller: iqamaCtrl,
                            label: 'iqama_number'.tr,
                            icon: Icons.card_membership_outlined,
                          ),
                          _DateField(
                            label: 'iqama_expiry'.tr,
                            value: iqamaExpiry,
                            onTap: () => pickDate(
                                iqamaExpiry, (v) => iqamaExpiry = v),
                            onClear: () =>
                                setSheetState(() => iqamaExpiry = null),
                          ),
                          _FormField(
                            controller: passportCtrl,
                            label: 'passport_number'.tr,
                            icon: Icons.menu_book_outlined,
                          ),
                          _DateField(
                            label: 'passport_expiry'.tr,
                            value: passportExpiry,
                            onTap: () => pickDate(
                                passportExpiry, (v) => passportExpiry = v),
                            onClear: () => setSheetState(
                                () => passportExpiry = null),
                          ),
                          _FormField(
                            controller: workPermitCtrl,
                            label: 'work_permit_number'.tr,
                            icon: Icons.assignment_outlined,
                          ),
                          _DateField(
                            label: 'work_permit_expiry'.tr,
                            value: workPermitExpiry,
                            onTap: () => pickDate(workPermitExpiry,
                                (v) => workPermitExpiry = v),
                            onClear: () => setSheetState(
                                () => workPermitExpiry = null),
                          ),
                          _DateField(
                            label: 'contract_end'.tr,
                            value: contractEnd,
                            onTap: () => pickDate(
                                contractEnd, (v) => contractEnd = v),
                            onClear: () =>
                                setSheetState(() => contractEnd = null),
                          ),
                          _DateField(
                            label: 'health_insurance_expiry'.tr,
                            value: healthInsuranceExpiry,
                            onTap: () => pickDate(healthInsuranceExpiry,
                                (v) => healthInsuranceExpiry = v),
                            onClear: () => setSheetState(
                                () => healthInsuranceExpiry = null),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final changes = <String, dynamic>{};

                            void putIfChanged(
                                String key, String newVal, String? oldVal) {
                              final n = newVal.trim();
                              final o = (oldVal ?? '').trim();
                              if (n != o) changes[key] = n;
                            }

                            void putDateIfChanged(String key,
                                DateTime? newVal, DateTime? oldVal) {
                              final n = fmtDate(newVal);
                              final o = fmtDate(oldVal);
                              if (n != o) changes[key] = n;
                            }

                            putIfChanged('name', nameCtrl.text, e.name);
                            putIfChanged('phone', phoneCtrl.text, e.phone);
                            putIfChanged(
                                'job_title', jobTitleCtrl.text, e.jobTitle);
                            final newSalary =
                                num.tryParse(salaryCtrl.text.trim());
                            if (newSalary != null &&
                                newSalary != e.baseSalary) {
                              changes['base_salary'] = newSalary;
                            }
                            putDateIfChanged(
                                'hire_date', hireDate, e.hireDate);

                            putIfChanged(
                                'bank_name', bankNameCtrl.text, e.bankName);
                            putIfChanged('bank_account_number',
                                bankAccountCtrl.text, e.bankAccountNumber);
                            putIfChanged(
                                'bank_iban', bankIbanCtrl.text, e.bankIban);
                            putIfChanged('bank_swift', bankSwiftCtrl.text,
                                e.bankSwift);

                            putIfChanged('national_id',
                                nationalIdCtrl.text, e.nationalId);
                            putIfChanged('nationality',
                                nationalityCtrl.text, e.nationality);
                            putIfChanged('iqama_number', iqamaCtrl.text,
                                e.iqamaNumber);
                            putDateIfChanged('iqama_expiry', iqamaExpiry,
                                e.iqamaExpiry);
                            putIfChanged('passport_number',
                                passportCtrl.text, e.passportNumber);
                            putDateIfChanged('passport_expiry',
                                passportExpiry, e.passportExpiry);
                            putIfChanged('work_permit_number',
                                workPermitCtrl.text, e.workPermitNumber);
                            putDateIfChanged('work_permit_expiry',
                                workPermitExpiry, e.workPermitExpiry);
                            putDateIfChanged('contract_end', contractEnd,
                                e.contractEnd);
                            putDateIfChanged(
                                'health_insurance_expiry',
                                healthInsuranceExpiry,
                                e.healthInsuranceExpiry);

                            Get.back<void>();
                            await ctrl.updateEmployeeInfo(changes);
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s2),
                            child: Text('save'.tr),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
    isScrollControlled: true,
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.brand,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3,
            vertical: AppSpacing.s3,
          ),
        ),
        style: const TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 14,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasValue = value != null;
    final text = hasValue
        ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
        : 'no_value_placeholder'.tr;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            suffixIcon: hasValue
                ? IconButton(
                    onPressed: onClear,
                    icon: Icon(Icons.clear,
                        size: 18, color: colors.textTertiary),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s3,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              color: hasValue ? colors.textPrimary : colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────────────────── */
/*  ATTENDANCE TAB                                                          */
/* ─────────────────────────────────────────────────────────────────────── */

class _AttendanceTab extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _AttendanceTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    // The calendar grid renders the active window (a calendar month or a custom
    // cycle like 25→24). For long custom ranges we hide it and keep the list.
    final span = ctrl.periodTo.difference(ctrl.periodFrom).inDays;
    final showCalendar = span >= 0 && span <= 31;

    return RefreshIndicator(
      onRefresh: ctrl.loadAttendanceMonth,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          _AttendancePeriodSelector(ctrl: ctrl),
          const SizedBox(height: AppSpacing.s4),
          _AttendanceSummaryCard(ctrl: ctrl),
          const SizedBox(height: AppSpacing.s4),
          if (showCalendar) ...[
            _AttendanceCalendarCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s4),
          ],
          _AttendanceListCard(ctrl: ctrl),
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

/* ─────────────────────────────────────────────────────────────────────── */
/*  ATTENDANCE PERIOD SELECTOR                                              */
/* ─────────────────────────────────────────────────────────────────────── */

enum _AttendancePreset { thisMonth, lastMonth, last7Days, last30Days, custom }

class _AttendancePeriodSelector extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _AttendancePeriodSelector({required this.ctrl});

  _AttendancePreset _detectPreset() {
    final now = DateTime.now();
    if (!ctrl.attendanceIsRange) {
      // Cycle mode: which cycle (by its label/end month) is anchored?
      final current = ctrl.currentCycleLabelMonth();
      if (ctrl.attendanceMonth.year == current.year &&
          ctrl.attendanceMonth.month == current.month) {
        return _AttendancePreset.thisMonth;
      }
      final last = DateTime(current.year, current.month - 1);
      if (ctrl.attendanceMonth.year == last.year &&
          ctrl.attendanceMonth.month == last.month) {
        return _AttendancePreset.lastMonth;
      }
      return _AttendancePreset.custom;
    }
    final from = ctrl.attendanceFrom!;
    final to = ctrl.attendanceTo!;
    final today = DateTime(now.year, now.month, now.day);
    final daySpan = to.difference(from).inDays + 1;
    if (_sameDay(to, today)) {
      if (daySpan == 7) return _AttendancePreset.last7Days;
      if (daySpan == 30) return _AttendancePreset.last30Days;
    }
    return _AttendancePreset.custom;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _apply(_AttendancePreset preset, BuildContext context) {
    final now = DateTime.now();
    final currentCycle = ctrl.currentCycleLabelMonth();
    switch (preset) {
      case _AttendancePreset.thisMonth:
        ctrl.changeAttendanceMonth(currentCycle);
        break;
      case _AttendancePreset.lastMonth:
        ctrl.changeAttendanceMonth(
            DateTime(currentCycle.year, currentCycle.month - 1));
        break;
      case _AttendancePreset.last7Days:
        ctrl.changeAttendanceRange(
          now.subtract(const Duration(days: 6)),
          now,
        );
        break;
      case _AttendancePreset.last30Days:
        ctrl.changeAttendanceRange(
          now.subtract(const Duration(days: 29)),
          now,
        );
        break;
      case _AttendancePreset.custom:
        _openRangePicker(context);
        break;
    }
  }

  Future<void> _openRangePicker(BuildContext context) async {
    final now = DateTime.now();
    final initial =
        DateTimeRange(start: ctrl.periodFrom, end: ctrl.periodTo);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'select_date_range'.tr,
      saveText: 'apply'.tr,
      cancelText: 'cancel'.tr,
    );
    if (picked != null) {
      ctrl.changeAttendanceRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = _detectPreset();

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final rangeStart = ctrl.periodFrom;
    final rangeEnd = ctrl.periodTo;
    final dayCount = rangeEnd.difference(rangeStart).inDays + 1;

    final presets = <(_AttendancePreset, String, IconData)>[
      (_AttendancePreset.thisMonth, 'preset_this_month'.tr,
          Icons.today_outlined),
      (_AttendancePreset.lastMonth, 'preset_last_month'.tr,
          Icons.event_note_outlined),
      (_AttendancePreset.last7Days, 'preset_last_7_days'.tr,
          Icons.date_range_outlined),
      (_AttendancePreset.last30Days, 'preset_last_30_days'.tr,
          Icons.calendar_view_month_outlined),
      (_AttendancePreset.custom, 'preset_custom'.tr,
          Icons.tune_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.map((p) {
                final isActive = active == p.$1;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.s2),
                  child: InkWell(
                    onTap: () => _apply(p.$1, context),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s3, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colors.brand
                            : colors.sunken.withValues(alpha: 0.5),
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: isActive
                              ? colors.brand
                              : colors.borderHairline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            p.$3,
                            size: 14,
                            color: isActive
                                ? Colors.white
                                : colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            p.$2,
                            style: TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          InkWell(
            onTap: () => _openRangePicker(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
              decoration: BoxDecoration(
                color: colors.brandSubtle,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: colors.brand.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 16, color: colors.brand),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      '${fmt(rangeStart)}  ←  ${fmt(rangeEnd)}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s2, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      'days_count'
                          .trParams({'count': dayCount.toString()}),
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final void Function(DateTime) onChange;
  /// Inclusive cycle window for the picked month. When provided (and the
  /// company uses a non-calendar cycle), it's shown as a subtitle so the
  /// user can see, e.g., that "May" actually means May 12 → June 11.
  final DateTime? cycleFrom;
  final DateTime? cycleTo;
  /// Most-recent label month the picker is allowed to land on. The "next"
  /// arrow becomes disabled once `month` reaches this. Defaults to the
  /// current calendar month for callers that aren't cycle-aware.
  final DateTime? maxMonth;
  /// Oldest label month the picker is allowed to land on. The "previous"
  /// arrow becomes disabled once `month` reaches this. Null = uncapped.
  final DateTime? minMonth;
  const _MonthSwitcher({
    required this.month,
    required this.onChange,
    this.cycleFrom,
    this.cycleTo,
    this.maxMonth,
    this.minMonth,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final label = '${'month_${month.month}'.tr} ${month.year}';
    final showRange = cycleFrom != null &&
        cycleTo != null &&
        (cycleFrom!.month != month.month || cycleTo!.month != month.month);
    final now = DateTime.now();
    final cap = maxMonth ?? DateTime(now.year, now.month);
    final canGoNext = month.isBefore(cap);
    final canGoPrev = minMonth == null || month.isAfter(minMonth!);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'previous_month'.tr,
            onPressed: canGoPrev
                ? () => onChange(DateTime(month.year, month.month - 1))
                : null,
            icon: Icon(
              Icons.chevron_right,
              color: canGoPrev ? colors.textSecondary : colors.textTertiary,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () async {
                final picked = await showMonthGridPicker(
                  context,
                  selected: month,
                  min: minMonth,
                  max: cap,
                );
                if (picked != null) onChange(picked);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showRange) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_dayMonth(cycleFrom!)} → ${_dayMonth(cycleTo!)}',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'next_month'.tr,
            onPressed: canGoNext
                ? () => onChange(DateTime(month.year, month.month + 1))
                : null,
            icon: Icon(
              Icons.chevron_left,
              color: canGoNext ? colors.textSecondary : colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  static String _dayMonth(DateTime d) =>
      '${d.day} ${'month_${d.month}'.tr}';
}

class _AttendanceSummaryCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _AttendanceSummaryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = ctrl.attendanceSummary;
    final overtime = s['overtime_minutes'] ?? 0;
    final late = s['late_minutes'] ?? 0;
    final e = ctrl.employee;
    final shiftRange = e == null
        ? null
        : _formatShiftRange(
            e.shiftStart ?? e.workStartTime,
            e.shiftEnd ?? e.workEndTime,
          );
    final shiftLabel = (e?.shiftName != null && e!.shiftName!.isNotEmpty)
        ? '$shiftRange (${e.shiftName})'
        : shiftRange;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('attendance_summary'.tr, style: AppTextStyles.h3(context)),
          if (shiftLabel != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: colors.brand),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    '${'work_time'.tr}: $shiftLabel',
                    style: AppTextStyles.sm(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  count: '${s['present'] ?? 0}',
                  label: 'attendance_present_short'.tr,
                  color: colors.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: _SummaryChip(
                  count: '${s['late'] ?? 0}',
                  label: 'attendance_late_short'.tr,
                  color: colors.warning,
                  icon: Icons.schedule,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: _SummaryChip(
                  count: '${s['absent'] ?? 0}',
                  label: 'attendance_absent_short'.tr,
                  color: colors.error,
                  icon: Icons.cancel_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: _SummaryChip(
                  // Holiday & weekly-off are counted within "leave".
                  count:
                      '${(s['leave'] ?? 0) + (s['holiday'] ?? 0) + (s['weekly_off'] ?? 0)}',
                  label: 'attendance_leave_short'.tr,
                  color: colors.accentWarm,
                  icon: Icons.beach_access_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Icon(Icons.trending_up,
                  size: 14, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Text(
                '${'total_overtime'.tr}: ${_fmtMinutes(overtime)}',
                style: AppTextStyles.sm(context),
              ),
              const SizedBox(width: AppSpacing.s4),
              Icon(Icons.history, size: 14, color: colors.textSecondary),
              const SizedBox(width: AppSpacing.s2),
              Text(
                '${'total_late_minutes'.tr}: ${_fmtMinutes(late)}',
                style: AppTextStyles.sm(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtMinutes(int minutes) {
    if (minutes <= 0) return '0';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '$m ${'minutes_short'.tr}';
    return '$h ${'hours_short'.tr} $m ${'minutes_short'.tr}';
  }
}

class _SummaryChip extends StatelessWidget {
  final String count;
  final String label;
  final Color color;
  final IconData icon;
  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s2, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCalendarCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _AttendanceCalendarCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Render the active window (calendar month or custom cycle like 25→24).
    final from = ctrl.periodFrom;
    final to = ctrl.periodTo;

    // Map records by full date string (the window can span two months).
    final byDate = <String, AttendanceRecordModel>{};
    for (final r in ctrl.attendanceRecords) {
      if (r.date != null) byDate[r.date!] = r;
    }

    _DayKind kindOf(AttendanceRecordModel? r) {
      if (r == null) return _DayKind.none;
      switch (r.status) {
        case 'present':
          return (r.lateMinutes ?? 0) > 0 ? _DayKind.late : _DayKind.present;
        case 'absent':
          return _DayKind.absent;
        case 'leave':
        case 'holiday':
        case 'weekly_off':
          return _DayKind.leave;
        default:
          return _DayKind.none;
      }
    }

    final canEdit = ctrl.canManageAttendance;
    String dateStr(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Weekday columns: start week on Saturday (Arabic standard).
    // Convert to "Saturday-first" index (0=Sat,1=Sun,...,6=Fri).
    final satFirstOffset = (from.weekday + 1) % 7;

    final cells = <Widget>[];
    // Saturday-first single-letter day labels (Sat, Sun, Mon, Tue, Wed, Thu, Fri).
    final dayLabels = Get.locale?.languageCode == 'ar'
        ? ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']
        : ['S', 'S', 'M', 'T', 'W', 'T', 'F'];
    for (final l in dayLabels) {
      cells.add(Center(
        child: Text(
          l,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 11,
            color: colors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
    }
    for (int i = 0; i < satFirstOffset; i++) {
      cells.add(const SizedBox());
    }
    final totalDays = to.difference(from).inDays;
    for (int i = 0; i <= totalDays; i++) {
      final d = DateTime(from.year, from.month, from.day + i);
      final ds = dateStr(d);
      final rec = byDate[ds];
      final future = _isFutureDay(d);
      cells.add(_CalendarCell(
        day: d.day,
        kind: kindOf(rec),
        dimmed: future,
        // Future days can't be edited (you can't mark attendance ahead of time).
        onTap: (canEdit && !future)
            ? () => _showDayEditorSheet(context, ctrl,
                record: rec, date: ds)
            : null,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('attendance_calendar'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s3),
          if (ctrl.attendanceStatus == StatusRequest.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s5),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: cells,
            ),
          const SizedBox(height: AppSpacing.s3),
          Wrap(
            spacing: AppSpacing.s3,
            runSpacing: AppSpacing.s2,
            children: [
              _LegendDot(
                  color: colors.success,
                  label: 'attendance_present_short'.tr),
              _LegendDot(
                  color: colors.warning,
                  label: 'attendance_late_short'.tr),
              _LegendDot(
                  color: colors.error,
                  label: 'attendance_absent_short'.tr),
              _LegendDot(
                  color: colors.accentWarm,
                  label: 'attendance_leave_short'.tr),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DayKind { none, present, late, absent, leave }

class _CalendarCell extends StatelessWidget {
  final int day;
  final _DayKind kind;
  final VoidCallback? onTap;
  final bool dimmed;
  const _CalendarCell(
      {required this.day,
      required this.kind,
      this.onTap,
      this.dimmed = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Color? bg;
    Color text = colors.textSecondary;
    switch (kind) {
      case _DayKind.present:
        bg = colors.success.withValues(alpha: 0.18);
        text = colors.success;
        break;
      case _DayKind.late:
        bg = colors.warning.withValues(alpha: 0.18);
        text = colors.warning;
        break;
      case _DayKind.absent:
        bg = colors.error.withValues(alpha: 0.18);
        text = colors.error;
        break;
      case _DayKind.leave:
        bg = colors.accentWarm.withValues(alpha: 0.18);
        text = colors.accentWarm;
        break;
      case _DayKind.none:
        break;
    }
    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: bg ?? colors.sunken.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: text,
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Text(label, style: AppTextStyles.xs(context)),
      ],
    );
  }
}

class _AttendanceListCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _AttendanceListCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final records = ctrl.attendanceRecords;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('attendance_records'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s3),
          if (ctrl.attendanceStatus == StatusRequest.loading)
            const Center(child: CircularProgressIndicator.adaptive())
          else if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s5),
              child: Center(
                child: Text('attendance_no_records_for_month'.tr,
                    style: AppTextStyles.bodySecondary(context)),
              ),
            )
          else
            ...records.map((r) => _AttendanceRow(ctrl: ctrl, record: r)),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final EmployeeDetailController ctrl;
  final AttendanceRecordModel record;
  const _AttendanceRow({required this.ctrl, required this.record});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // A present day with late minutes is shown as "late" (matches the calendar).
    final isLate =
        record.status == 'present' && (record.lateMinutes ?? 0) > 0;
    // Holiday & weekly-off are shown under the "leave" umbrella.
    final isLeaveKind =
        const ['leave', 'holiday', 'weekly_off'].contains(record.status);
    final statusColor =
        _attendanceStatusColor(isLate ? 'late' : record.status, colors);
    final statusText = isLate
        ? 'status_late'.tr
        : (isLeaveKind ? 'status_leave'.tr : record.statusLabel);
    final displayDate = record.date ??
        (record.checkIn != null
            ? '${record.checkIn!.year}-${record.checkIn!.month.toString().padLeft(2, '0')}-${record.checkIn!.day.toString().padLeft(2, '0')}'
            : '');

    final recDate =
        record.date != null ? DateTime.tryParse(record.date!) : null;
    final canEdit = ctrl.canManageAttendance &&
        record.date != null &&
        !_isFutureDay(recDate);

    // Secondary details to surface what was entered (leave type / custom
    // deduction / note) without reopening the editor.
    final extra = <String>[];
    if (record.status == 'holiday') {
      extra.add('status_holiday'.tr);
    } else if (record.status == 'weekly_off') {
      extra.add('status_weekly_off'.tr);
    } else if (record.status == 'leave' &&
        (record.leaveType ?? '').isNotEmpty) {
      extra.add(_leaveTypeLabel(record.leaveType!));
    }
    if (record.status == 'absent' &&
        record.deductionMode != 'auto' &&
        record.deductionValue != null) {
      final v = _fmtDeductionValue(record.deductionValue!);
      extra.add(record.deductionMode == 'days'
          ? '${'deduction_label'.tr}: $v ${'days_unit'.tr}'
          : '${'deduction_label'.tr}: $v ${'currency_egp'.tr}');
    }
    if ((record.note ?? '').isNotEmpty) extra.add(record.note!);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canEdit
              ? () => _showDayEditorSheet(context, ctrl,
                  record: record, date: record.date!)
              : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (record.checkIn != null) ...[
                            Icon(Icons.login,
                                size: 12, color: colors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(record.checkIn!),
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if (record.checkOut != null) ...[
                            const SizedBox(width: AppSpacing.s2),
                            Icon(Icons.logout,
                                size: 12, color: colors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(record.checkOut!),
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          if (record.checkIn == null &&
                              record.checkOut == null)
                            Text(
                              '—',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      if (extra.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          extra.join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: AppSpacing.s2),
                  Icon(Icons.edit_outlined,
                      size: 16, color: colors.textTertiary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Color _attendanceStatusColor(String status, AppColorScheme colors) {
  switch (status) {
    case 'present':
      return colors.success;
    case 'absent':
      return colors.error;
    case 'late':
      return colors.warning;
    case 'leave':
    case 'holiday':
    case 'weekly_off':
      return colors.accentWarm;
    default:
      return colors.textTertiary;
  }
}

/// True when [d] is strictly after today (date-only comparison).
bool _isFutureDay(DateTime? d) {
  if (d == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(d.year, d.month, d.day).isAfter(today);
}

String _leaveTypeLabel(String type) {
  switch (type) {
    case 'annual':
      return 'leave_type_annual'.tr;
    case 'sick':
      return 'leave_type_sick'.tr;
    case 'unpaid':
      return 'leave_type_unpaid'.tr;
    case 'holiday':
      return 'status_holiday'.tr;
    case 'weekly_off':
      return 'status_weekly_off'.tr;
    default:
      return type;
  }
}

String _fmtDeductionValue(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/* ─────────────────────────────────────────────────────────────────────── */
/*  UNIFIED DAY EDITOR SHEET                                                */
/*  One sheet to set any day to present / absent / leave, creating the     */
/*  attendance record when it doesn't exist yet.                           */
/* ─────────────────────────────────────────────────────────────────────── */

void _showDayEditorSheet(
  BuildContext context,
  EmployeeDetailController ctrl, {
  AttendanceRecordModel? record,
  required String date,
}) {
  // ── Working state (seeded from the existing record, if any) ──
  // Holiday & weekly-off are presented as kinds of "leave", so they map to the
  // 'leave' status chip and a leave-type selection.
  String status = (record?.status == 'absent')
      ? 'absent'
      : (const ['leave', 'holiday', 'weekly_off'].contains(record?.status)
          ? 'leave'
          : 'present');

  TimeOfDay? checkIn = record?.checkIn != null
      ? TimeOfDay(hour: record!.checkIn!.hour, minute: record.checkIn!.minute)
      : null;
  TimeOfDay? checkOut = record?.checkOut != null
      ? TimeOfDay(
          hour: record!.checkOut!.hour, minute: record.checkOut!.minute)
      : null;
  // The chosen leave "kind": annual/sick/unpaid (real leaves) or
  // holiday/weekly_off (non-working day statuses).
  String leaveType = (record?.status == 'holiday')
      ? 'holiday'
      : (record?.status == 'weekly_off')
          ? 'weekly_off'
          : (const ['annual', 'sick', 'unpaid'].contains(record?.leaveType)
              ? record!.leaveType!
              : 'annual');
  final reasonCtrl = TextEditingController(text: record?.note ?? '');

  // Absence deduction override: auto = company rule, days = N × daily rate,
  // amount = fixed money.
  String deductionMode = const ['auto', 'days', 'amount']
          .contains(record?.deductionMode)
      ? record!.deductionMode
      : 'auto';
  final deductionValueCtrl = TextEditingController(
    text: (record?.deductionValue != null && record!.deductionValue! > 0)
        ? (record.deductionValue! == record.deductionValue!.roundToDouble()
            ? record.deductionValue!.toInt().toString()
            : record.deductionValue!.toString())
        : '',
  );

  final parsed = DateTime.tryParse(date);
  final weekdayText = parsed != null ? _weekdayLabel(parsed) : '';
  String? validationError;

  String fmt(TimeOfDay? t) => t == null
      ? 'not_set'.tr
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String toApiTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  const leaveTypes = <_LeaveTypeOption>[
    _LeaveTypeOption(
      id: 'annual',
      labelKey: 'leave_type_annual',
      descKey: 'leave_type_annual_desc',
      icon: Icons.beach_access_outlined,
    ),
    _LeaveTypeOption(
      id: 'sick',
      labelKey: 'leave_type_sick',
      descKey: 'leave_type_sick_desc',
      icon: Icons.medical_services_outlined,
    ),
    _LeaveTypeOption(
      id: 'unpaid',
      labelKey: 'leave_type_unpaid',
      descKey: 'leave_type_unpaid_desc',
      icon: Icons.money_off_csred_outlined,
    ),
    _LeaveTypeOption(
      id: 'holiday',
      labelKey: 'status_holiday',
      descKey: 'leave_type_holiday_desc',
      icon: Icons.celebration_outlined,
    ),
    _LeaveTypeOption(
      id: 'weekly_off',
      labelKey: 'status_weekly_off',
      descKey: 'leave_type_weekly_off_desc',
      icon: Icons.weekend_outlined,
    ),
  ];

  final statusOptions = <(String, String, IconData)>[
    ('present', 'status_present', Icons.check_circle_outline),
    ('absent', 'status_absent', Icons.cancel_outlined),
    ('leave', 'status_leave', Icons.beach_access_outlined),
  ];

  Get.bottomSheet<void>(
    StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final colors = AppColors.of(context);
        final isLoading = ctrl.conversionStatus == StatusRequest.loading;

        Color statusColor(String s) => s == 'present'
            ? colors.success
            : (s == 'absent' ? colors.error : colors.accentWarm);

        Future<void> pickTime(
            TimeOfDay? current, void Function(TimeOfDay) onSet) async {
          final picked = await showTimePicker(
            context: sheetCtx,
            initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
          );
          if (picked != null) {
            setSheetState(() {
              onSet(picked);
              validationError = null;
            });
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(
                        top: AppSpacing.s3, bottom: AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: colors.borderHairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s2),
                        decoration: BoxDecoration(
                          color: colors.brandSubtle,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(Icons.edit_calendar_outlined,
                            size: 20, color: colors.brand),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('day_editor_title'.tr,
                                style: AppTextStyles.h2(context)
                                    .copyWith(fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(
                              weekdayText.isEmpty
                                  ? date
                                  : '$weekdayText · $date',
                              style: AppTextStyles.sm(context),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Get.back<void>(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s4),

                // Status selector (segmented)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                  child: Text(
                    'select_status'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                  child: Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: statusOptions.map((o) {
                      final selected = status == o.$1;
                      final c = statusColor(o.$1);
                      return InkWell(
                        onTap: () => setSheetState(() {
                          status = o.$1;
                          validationError = null;
                        }),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
                          decoration: BoxDecoration(
                            color: selected
                                ? c.withValues(alpha: 0.12)
                                : colors.sunken.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: selected ? c : colors.borderHairline,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(o.$3,
                                  size: 16,
                                  color:
                                      selected ? c : colors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                o.$2.tr,
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? c : colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: AppSpacing.s4),

                // Contextual fields
                if (status == 'present')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TimePickerTile(
                            label: 'check_in_time_label'.tr,
                            icon: Icons.login,
                            time: checkIn,
                            color: colors.success,
                            onTap: () => pickTime(checkIn, (v) {
                              checkIn = v;
                            }),
                            onClear: checkIn == null
                                ? null
                                : () => setSheetState(() => checkIn = null),
                            formattedTime: fmt(checkIn),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: _TimePickerTile(
                            label: 'check_out_time_label'.tr,
                            icon: Icons.logout,
                            time: checkOut,
                            color: colors.brand,
                            onTap: () => pickTime(checkOut, (v) {
                              checkOut = v;
                            }),
                            onClear: checkOut == null
                                ? null
                                : () => setSheetState(() => checkOut = null),
                            formattedTime: fmt(checkOut),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (status == 'leave')
                  ...leaveTypes.map((opt) {
                    final sel = leaveType == opt.id;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s2),
                      child: InkWell(
                        onTap: () => setSheetState(() => leaveType = opt.id),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          decoration: BoxDecoration(
                            color:
                                sel ? colors.brandSubtle : colors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color:
                                  sel ? colors.brand : colors.borderHairline,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: sel ? colors.brand : colors.sunken,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(opt.icon,
                                    size: 18,
                                    color: sel
                                        ? Colors.white
                                        : colors.textSecondary),
                              ),
                              const SizedBox(width: AppSpacing.s3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      opt.labelKey.tr,
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? colors.brand
                                            : colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt.descKey.tr,
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Sans Arabic',
                                        fontSize: 12,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                sel
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color:
                                    sel ? colors.brand : colors.borderHairline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                // Absence deduction override
                if (status == 'absent') ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4),
                    child: Text(
                      'deduction_label'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  ...<(String, String, IconData)>[
                    ('auto', 'deduction_company_default',
                        Icons.business_outlined),
                    ('days', 'deduction_by_days',
                        Icons.calendar_month_outlined),
                    ('amount', 'deduction_direct_amount',
                        Icons.payments_outlined),
                  ].map((o) {
                    final sel = deductionMode == o.$1;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s2),
                      child: InkWell(
                        onTap: () => setSheetState(() {
                          deductionMode = o.$1;
                          validationError = null;
                        }),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          decoration: BoxDecoration(
                            color:
                                sel ? colors.brandSubtle : colors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: sel
                                  ? colors.brand
                                  : colors.borderHairline,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(o.$3,
                                  size: 20,
                                  color: sel
                                      ? colors.brand
                                      : colors.textSecondary),
                              const SizedBox(width: AppSpacing.s3),
                              Expanded(
                                child: Text(
                                  o.$2.tr,
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? colors.brand
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                sel
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: sel
                                    ? colors.brand
                                    : colors.borderHairline,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (deductionMode != 'auto')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s4, AppSpacing.s1, AppSpacing.s4, 0),
                      child: TextField(
                        controller: deductionValueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) =>
                            setSheetState(() => validationError = null),
                        decoration: InputDecoration(
                          labelText: deductionMode == 'days'
                              ? 'deduction_days_label'.tr
                              : 'deduction_amount_label'.tr,
                          suffixText: deductionMode == 'days'
                              ? 'days_unit'.tr
                              : 'currency_egp'.tr,
                          filled: true,
                          fillColor: colors.sunken.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            borderSide:
                                BorderSide(color: colors.borderHairline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            borderSide:
                                BorderSide(color: colors.borderHairline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                                color: colors.brand, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                ],

                // Reason / note (optional for all statuses)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status == 'leave'
                            ? 'conversion_reason'.tr
                            : 'optional_note'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      TextField(
                        controller: reasonCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'enter_conversion_reason'.tr,
                          hintStyle: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            color: colors.textTertiary,
                          ),
                          filled: true,
                          fillColor: colors.sunken.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide:
                                BorderSide(color: colors.borderHairline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide:
                                BorderSide(color: colors.borderHairline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide:
                                BorderSide(color: colors.brand, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (validationError != null) ...[
                  const SizedBox(height: AppSpacing.s3),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: colors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 16, color: colors.error),
                          const SizedBox(width: AppSpacing.s2),
                          Expanded(
                            child: Text(
                              validationError!,
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 12,
                                color: colors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.s5),

                // Actions
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s4,
                    0,
                    AppSpacing.s4,
                    AppSpacing.s4 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              isLoading ? null : () => Get.back<void>(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.textSecondary,
                            side: BorderSide(color: colors.borderHairline),
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s3),
                          ),
                          child: Text('cancel'.tr),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (status == 'present' &&
                                      checkIn != null &&
                                      checkOut != null &&
                                      toMinutes(checkOut!) <=
                                          toMinutes(checkIn!)) {
                                    setSheetState(() => validationError =
                                        'check_out_must_be_after_check_in'
                                            .tr);
                                    return;
                                  }
                                  num? deductionValue;
                                  if (status == 'absent' &&
                                      deductionMode != 'auto') {
                                    deductionValue = num.tryParse(
                                        deductionValueCtrl.text.trim());
                                    if (deductionValue == null ||
                                        deductionValue < 0) {
                                      setSheetState(() => validationError =
                                          'deduction_value_invalid'.tr);
                                      return;
                                    }
                                  }
                                  Get.back<void>();
                                  final reason = reasonCtrl.text.trim();
                                  // Holiday / weekly-off are leave "kinds" in
                                  // the UI but map to their own backend status.
                                  final isLeave = status == 'leave';
                                  final apiStatus = isLeave &&
                                          (leaveType == 'holiday' ||
                                              leaveType == 'weekly_off')
                                      ? leaveType
                                      : status;
                                  await ctrl.setDayStatus(
                                    date: date,
                                    status: apiStatus,
                                    checkInTime:
                                        status == 'present' && checkIn != null
                                            ? toApiTime(checkIn!)
                                            : null,
                                    checkOutTime: status == 'present' &&
                                            checkOut != null
                                        ? toApiTime(checkOut!)
                                        : null,
                                    leaveType: apiStatus == 'leave'
                                        ? leaveType
                                        : null,
                                    reason: reason.isEmpty ? null : reason,
                                    deductionMode:
                                        status == 'absent' ? deductionMode : null,
                                    deductionValue: status == 'absent'
                                        ? deductionValue
                                        : null,
                                  );
                                },
                          icon: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator.adaptive(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text('save'.tr),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s3),
                          ),
                        ),
                      ),
                    ],
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

class _TimePickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final TimeOfDay? time;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String formattedTime;
  const _TimePickerTile({
    required this.label,
    required this.icon,
    required this.time,
    required this.color,
    required this.onTap,
    required this.onClear,
    required this.formattedTime,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasValue = time != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: hasValue
              ? color.withValues(alpha: 0.08)
              : colors.sunken.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasValue
                ? color.withValues(alpha: 0.3)
                : colors.borderHairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClear != null)
                  InkWell(
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.close,
                          size: 14, color: colors.textTertiary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              formattedTime,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: hasValue ? color : colors.textTertiary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasValue ? '' : 'tap_to_set'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveTypeOption {
  final String id;
  final String labelKey;
  final String descKey;
  final IconData icon;
  const _LeaveTypeOption({
    required this.id,
    required this.labelKey,
    required this.descKey,
    required this.icon,
  });
}

String _weekdayLabel(DateTime d) {
  // DateTime.weekday: 1=Mon ... 7=Sun
  switch (d.weekday) {
    case DateTime.saturday:
      return 'weekday_sat'.tr;
    case DateTime.sunday:
      return 'weekday_sun'.tr;
    case DateTime.monday:
      return 'weekday_mon'.tr;
    case DateTime.tuesday:
      return 'weekday_tue'.tr;
    case DateTime.wednesday:
      return 'weekday_wed'.tr;
    case DateTime.thursday:
      return 'weekday_thu'.tr;
    case DateTime.friday:
      return 'weekday_fri'.tr;
    default:
      return '';
  }
}

/* ─────────────────────────────────────────────────────────────────────── */
/*  FINANCIAL TAB                                                           */
/* ─────────────────────────────────────────────────────────────────────── */

class _FinancialTab extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _FinancialTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final f = ctrl.financialCurrent;
    final firstLoad = ctrl.financialStatus == StatusRequest.loading && f == null;

    // New layout: one always-visible summary card carrying the net amount,
    // status and the primary payroll actions, followed by an accordion of
    // collapsible sections so the page reads as a short list rather than a
    // long stack of cards. Every section is preserved — just folded away by
    // default (the breakdown stays open as the most-used detail).
    return RefreshIndicator(
      onRefresh: ctrl.loadFinancialMonth,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          _MonthSwitcher(
            month: ctrl.financialMonth,
            onChange: ctrl.changeFinancialMonth,
            cycleFrom: ctrl.cycleWindowFrom(ctrl.financialMonth),
            cycleTo: ctrl.cycleWindowTo(ctrl.financialMonth),
            maxMonth: ctrl.currentCycleLabelMonth(),
            minMonth: ctrl.minFinancialMonth(),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (firstLoad)
            const _FinancialLoading()
          else ...[
            // ── Hero: net amount + status + primary actions + payslip ──
            _FinancialSummaryCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s4),

            // ── Salary detail (kept open) ──
            _FinancialBreakdownCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s3),
            _FinancialAttendanceCard(ctrl: ctrl),

            // ── Adjustments (add lives in each section header) ──
            const SizedBox(height: AppSpacing.s3),
            _AdjustmentListCard(
              ctrl: ctrl,
              title: 'deductions_details'.tr,
              items: f?.deductions ?? const [],
              emptyKey: 'no_deductions_this_month',
              isDeduction: true,
            ),
            const SizedBox(height: AppSpacing.s3),
            _AdjustmentListCard(
              ctrl: ctrl,
              title: 'bonuses_details'.tr,
              // Allowances are shown in their own dedicated card; exclude
              // them here so they don't appear twice.
              items: (f?.bonuses ?? const [])
                  .where((a) => a.type != 'allowance')
                  .toList(),
              emptyKey: 'no_bonuses_this_month',
              isDeduction: false,
            ),
            const SizedBox(height: AppSpacing.s3),
            _AllowancesCard(ctrl: ctrl),

            // ── Statutory / loans / bank (only when relevant) ──
            if (f?.statutory?.hasAny ?? false) ...[
              const SizedBox(height: AppSpacing.s3),
              _StatutoryCard(ctrl: ctrl),
            ],
            if (ctrl.financialLoans.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              _LoansCard(ctrl: ctrl),
            ],
            if (_hasBankInfo(ctrl.employee)) ...[
              const SizedBox(height: AppSpacing.s3),
              _BankPaymentCard(ctrl: ctrl),
            ],

            // ── Documents & long-horizon info ──
            if (ctrl.eosb?.enabled ?? false) ...[
              const SizedBox(height: AppSpacing.s3),
              _EosbCard(ctrl: ctrl),
            ],
            if (f?.rules?.hasAny ?? false) ...[
              const SizedBox(height: AppSpacing.s3),
              _RulesCard(ctrl: ctrl),
            ],

            // ── History & reports ──
            if (ctrl.financialHistory.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              _SalaryTrendCard(ctrl: ctrl),
            ],
            if (ctrl.salaryHistory.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              _SalaryHistoryCard(ctrl: ctrl),
            ],
            const SizedBox(height: AppSpacing.s3),
            _PayrollHistoryCard(ctrl: ctrl),
            const SizedBox(height: AppSpacing.s4),
            _YearToDateButton(employeeId: ctrl.employeeId),
          ],
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

class _FinancialLoading extends StatelessWidget {
  const _FinancialLoading();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: const Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

/* ── Payroll status label ─────────────────────────────────────────────── */

String _statusLabel(String s) {
  switch (s) {
    case 'approved':
      return 'status_approved'.tr;
    case 'paid':
      return 'status_paid'.tr;
    default:
      return 'status_draft'.tr;
  }
}

/* ── BREAKDOWN: how the amount is composed ──────────────────────────────── */

/// Hero summary: the single most-important card. Shows the earned/net amount,
/// the payroll status, the pay-period meta, the context-aware primary actions
/// (approve / mark-paid / revert) and the payslip download — everything an
/// admin needs at a glance, consolidated so nothing is scattered.
class _FinancialSummaryCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _FinancialSummaryCard({required this.ctrl});

  Future<void> _confirmRevert(BuildContext context) async {
    final colors = AppColors.of(context);
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('payroll_revert_confirm_title'.tr),
        content: Text('payroll_revert_confirm_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back<bool>(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text('payroll_revert'.tr),
          ),
        ],
      ),
    );
    if (ok == true) await ctrl.revertCurrentSlip();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final f = ctrl.financialCurrent;
    if (f == null) return const SizedBox.shrink();
    final currency = 'currency_egp'.tr;

    final daysIn = f.daysInMonth;
    final partial = daysIn > 0 && f.daysElapsed > 0 && f.daysElapsed < daysIn;
    final resultLabel =
        partial ? 'salary_to_date_label'.tr : 'net_salary_full_label'.tr;
    final resultAmount = partial ? f.earnedToDate : f.netSalary;
    final statusColor = f.status == 'paid'
        ? colors.success
        : (f.status == 'approved' ? colors.brand : colors.warning);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resultLabel,
                        style: AppTextStyles.bodySecondary(context)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: RichText(
                        text: TextSpan(
                          text: _money(resultAmount),
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: colors.brand,
                            height: 1.0,
                          ),
                          children: [
                            TextSpan(
                              text: '  $currency',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _statusLabel(f.status),
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (f.cycleFrom != null && f.cycleTo != null) ...[
            const SizedBox(height: AppSpacing.s2),
            _MetaLine(
              icon: Icons.date_range_outlined,
              text: '${f.cycleFrom} → ${f.cycleTo}',
              mono: true,
            ),
          ],
          if (partial && f.daysElapsed > 0) ...[
            const SizedBox(height: AppSpacing.s1),
            _MetaLine(
              icon: Icons.event_available_outlined,
              text: 'work_days_value'.trParams({'days': '${f.daysElapsed}'}),
            ),
          ],
          // Draft = live estimate that can still change; approved/paid is the
          // frozen, locked figure. Make that explicit so the number isn't
          // mistaken for final before approval.
          if (!f.locked) ...[
            const SizedBox(height: AppSpacing.s1),
            _MetaLine(
              icon: Icons.info_outline,
              text: 'payroll_estimate_hint'.tr,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            child: Divider(height: 1, color: colors.borderHairline),
          ),
          _buildActions(context, colors, f),
          const SizedBox(height: AppSpacing.s3),
          _PayslipDownloadButton(ctrl: ctrl),
        ],
      ),
    );
  }

  /// Context-aware payroll workflow buttons (draft → approved → paid + revert),
  /// or a quiet hint when no slip has been generated yet.
  Widget _buildActions(
      BuildContext context, AppColorScheme colors, FinancialMonthSummary f) {
    if (f.payrollId == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.sunken.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.textTertiary),
            const SizedBox(width: AppSpacing.s2),
            Expanded(
              child: Text(
                'payroll_no_slip_yet'.tr,
                style: AppTextStyles.bodySecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    final loading = ctrl.adjustmentStatus == StatusRequest.loading;
    final status = f.status;
    final isDraft = status == 'draft';
    final isApproved = status == 'approved';
    final isPaid = status == 'paid';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isApproved && (f.approvedAt ?? '').isNotEmpty) ...[
          _MetaLine(
            icon: Icons.verified_outlined,
            text: '${'payroll_approved_at'.tr} ${_adjDate(f.approvedAt)}',
            mono: true,
          ),
          if ((f.approvedByName ?? '').isNotEmpty)
            _MetaLine(
              icon: Icons.person_outline,
              text: 'audit_approved_by'.trParams({'name': f.approvedByName!}),
            ),
          const SizedBox(height: AppSpacing.s3),
        ],
        if (isPaid && (f.paidAt ?? '').isNotEmpty) ...[
          _MetaLine(
            icon: Icons.check_circle_outline,
            text: '${'payroll_paid_at'.tr} ${_adjDate(f.paidAt)}',
            mono: true,
          ),
          if ((f.approvedByName ?? '').isNotEmpty)
            _MetaLine(
              icon: Icons.person_outline,
              text: 'audit_approved_by'.trParams({'name': f.approvedByName!}),
            ),
          const SizedBox(height: AppSpacing.s3),
        ],
        Row(
          children: [
            if (isDraft)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : ctrl.approveCurrentSlip,
                  icon: const Icon(Icons.verified_outlined, size: 18),
                  label: Text('payroll_approve'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  ),
                ),
              ),
            if (isApproved) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : () => ctrl.markCurrentSlipPaid(),
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text('payroll_mark_paid'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.success,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : () => _confirmRevert(context),
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text('payroll_revert'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.warning,
                    side: BorderSide(color: colors.warning),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  ),
                ),
              ),
            ],
            if (isPaid)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : () => _confirmRevert(context),
                  icon: const Icon(Icons.undo, size: 18),
                  label: Text('payroll_revert'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.warning,
                    side: BorderSide(color: colors.warning),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Collapsed salary breakdown (base → prorated → bonuses → deductions → net).
/// The headline amount now lives in [_FinancialSummaryCard]; this section keeps
/// the line-by-line composition for when the admin wants the detail.
class _FinancialBreakdownCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _FinancialBreakdownCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final f = ctrl.financialCurrent;
    if (f == null) return const SizedBox.shrink();
    final currency = 'currency_egp'.tr;

    final daysIn = f.daysInMonth;
    final partial = daysIn > 0 && f.daysElapsed > 0 && f.daysElapsed < daysIn;

    return _CollapsibleSection(
      icon: Icons.calculate_outlined,
      title: 'financial_breakdown'.tr,
      initiallyExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BreakdownRow(
            label: 'base_salary_label'.tr,
            amount: '${_money(f.baseSalary)} $currency',
            color: colors.textPrimary,
          ),
          if (partial) ...[
            const SizedBox(height: AppSpacing.s2),
            _BreakdownRow(
              label: 'prorated_base_label'.tr,
              amount: '${_money(f.proratedBaseSalary)} $currency',
              color: colors.textSecondary,
              indented: true,
            ),
          ],
          const SizedBox(height: AppSpacing.s2),
          _BreakdownRow(
            label: 'total_bonuses_label'.tr,
            amount: '+${_money(f.totalBonuses)} $currency',
            color: colors.success,
          ),
          const SizedBox(height: AppSpacing.s2),
          _BreakdownRow(
            label: 'total_deductions_label'.tr,
            amount: '-${_money(f.totalDeductions)} $currency',
            color: colors.error,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
            child: Divider(height: 1, color: colors.borderHairline),
          ),
          _BreakdownRow(
            label: partial
                ? 'full_cycle_net_label'.tr
                : 'net_salary_full_label'.tr,
            amount: '${_money(f.netSalary)} $currency',
            color: colors.brand,
          ),
        ],
      ),
    );
  }
}

/// A small icon + caption line used under the headline amount.
class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool mono;
  const _MetaLine({required this.icon, required this.text, this.mono = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 13, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.s1),
        Text(
          text,
          style: TextStyle(
            fontFamily: mono ? 'Geist' : 'IBM Plex Sans Arabic',
            fontSize: 12,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final bool indented;
  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.color,
    this.indented = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        if (indented) ...[
          Icon(Icons.subdirectory_arrow_left_rounded,
              size: 14, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.s1),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

/* ── BANK PAYMENT CARD (account info + payment status for this period) ── */

bool _hasBankInfo(EmployeeModel? e) {
  if (e == null) return false;
  final any = (e.bankName ?? '').trim().isNotEmpty ||
      (e.bankAccountNumber ?? '').trim().isNotEmpty ||
      (e.bankIban ?? '').trim().isNotEmpty;
  return any;
}

String _last4(String? s) {
  final v = (s ?? '').replaceAll(RegExp(r'\s+'), '');
  if (v.length <= 4) return v;
  return v.substring(v.length - 4);
}

class _BankPaymentCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _BankPaymentCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = ctrl.employee;
    final f = ctrl.financialCurrent;
    if (e == null) return const SizedBox.shrink();

    final bankName = (e.bankName ?? '').trim();
    final accountLast4 = _last4(e.bankAccountNumber);
    final ibanLast4 = _last4(e.bankIban);
    final isPaid = f?.status == 'paid' && (f?.paidAt ?? '').isNotEmpty;

    return _CollapsibleSection(
      icon: Icons.account_balance_wallet_outlined,
      title: 'bank_card_title'.tr,
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 3),
        decoration: BoxDecoration(
          color: (isPaid ? colors.success : colors.warning)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          isPaid
              ? 'bank_card_paid_on'.trParams({'date': _adjDate(f!.paidAt)})
              : 'bank_card_pending_pay'.tr,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isPaid ? colors.success : colors.warning,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bankName.isNotEmpty)
            Row(
              children: [
                Icon(Icons.account_balance, size: 16, color: colors.brand),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    bankName,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          if (accountLast4.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            _MetaLine(
              icon: Icons.credit_card,
              text:
                  'bank_card_account_masked'.trParams({'last4': accountLast4}),
              mono: true,
            ),
          ],
          if (ibanLast4.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            _MetaLine(
              icon: Icons.qr_code,
              text: 'bank_card_iban_masked'.trParams({'last4': ibanLast4}),
              mono: true,
            ),
          ],
        ],
      ),
    );
  }
}

/* ── STATUTORY: social insurance / income tax (compliance transparency) ── */

class _StatutoryCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _StatutoryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = ctrl.financialCurrent?.statutory;
    if (s == null) return const SizedBox.shrink();
    final currency = 'currency_egp'.tr;

    return _CollapsibleSection(
      icon: Icons.gavel_outlined,
      title: 'statutory_title'.tr,
      child: Column(
        children: [
          if (s.insuranceEmployee > 0)
            _BreakdownRow(
              label: 'statutory_insurance_employee'.tr,
              amount: '-${_money(s.insuranceEmployee)} $currency',
              color: colors.error,
            ),
          if (s.incomeTax > 0) ...[
            if (s.insuranceEmployee > 0) const SizedBox(height: AppSpacing.s2),
            _BreakdownRow(
              label: 'statutory_income_tax'.tr,
              amount: '-${_money(s.incomeTax)} $currency',
              color: colors.error,
            ),
          ],
          if (s.taxableIncome > 0) ...[
            const SizedBox(height: AppSpacing.s2),
            _BreakdownRow(
              label: 'statutory_taxable_income'.tr,
              amount: '${_money(s.taxableIncome)} $currency',
              color: colors.textTertiary,
            ),
          ],
          if (s.insuranceEmployer > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Divider(height: 1, color: colors.borderHairline),
            ),
            _BreakdownRow(
              label: 'statutory_insurance_employer'.tr,
              amount: '${_money(s.insuranceEmployer)} $currency',
              color: colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.s1),
            Row(
              children: [
                Icon(Icons.info_outline,
                    size: 12, color: colors.textTertiary),
                const SizedBox(width: AppSpacing.s1),
                Expanded(
                  child: Text(
                    'statutory_employer_note'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/* ── LOANS & ADVANCES (active balances + next due) ──────────────────────── */

class _LoansCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _LoansCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loans = ctrl.financialLoans;
    final currency = 'currency_egp'.tr;
    final totalRemaining =
        loans.fold<double>(0, (sum, l) => sum + l.remainingAmount);

    return _CollapsibleSection(
      icon: Icons.account_balance_outlined,
      title: 'loans_title'.tr,
      trailing: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s2, vertical: 3),
        decoration: BoxDecoration(
          color: colors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          '${_money(totalRemaining)} $currency',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.brand,
          ),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < loans.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s2),
            _LoanTile(loan: loans[i]),
          ],
        ],
      ),
    );
  }
}

class _LoanTile extends StatelessWidget {
  final LoanSummary loan;
  const _LoanTile({required this.loan});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currency = 'currency_egp'.tr;
    final progress = loan.installmentsCount > 0
        ? (loan.installmentsPaid / loan.installmentsCount).clamp(0.0, 1.0)
        : 0.0;
    final isPending = loan.status == 'pending';
    final statusColor = isPending ? colors.warning : colors.brand;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  loan.typeLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    loan.statusLabel,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 10,
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '${_money(loan.totalAmount)} $currency',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          if ((loan.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              loan.reason!,
              style: AppTextStyles.sm(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: colors.sunken,
              valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Text(
                'loan_installments_progress'.trParams({
                  'paid': '${loan.installmentsPaid}',
                  'total': '${loan.installmentsCount}',
                }),
                style: AppTextStyles.xs(context),
              ),
              const Spacer(),
              if (loan.nextDueMonth != null && !isPending)
                Text(
                  'loan_next_due'
                      .trParams({'month': loan.nextDueMonth!}),
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: _LoanMini(
                  label: 'loan_paid_label'.tr,
                  value: '${_money(loan.paidAmount)} $currency',
                  color: colors.success,
                ),
              ),
              _MetricDivider(color: colors.borderHairline),
              Expanded(
                child: _LoanMini(
                  label: 'loan_remaining_label'.tr,
                  value: '${_money(loan.remainingAmount)} $currency',
                  color: colors.error,
                ),
              ),
              _MetricDivider(color: colors.borderHairline),
              Expanded(
                child: _LoanMini(
                  label: 'loan_installment_label'.tr,
                  value: '${_money(loan.installmentAmount)} $currency',
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoanMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _LoanMini(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 10,
            color: colors.textTertiary,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

/* ── ATTENDANCE within the pay period ───────────────────────────────────── */

class _FinancialAttendanceCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _FinancialAttendanceCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final f = ctrl.financialCurrent;
    if (f == null) return const SizedBox.shrink();

    final total = f.attPresent + f.attLate + f.attAbsent + f.attLeave;
    final hasHours = f.attWorkedMinutes > 0 ||
        f.attOvertimeMinutes > 0 ||
        f.attLateMinutes > 0;

    return _CollapsibleSection(
      icon: Icons.event_note_outlined,
      title: 'attendance_in_period'.tr,
      child: total == 0 && !hasHours
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Center(
                child: Text('no_attendance_in_period'.tr,
                    style: AppTextStyles.bodySecondary(context)),
              ),
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryChip(
                        count: '${f.attPresent}',
                        label: 'attendance_present_short'.tr,
                        color: colors.success,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: _SummaryChip(
                        count: '${f.attLate}',
                        label: 'attendance_late_short'.tr,
                        color: colors.warning,
                        icon: Icons.schedule,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: _SummaryChip(
                        count: '${f.attAbsent}',
                        label: 'attendance_absent_short'.tr,
                        color: colors.error,
                        icon: Icons.cancel_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: _SummaryChip(
                        count: '${f.attLeave}',
                        label: 'attendance_leave_short'.tr,
                        color: colors.accentWarm,
                        icon: Icons.beach_access_outlined,
                      ),
                    ),
                  ],
                ),
                if (hasHours) ...[
                  const SizedBox(height: AppSpacing.s3),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: colors.sunken.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _MetricMini(
                            icon: Icons.work_history_outlined,
                            label: 'worked_hours_label'.tr,
                            value: _fmtHM(f.attWorkedMinutes),
                            color: colors.brand,
                          ),
                        ),
                        _MetricDivider(color: colors.borderHairline),
                        Expanded(
                          child: _MetricMini(
                            icon: Icons.trending_up,
                            label: 'overtime_hours_label'.tr,
                            value: _fmtHM(f.attOvertimeMinutes),
                            color: colors.success,
                          ),
                        ),
                        _MetricDivider(color: colors.borderHairline),
                        Expanded(
                          child: _MetricMini(
                            icon: Icons.history,
                            label: 'late_time_label'.tr,
                            value: _fmtHM(f.attLateMinutes),
                            color: colors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _MetricMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MetricMini({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 10,
            color: colors.textTertiary,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  final Color color;
  const _MetricDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      color: color,
    );
  }
}

/// A bordered card whose body folds away behind a tappable header (with a
/// rotating chevron). Takes the same `icon` / `title` / `trailing` / `child`
/// as a plain section card, plus [initiallyExpanded]; used across the
/// financial tab so the page reads as a compact accordion instead of a long
/// card stack.
class _CollapsibleSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;
  const _CollapsibleSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s4),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 18, color: colors.brand),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(widget.title,
                          style: AppTextStyles.h3(context)),
                    ),
                    if (widget.trailing != null) ...[
                      widget.trailing!,
                      const SizedBox(width: AppSpacing.s2),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 22, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4, 0, AppSpacing.s4, AppSpacing.s4),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

void _showAdjustmentSheet(
  BuildContext context,
  EmployeeDetailController ctrl, {
  required bool isDeduction,
  FinancialAdjustment? existing,
}) {
  final isEdit = existing != null && existing.isManual;
  final amountCtrl = TextEditingController(
    text: isEdit
        ? (existing.amount == existing.amount.roundToDouble()
            ? existing.amount.toInt().toString()
            : existing.amount.toString())
        : '',
  );
  final reasonCtrl =
      TextEditingController(text: isEdit ? existing.description : '');
  final formKey = GlobalKey<FormState>();

  Get.bottomSheet<void>(
    StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final colors = AppColors.of(context);
        final isLoading = ctrl.adjustmentStatus == StatusRequest.loading;
        final accent = isDeduction ? colors.error : colors.success;

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          isDeduction
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          color: accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit
                                  ? 'adjustment_edit_title'.tr
                                  : (isDeduction
                                      ? 'add_deduction'.tr
                                      : 'add_bonus'.tr),
                              style: AppTextStyles.h2(context),
                            ),
                            Text(ctrl.employee?.name ?? '',
                                style: AppTextStyles.bodySecondary(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'amount'.tr,
                      hintText: 'enter_amount'.tr,
                      suffixText: 'currency_egp'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'Geist', fontSize: 16),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'amount_required'.tr;
                      }
                      final parsed = num.tryParse(v);
                      if (parsed == null || parsed <= 0) {
                        return 'amount_must_be_positive'.tr;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'reason_optional'.tr,
                      hintText: 'enter_reason'.tr,
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
                              final amount = num.parse(amountCtrl.text);
                              final reason = reasonCtrl.text.trim();
                              Get.back<void>();
                              if (isEdit) {
                                await ctrl.updateManualAdjustment(
                                  id: existing.id!,
                                  isDeduction: isDeduction,
                                  amount: amount,
                                  reason: reason,
                                );
                              } else if (isDeduction) {
                                await ctrl.addManualDeduction(
                                    amount: amount, reason: reason);
                              } else {
                                await ctrl.addManualBonus(
                                    amount: amount, reason: reason);
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
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                        child: Text('save'.tr),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
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

/* ── Deduction / bonus detail lists ─────────────────────────────────────── */

class _AdjustmentListCard extends StatefulWidget {
  final EmployeeDetailController ctrl;
  final String title;
  final List<FinancialAdjustment> items;
  final String emptyKey;
  final bool isDeduction;
  const _AdjustmentListCard({
    required this.ctrl,
    required this.title,
    required this.items,
    required this.emptyKey,
    required this.isDeduction,
  });

  @override
  State<_AdjustmentListCard> createState() => _AdjustmentListCardState();
}

class _AdjustmentListCardState extends State<_AdjustmentListCard> {
  /// Show the search bar once the list gets unwieldy; below this we just
  /// render the rows directly.
  static const int _searchThreshold = 8;
  String _query = '';

  List<FinancialAdjustment> _filtered() {
    if (_query.trim().isEmpty) return widget.items;
    final q = _query.trim().toLowerCase();
    return widget.items.where((a) {
      final desc = a.description.toLowerCase();
      final type = a.typeLabel.toLowerCase();
      final amt = a.amount.toString();
      return desc.contains(q) || type.contains(q) || amt.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = widget.isDeduction ? colors.error : colors.success;
    final currency = 'currency_egp'.tr;
    final all = widget.items;
    final showSearch = all.length > _searchThreshold;
    final visible = showSearch ? _filtered() : all;
    final total = all.fold<double>(0, (sum, a) => sum + a.amount);

    Widget body;
    if (all.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        child: Center(
          child: Text(widget.emptyKey.tr,
              style: AppTextStyles.bodySecondary(context)),
        ),
      );
    } else {
      body = Column(
        children: [
          if (showSearch) ...[
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'adjustment_search_hint'.tr,
                prefixIcon:
                    Icon(Icons.search, size: 18, color: colors.textTertiary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              style:
                  const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Center(
                child: Text('adjustment_search_no_match'.tr,
                    style: AppTextStyles.bodySecondary(context)),
              ),
            )
          else
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.s2),
              _AdjustmentTile(
                ctrl: widget.ctrl,
                adjustment: visible[i],
                color: accent,
                sign: widget.isDeduction ? '-' : '+',
              ),
            ],
        ],
      );
    }

    return _CollapsibleSection(
      icon: widget.isDeduction
          ? Icons.remove_circle_outline
          : Icons.add_circle_outline,
      title: widget.title,
      // The add action now lives in the section header — next to the running
      // total — so deductions/bonuses are created where they're listed.
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (all.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${widget.isDeduction ? '-' : '+'}${_money(total)} $currency',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          IconButton(
            onPressed: () => _showAdjustmentSheet(context, widget.ctrl,
                isDeduction: widget.isDeduction),
            icon: Icon(Icons.add, size: 20, color: accent),
            tooltip: widget.isDeduction ? 'add_deduction'.tr : 'add_bonus'.tr,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
      child: body,
    );
  }
}

class _AdjustmentTile extends StatelessWidget {
  final EmployeeDetailController ctrl;
  final FinancialAdjustment adjustment;
  final Color color;
  final String sign;
  const _AdjustmentTile({
    required this.ctrl,
    required this.adjustment,
    required this.color,
    required this.sign,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _showAdjustmentDetailSheet(
          context,
          ctrl,
          adjustment,
          color: color,
          sign: sign,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: colors.sunken.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  adjustment.typeLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (adjustment.overridden) ...[
                const SizedBox(width: AppSpacing.s1),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s1, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'adjustment_overridden_badge'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: colors.warning,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adjustment.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_adjDate(adjustment.date).isNotEmpty)
                      Text(
                        _adjDate(adjustment.date),
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                '$sign${_money(adjustment.amount)} ${'currency_egp'.tr}',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.s1),
              Icon(Icons.chevron_left,
                  size: 18, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Normalises an adjustment date/time string to a plain `YYYY-MM-DD` (or the
/// `YYYY-MM` month label) for display, dropping any time component.
String _adjDate(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return '';
  if (s.length >= 10 && s[4] == '-' && s[7] == '-') return s.substring(0, 10);
  return s;
}

/// Detail bottom sheet for a single deduction / bonus line, showing its full
/// data (type, amount, date, and the description / reason).
void _showAdjustmentDetailSheet(
  BuildContext context,
  EmployeeDetailController ctrl,
  FinancialAdjustment adjustment, {
  required Color color,
  required String sign,
}) {
  final colors = AppColors.of(context);
  final isDeduction = sign == '-';
  // Approved/paid slips are locked snapshots — no in-place editing.
  final locked = ctrl.financialCurrent?.locked ?? false;

  Get.bottomSheet<void>(
    Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s4,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
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
              margin: const EdgeInsets.only(bottom: AppSpacing.s4),
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  isDeduction
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDeduction
                          ? 'deduction_detail_title'.tr
                          : 'bonus_detail_title'.tr,
                      style: AppTextStyles.h2(context),
                    ),
                    Text(adjustment.typeLabel,
                        style: AppTextStyles.bodySecondary(context)),
                  ],
                ),
              ),
              Text(
                '$sign${_money(adjustment.amount)} ${'currency_egp'.tr}',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          _DetailRow(
            label: 'adjustment_type_label'.tr,
            value: adjustment.typeLabel,
          ),
          _DetailRow(
            label: 'adjustment_amount_label'.tr,
            value: '${_money(adjustment.amount)} ${'currency_egp'.tr}',
            valueColor: color,
          ),
          if (_adjDate(adjustment.date).isNotEmpty)
            _DetailRow(
              label: 'adjustment_date_label'.tr,
              value: _adjDate(adjustment.date),
              mono: true,
            ),
          if (adjustment.description.trim().isNotEmpty)
            _DetailRow(
              label: 'adjustment_description_label'.tr,
              value: adjustment.description,
            ),
          if (adjustment.overridden && adjustment.originalAmount != null)
            _DetailRow(
              label: 'adjustment_original_amount_label'.tr,
              value:
                  '${_money(adjustment.originalAmount!)} ${'currency_egp'.tr}',
            ),
          if ((adjustment.createdByName ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            _MetaLine(
              icon: Icons.person_outline,
              text: 'audit_added_by'
                  .trParams({'name': adjustment.createdByName!}),
            ),
          ],
          // ── Actions ──
          if (locked) ...[
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.sunken.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: colors.textTertiary),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text('adjustment_locked_hint'.tr,
                        style: AppTextStyles.bodySecondary(context)),
                  ),
                ],
              ),
            ),
          ] else if (adjustment.isManual) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Get.back<void>();
                      _showAdjustmentSheet(
                        context, ctrl,
                        isDeduction: isDeduction,
                        existing: adjustment,
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text('adjustment_edit'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.brand,
                      side: BorderSide(color: colors.brand),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await Get.dialog<bool>(
                        AlertDialog(
                          title: Text('adjustment_delete_confirm_title'.tr),
                          content:
                              Text('adjustment_delete_confirm_message'.tr),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back<bool>(result: false),
                              child: Text('cancel'.tr),
                            ),
                            ElevatedButton(
                              onPressed: () => Get.back<bool>(result: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.error,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('adjustment_delete'.tr),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        Get.back<void>();
                        await ctrl.deleteManualAdjustment(
                          id: adjustment.id!,
                          isDeduction: isDeduction,
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text('adjustment_delete'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (adjustment.isOverridable) ...[
            // Derived line (absence / late / loan / insurance / tax / overtime):
            // edit its amount or remove it for this month via an override.
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Get.back<void>();
                      _showOverrideAmountDialog(context, ctrl, adjustment,
                          isDeduction: isDeduction);
                    },
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text('adjustment_override_value'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.brand,
                      side: BorderSide(color: colors.brand),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await Get.dialog<bool>(
                        AlertDialog(
                          title: Text('adjustment_waive_confirm_title'.tr),
                          content:
                              Text('adjustment_waive_confirm_message'.tr),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back<bool>(result: false),
                              child: Text('cancel'.tr),
                            ),
                            ElevatedButton(
                              onPressed: () => Get.back<bool>(result: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.error,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('adjustment_waive'.tr),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        Get.back<void>();
                        await ctrl.overrideAdjustmentLine(
                          line: adjustment,
                          isDeduction: isDeduction,
                          action: 'waive',
                        );
                      }
                    },
                    icon: const Icon(Icons.block, size: 18),
                    label: Text('adjustment_waive'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                      side: BorderSide(color: colors.error),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                  ),
                ),
              ],
            ),
            if (adjustment.overridden) ...[
              const SizedBox(height: AppSpacing.s2),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    Get.back<void>();
                    await ctrl.overrideAdjustmentLine(
                      line: adjustment,
                      isDeduction: isDeduction,
                      action: 'clear',
                    );
                  },
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text('adjustment_restore'.tr),
                ),
              ),
            ],
          ],
        ],
      ),
    ),
    isScrollControlled: true,
  );
}

/// Prompt for a replacement amount for a computed (non-manual) line, then save
/// it as a per-line override for the current financial month.
Future<void> _showOverrideAmountDialog(
  BuildContext context,
  EmployeeDetailController ctrl,
  FinancialAdjustment adjustment, {
  required bool isDeduction,
}) async {
  final colors = AppColors.of(context);
  final amountCtrl = TextEditingController(
    text: adjustment.amount == adjustment.amount.roundToDouble()
        ? adjustment.amount.toInt().toString()
        : adjustment.amount.toString(),
  );
  final result = await Get.dialog<num>(
    AlertDialog(
      title: Text('adjustment_override_value'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(adjustment.typeLabel,
              style: AppTextStyles.bodySecondary(context)),
          const SizedBox(height: AppSpacing.s3),
          TextField(
            controller: amountCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'amount'.tr,
              suffixText: 'currency_egp'.tr,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            style: const TextStyle(fontFamily: 'Geist', fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<num>(),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: () {
            final v = num.tryParse(amountCtrl.text.trim());
            if (v == null || v < 0) return;
            Get.back<num>(result: v);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.brand,
            foregroundColor: Colors.white,
          ),
          child: Text('save'.tr),
        ),
      ],
    ),
  );
  if (result != null) {
    await ctrl.overrideAdjustmentLine(
      line: adjustment,
      isDeduction: isDeduction,
      action: 'set',
      amount: result,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
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
              style: TextStyle(
                fontFamily: mono ? 'Geist' : 'IBM Plex Sans Arabic',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Payslip PDF download (generated server-side by PayslipPdfService) ──── */

class _PayslipDownloadButton extends StatefulWidget {
  final EmployeeDetailController ctrl;
  const _PayslipDownloadButton({required this.ctrl});

  @override
  State<_PayslipDownloadButton> createState() => _PayslipDownloadButtonState();
}

class _PayslipDownloadButtonState extends State<_PayslipDownloadButton> {
  bool _busy = false;

  Future<void> _download() async {
    if (_busy) return;
    setState(() => _busy = true);
    final path = await widget.ctrl.downloadPayslipPdf();
    if (!mounted) return;
    setState(() => _busy = false);
    if (path == null) return;
    try {
      final bytes = await File(path).readAsBytes();
      // Hand the PDF to the platform share / preview sheet. Printing uses a
      // content:// URI (via a FileProvider) under the hood, so it avoids the
      // Android FileUriExposedException that a raw file:// launch throws.
      await Printing.sharePdf(bytes: bytes, filename: path.split('/').last);
    } catch (_) {
      if (!mounted) return;
      Get.snackbar('error'.tr, 'payslip_download_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : _download,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          child: Text('payslip_download_pdf'.tr),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

/* ── ALLOWANCES (recurring monthly: housing, transport, food…) ──────────── */

class _AllowancesCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _AllowancesCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final items = ctrl.allowances;
    final currency = 'currency_egp'.tr;
    final now = DateTime.now();
    final currentMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final activeTotal = items
        .where((a) => a.isActive(currentMonth))
        .fold<double>(0, (s, a) => s + a.amount);

    return _CollapsibleSection(
      icon: Icons.workspace_premium_outlined,
      title: 'allowances_title'.tr,
      trailing: items.isEmpty
          ? IconButton(
              onPressed: () => _showAllowanceSheet(context, ctrl),
              icon: Icon(Icons.add, color: colors.brand),
              tooltip: 'allowance_add'.tr,
              visualDensity: VisualDensity.compact,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    '+${_money(activeTotal)} $currency',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.success,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _showAllowanceSheet(context, ctrl),
                  icon: Icon(Icons.add, color: colors.brand),
                  tooltip: 'allowance_add'.tr,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Center(
                child: Text('allowance_empty'.tr,
                    style: AppTextStyles.bodySecondary(context)),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.s2),
                  _AllowanceTile(
                    ctrl: ctrl,
                    allowance: items[i],
                    currentMonth: currentMonth,
                  ),
                ],
              ],
            ),
    );
  }
}

class _AllowanceTile extends StatelessWidget {
  final EmployeeDetailController ctrl;
  final Allowance allowance;
  final String currentMonth;
  const _AllowanceTile({
    required this.ctrl,
    required this.allowance,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currency = 'currency_egp'.tr;
    final active = allowance.isActive(currentMonth);
    final future = allowance.startMonth.compareTo(currentMonth) > 0;
    final (badge, badgeColor) = future
        ? ('allowance_future_badge'.tr, colors.warning)
        : (active
            ? ('allowance_active_badge'.tr, colors.success)
            : ('allowance_ended_badge'.tr, colors.textTertiary));
    final periodText = 'allowance_period'.trParams({
      'from': allowance.startMonth,
      'to': allowance.endMonth ?? 'allowance_end_month_ongoing'.tr,
    });

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () =>
            _showAllowanceSheet(context, ctrl, existing: allowance),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: colors.sunken.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      allowance.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      periodText,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                '+${_money(allowance.amount)} $currency',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: active ? colors.success : colors.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.s1),
              Icon(Icons.chevron_left, size: 18, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

void _showAllowanceSheet(
  BuildContext context,
  EmployeeDetailController ctrl, {
  Allowance? existing,
}) {
  final isEdit = existing != null;
  final amountCtrl = TextEditingController(
    text: isEdit
        ? (existing.amount == existing.amount.roundToDouble()
            ? existing.amount.toInt().toString()
            : existing.amount.toString())
        : '',
  );
  final labelCtrl =
      TextEditingController(text: isEdit ? (existing.label ?? '') : '');
  String type = isEdit ? existing.type : 'housing';
  String startMonth = isEdit
      ? existing.startMonth
      : '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
  String? endMonth = isEdit ? existing.endMonth : null;
  final formKey = GlobalKey<FormState>();

  const knownTypes = ['housing', 'transport', 'food', 'communication', 'other'];

  Future<String?> pickMonth(BuildContext c, {String? initial}) async {
    final now = DateTime.now();
    DateTime init = now;
    if (initial != null && RegExp(r'^\d{4}-\d{2}$').hasMatch(initial)) {
      final p = initial.split('-');
      init = DateTime(int.parse(p[0]), int.parse(p[1]));
    }
    final picked = await showDatePicker(
      context: c,
      initialDate: init,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'allowance_select_month'.tr,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked == null) return null;
    return '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
  }

  Get.bottomSheet<void>(
    StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final colors = AppColors.of(context);
        final loading = ctrl.adjustmentStatus == StatusRequest.loading;

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s2),
                        decoration: BoxDecoration(
                          color: colors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(Icons.workspace_premium_outlined,
                            color: colors.brand, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.s3),
                      Expanded(
                        child: Text(
                          isEdit
                              ? 'allowance_edit'.tr
                              : 'allowance_add'.tr,
                          style: AppTextStyles.h2(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      for (final t in knownTypes)
                        ChoiceChip(
                          label: Text({
                            'housing': 'allowance_type_housing'.tr,
                            'transport': 'allowance_type_transport'.tr,
                            'food': 'allowance_type_food'.tr,
                            'communication': 'allowance_type_communication'.tr,
                            'other': 'allowance_type_other'.tr,
                          }[t]!),
                          selected: type == t,
                          onSelected: (_) =>
                              setSheetState(() => type = t),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: !isEdit,
                    decoration: InputDecoration(
                      labelText: 'amount'.tr,
                      suffixText: 'currency_egp'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'Geist', fontSize: 16),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'amount_required'.tr;
                      }
                      final parsed = num.tryParse(v);
                      if (parsed == null || parsed <= 0) {
                        return 'amount_must_be_positive'.tr;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TextFormField(
                    controller: labelCtrl,
                    decoration: InputDecoration(
                      labelText: 'allowance_label_label'.tr,
                      hintText: 'allowance_label_hint'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await pickMonth(sheetCtx,
                                initial: startMonth);
                            if (picked != null) {
                              setSheetState(() => startMonth = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            '${'allowance_start_month'.tr}: $startMonth',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s3,
                                horizontal: AppSpacing.s3),
                            alignment: AlignmentDirectional.centerStart,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await pickMonth(sheetCtx,
                                initial: endMonth ?? startMonth);
                            if (picked != null) {
                              setSheetState(() => endMonth = picked);
                            }
                          },
                          icon: const Icon(Icons.event_outlined, size: 16),
                          label: Text(
                            endMonth == null
                                ? 'allowance_end_month_optional'.tr
                                : '${'allowance_end_month_optional'.tr}: $endMonth',
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s3,
                                horizontal: AppSpacing.s3),
                            alignment: AlignmentDirectional.centerStart,
                          ),
                        ),
                      ),
                      if (endMonth != null)
                        IconButton(
                          tooltip: 'allowance_end_month_ongoing'.tr,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setSheetState(() => endMonth = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Row(
                    children: [
                      if (isEdit) ...[
                        OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () async {
                                  final ok = await Get.dialog<bool>(
                                    AlertDialog(
                                      title: Text(
                                          'allowance_delete_confirm_title'.tr),
                                      content: Text(
                                          'allowance_delete_confirm_message'
                                              .tr),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Get.back<bool>(result: false),
                                          child: Text('cancel'.tr),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Get.back<bool>(result: true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: colors.error,
                                            foregroundColor: Colors.white,
                                          ),
                                          child:
                                              Text('adjustment_delete'.tr),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    Get.back<void>();
                                    await ctrl.deleteAllowance(existing.id);
                                  }
                                },
                          icon: Icon(Icons.delete_outline,
                              color: colors.error, size: 18),
                          label: Text('adjustment_delete'.tr,
                              style: TextStyle(color: colors.error)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.error),
                            // Theme forces full width (infinite); size to
                            // content inside this Row.
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) {
                                    return;
                                  }
                                  final amount = num.parse(amountCtrl.text);
                                  final label = labelCtrl.text.trim();
                                  Get.back<void>();
                                  await ctrl.saveAllowance(
                                    id: existing?.id,
                                    type: type,
                                    amount: amount,
                                    startMonth: startMonth,
                                    endMonth: endMonth,
                                    label: label.isEmpty ? null : label,
                                  );
                                },
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s2),
                            child: Text('save'.tr),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.brand,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
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

/* ── End-of-Service Benefits (long-horizon entitlement snapshot) ────────── */

class _EosbCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _EosbCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = ctrl.eosb;
    if (e == null || !e.enabled) return const SizedBox.shrink();
    final currency = 'currency_egp'.tr;

    return _CollapsibleSection(
      icon: Icons.savings_outlined,
      title: 'eosb_title'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('eosb_amount_label'.tr,
                        style: AppTextStyles.bodySecondary(context)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: RichText(
                        text: TextSpan(
                          text: _money(e.eosbAmount),
                          style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: colors.brand,
                            height: 1.0,
                          ),
                          children: [
                            TextSpan(
                              text: '  $currency',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (e.hireDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    e.hireDate!,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.brand,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.sunken.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LoanMini(
                    label: 'eosb_years_label'.tr,
                    value: 'eosb_years_value'
                        .trParams({'years': _years(e.yearsOfService)}),
                    color: colors.brand,
                  ),
                ),
                _MetricDivider(color: colors.borderHairline),
                Expanded(
                  child: _LoanMini(
                    label: 'eosb_days_per_year_label'.tr,
                    value: _years(e.eosbDaysPerYear),
                    color: colors.textPrimary,
                  ),
                ),
                _MetricDivider(color: colors.borderHairline),
                Expanded(
                  child: _LoanMini(
                    label: 'eosb_daily_wage_label'.tr,
                    value: '${_money(e.dailyWage)} $currency',
                    color: colors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.info_outline, size: 12, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  'eosb_formula_note'.trParams({
                    'years': _years(e.yearsOfService),
                    'days': _years(e.eosbDaysPerYear),
                    'wage': _money(e.dailyWage),
                  }),
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11,
                    color: colors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compact number for years/days (1 decimal when not whole).
  static String _years(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

/* ── RULES TRANSPARENCY (how late/absence/overtime convert to money) ───── */

class _RulesCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _RulesCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final r = ctrl.financialCurrent?.rules;
    if (r == null || !r.hasAny) return const SizedBox.shrink();
    final currency = 'currency_egp'.tr;

    final lines = <Widget>[];
    // Late rule
    if (r.lateType == 'proportional' &&
        r.lateUnitMinutes != null &&
        r.lateDeductionPerUnit != null) {
      lines.add(_RuleLine(
        icon: Icons.history,
        label: 'rule_section_late'.tr,
        value: 'rule_late_proportional'.trParams({
          'unit': _money(r.lateUnitMinutes!),
          'amount': '${_money(r.lateDeductionPerUnit!)} $currency',
        }),
        color: colors.warning,
      ));
    } else if (r.lateType == 'fixed' && r.lateFixedAmount != null) {
      lines.add(_RuleLine(
        icon: Icons.history,
        label: 'rule_section_late'.tr,
        value: 'rule_late_fixed'
            .trParams({'amount': '${_money(r.lateFixedAmount!)} $currency'}),
        color: colors.warning,
      ));
    }
    // Absence rule
    if (r.absenceMultiplier != null) {
      lines.add(_RuleLine(
        icon: Icons.cancel_outlined,
        label: 'rule_section_absence'.tr,
        value: 'rule_absence_multiplier'
            .trParams({'multiplier': _money(r.absenceMultiplier!)}),
        color: colors.error,
      ));
    }
    // Overtime rule
    if (r.overtimeMultiplier != null) {
      lines.add(_RuleLine(
        icon: Icons.trending_up,
        label: 'rule_section_overtime'.tr,
        value: 'rule_overtime_multiplier'
            .trParams({'multiplier': _money(r.overtimeMultiplier!)}),
        color: colors.success,
      ));
    }

    return _CollapsibleSection(
      icon: Icons.rule_outlined,
      title: 'rule_transparency_title'.tr,
      child: Column(
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s2),
            lines[i],
          ],
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _RuleLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ── SALARY TREND (bar chart from financialHistory, last 6 months) ─────── */

class _SalaryTrendCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _SalaryTrendCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final all = ctrl.financialHistory;
    if (all.isEmpty) return const SizedBox.shrink();
    // Take the most-recent 6 and display oldest → newest left-to-right (or
    // right-to-left in RTL, the Row direction follows the locale).
    final items = all.length > 6 ? all.sublist(0, 6) : all;
    final ordered = items.reversed.toList();
    final maxNet = ordered.map((e) => e.netSalary).reduce(math.max);
    final avg = ordered.map((e) => e.netSalary).reduce((a, b) => a + b) /
        ordered.length;
    final currency = 'currency_egp'.tr;

    return _CollapsibleSection(
      icon: Icons.bar_chart_outlined,
      title: 'trend_card_title'.tr,
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 3),
        decoration: BoxDecoration(
          color: colors.brand.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          '${'trend_avg_label'.tr} ${_money(avg)} $currency',
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: colors.brand,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('trend_card_subtitle'.tr,
              style: AppTextStyles.bodySecondary(context)),
          const SizedBox(height: AppSpacing.s3),
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in ordered)
                  Expanded(
                    child: _TrendBar(
                      entry: e,
                      maxNet: maxNet,
                      currency: currency,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBar extends StatelessWidget {
  final FinancialHistoryEntry entry;
  final double maxNet;
  final String currency;
  const _TrendBar({
    required this.entry,
    required this.maxNet,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fraction =
        maxNet > 0 ? (entry.netSalary / maxNet).clamp(0.0, 1.0) : 0.0;
    final color = entry.status == 'paid'
        ? colors.success
        : (entry.status == 'approved' ? colors.brand : colors.warning);
    final parts = entry.month.split('-');
    final monthIdx = parts.length == 2 ? int.tryParse(parts[1]) ?? 1 : 1;
    final monthShort = 'month_$monthIdx'.tr;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _money(entry.netSalary),
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Reserve full height; the visible portion is sized by `fraction`.
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final h = (c.maxHeight * fraction).clamp(4.0, c.maxHeight);
                return Stack(
                  alignment: AlignmentDirectional.bottomCenter,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors.sunken.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color,
                            color.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            monthShort,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 10,
              color: colors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/* ── SALARY HISTORY (base salary change timeline from audit_log) ────────── */

class _SalaryHistoryCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _SalaryHistoryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final history = ctrl.salaryHistory;
    final currentBase = ctrl.employee?.baseSalary ?? 0;
    final currency = 'currency_egp'.tr;

    return _CollapsibleSection(
      icon: Icons.timeline_outlined,
      title: 'salary_history_title'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The current salary always tops the timeline.
          _SalaryHistoryRow(
            amount: '${_money(currentBase)} $currency',
            subtitle: 'salary_history_current'.tr,
            color: colors.brand,
            isCurrent: true,
          ),
          for (final s in history) ...[
            const SizedBox(height: AppSpacing.s2),
            _SalaryHistoryRow(
              amount: '${_money(s.baseSalary)} $currency',
              subtitle: [
                _adjDate(s.createdAt),
                if ((s.adminName ?? '').isNotEmpty)
                  'salary_history_by'.trParams({'name': s.adminName!}),
              ].join(' · '),
              color: colors.textTertiary,
              isCurrent: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _SalaryHistoryRow extends StatelessWidget {
  final String amount;
  final String subtitle;
  final Color color;
  final bool isCurrent;
  const _SalaryHistoryRow({
    required this.amount,
    required this.subtitle,
    required this.color,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: isCurrent
            ? colors.brand.withValues(alpha: 0.08)
            : colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: isCurrent
            ? Border.all(color: colors.brand.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  amount,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isCurrent ? colors.brand : colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Payroll history ────────────────────────────────────────────────────── */

class _PayrollHistoryCard extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _PayrollHistoryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final history = ctrl.financialHistory;
    return _CollapsibleSection(
      icon: Icons.receipt_long_outlined,
      title: 'payroll_history'.tr,
      child: history.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              child: Center(
                child: Text('no_payroll_history'.tr,
                    style: AppTextStyles.bodySecondary(context)),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.s2),
                  _PayrollHistoryTile(history[i]),
                ],
              ],
            ),
    );
  }
}

class _PayrollHistoryTile extends StatelessWidget {
  final FinancialHistoryEntry entry;
  const _PayrollHistoryTile(this.entry);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final parts = entry.month.split('-');
    final monthIdx = parts.length == 2 ? int.tryParse(parts[1]) ?? 1 : 1;
    final year = parts.length == 2 ? parts[0] : '';
    final label = '${'month_$monthIdx'.tr} $year';
    final statusColor = entry.status == 'paid'
        ? colors.success
        : (entry.status == 'approved' ? colors.brand : colors.warning);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            margin: const EdgeInsetsDirectional.only(end: AppSpacing.s3),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s2, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    entry.statusLabel,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_money(entry.netSalary)} ${'currency_egp'.tr}',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/* ── Money & time formatting helpers ────────────────────────────────────── */

/// Formats a money amount with thousands separators, dropping the decimals
/// when the value is whole (e.g. 12500 → "12,500", 12500.5 → "12,500.50").
String _money(double v) {
  final isWhole = v == v.roundToDouble();
  final raw = isWhole ? v.toInt().toString() : v.toStringAsFixed(2);
  final dot = raw.indexOf('.');
  final intPart = dot == -1 ? raw : raw.substring(0, dot);
  final frac = dot == -1 ? '' : raw.substring(dot);
  final neg = intPart.startsWith('-');
  final digits = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}$buf$frac';
}

/// Formats a minutes count as "Xس Yد" (hours/minutes), or "Yد" under an hour.
String _fmtHM(int minutes) {
  if (minutes <= 0) return '0 ${'hours_short'.tr}';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m ${'minutes_short'.tr}';
  if (m == 0) return '$h ${'hours_short'.tr}';
  return '$h ${'hours_short'.tr} $m ${'minutes_short'.tr}';
}

/* ─────────────────────────────────────────────────────────────────────── */
/*  DOCUMENTS TAB                                                           */
/* ─────────────────────────────────────────────────────────────────────── */

class _DocumentsTab extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _DocumentsTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final e = ctrl.employee;
    final required = ctrl.requiredDocuments;
    // Uploaded records not tied to any current requirement (kept visible so
    // nothing silently disappears).
    final extraDocs = ctrl.documents
        .where((d) =>
            d.status != 'rejected' &&
            !required.any((r) => r.id == d.requiredDocumentId))
        .toList();
    final hasAny = required.isNotEmpty || extraDocs.isNotEmpty;

    return RefreshIndicator(
      onRefresh: ctrl.loadDocuments,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_outlined,
                        size: 18, color: colors.brand),
                    const SizedBox(width: AppSpacing.s2),
                    Text('requested_documents'.tr,
                        style: AppTextStyles.h3(context)),
                    const Spacer(),
                    if (required.isNotEmpty)
                      Text(
                        '${ctrl.uploadedRequiredCount}/${required.length}',
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
                else if (!hasAny)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s5),
                    child: Center(
                      child: Text('no_requested_documents'.tr,
                          style: AppTextStyles.bodySecondary(context),
                          textAlign: TextAlign.center),
                    ),
                  )
                else ...[
                  ...required.map((req) {
                    final docForReq = ctrl.documentForRequired(req.id);
                    return _RequiredDocTile(
                      requiredDoc: req,
                      document: docForReq,
                      onTap: docForReq != null
                          ? () => _showDocReviewSheet(context, ctrl, docForReq)
                          : null,
                    );
                  }),
                  ...extraDocs.map((doc) => _DocumentTile(
                        document: doc,
                        onDelete: () => ctrl.deleteDocument(doc.id),
                      )),
                ],
                if (e != null && ctrl.canManageDocuments) ...[
                  const SizedBox(height: AppSpacing.s3),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showRequestDocumentSheet(context, ctrl),
                      icon: const Icon(Icons.note_add_outlined, size: 18),
                      label: Text('request_document'.tr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

/// Bottom sheet shown when tapping an uploaded document in the documents tab:
/// preview the file, and (for documents awaiting review) approve or reject it.
void _showDocReviewSheet(
    BuildContext context, EmployeeDetailController ctrl, DocumentModel doc) {
  final colors = AppColors.of(context);
  final hasFile = doc.filePath != null || doc.fileUrl != null;
  final isUploaded = doc.status == 'uploaded';
  final isVerified = doc.verifiedAt != null;

  Get.bottomSheet<void>(
    Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4,
                  AppSpacing.s4, AppSpacing.s2),
              child: Text(doc.name, style: AppTextStyles.h3(context)),
            ),
            if (hasFile)
              ListTile(
                leading: Icon(Icons.visibility_outlined, color: colors.brand),
                title: Text('view_document'.tr),
                onTap: () {
                  Get.back<void>();
                  ctrl.openDocument(doc.id,
                      mimeType: doc.mimeType, originalName: doc.originalName);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
                child: Text('no_documents'.tr,
                    style: AppTextStyles.bodySecondary(context)),
              ),
            if (isUploaded && !isVerified)
              ListTile(
                leading:
                    Icon(Icons.check_circle_outline, color: colors.success),
                title: Text('document_verify'.tr),
                onTap: () {
                  Get.back<void>();
                  ctrl.verifyDocument(doc.id);
                },
              ),
            if (isUploaded)
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: colors.error),
                title: Text('document_reject'.tr),
                onTap: () {
                  Get.back<void>();
                  _showDetailRejectDialog(context, ctrl, doc.id);
                },
              ),
            const SizedBox(height: AppSpacing.s2),
          ],
        ),
      ),
    ),
  );
}

void _showDetailRejectDialog(
    BuildContext context, EmployeeDetailController ctrl, int docId) {
  final reasonCtl = TextEditingController();
  Get.defaultDialog<void>(
    title: 'document_reject'.tr,
    content: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      child: TextField(
        controller: reasonCtl,
        decoration: InputDecoration(
          labelText: 'rejection_reason'.tr,
          isDense: true,
        ),
        maxLines: 2,
      ),
    ),
    textConfirm: 'reject'.tr,
    textCancel: 'cancel'.tr,
    confirmTextColor: Colors.white,
    buttonColor: AppColors.of(context).error,
    onConfirm: () {
      Get.back<void>();
      ctrl.rejectDocument(docId, reasonCtl.text.trim());
    },
  );
}

/// Bottom sheet to request a document from this employee — either by picking
/// from the tenant's document-type catalog, or by entering a custom, ad-hoc
/// document specific to this employee.
void _showRequestDocumentSheet(
    BuildContext context, EmployeeDetailController ctrl) {
  if (ctrl.documentCatalog.isEmpty) {
    ctrl.loadDocumentCatalog();
  }
  final selected = <int>{};
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  String mode = 'catalog';
  String? nameError;

  Get.bottomSheet<void>(
    GetBuilder<EmployeeDetailController>(
      builder: (_) {
        final colors = AppColors.of(context);
        final options = ctrl.requestableDocuments;
        final loading = ctrl.documentCatalogStatus == StatusRequest.loading;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            Widget modeTab(String value, String labelKey, IconData icon) {
              final isSel = mode == value;
              return Expanded(
                child: InkWell(
                  onTap: () => setSheetState(() => mode = value),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    decoration: BoxDecoration(
                      color: isSel ? colors.brand : colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSel ? colors.brand : colors.borderHairline,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon,
                            size: 16,
                            color: isSel ? Colors.white : colors.textTertiary),
                        const SizedBox(width: AppSpacing.s2),
                        Text(
                          labelKey.tr,
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 13,
                            fontWeight:
                                isSel ? FontWeight.w600 : FontWeight.w400,
                            color: isSel ? Colors.white : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final bool canSend =
                mode == 'catalog' ? selected.isNotEmpty : true;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              padding: EdgeInsets.only(
                left: AppSpacing.s4,
                right: AppSpacing.s4,
                top: AppSpacing.s4,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg)),
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
                  Text('request_document_title'.tr,
                      style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s1),
                  Text(ctrl.employee?.name ?? '',
                      style: AppTextStyles.bodySecondary(context)),
                  const SizedBox(height: AppSpacing.s3),
                  Row(
                    children: [
                      modeTab('catalog', 'request_from_catalog',
                          Icons.list_alt_outlined),
                      const SizedBox(width: AppSpacing.s2),
                      modeTab('custom', 'request_custom',
                          Icons.edit_note_outlined),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  if (mode == 'catalog') ...[
                    if (loading)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: AppSpacing.s6),
                        child: Center(
                            child: CircularProgressIndicator.adaptive()),
                      )
                    else if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s6),
                        child: Center(
                          child: Text('no_requestable_documents'.tr,
                              style: AppTextStyles.bodySecondary(context),
                              textAlign: TextAlign.center),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: options.map((opt) {
                            final isSel = selected.contains(opt.id);
                            return Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s2),
                              child: InkWell(
                                onTap: () => setSheetState(() {
                                  if (isSel) {
                                    selected.remove(opt.id);
                                  } else {
                                    selected.add(opt.id);
                                  }
                                }),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                child: Container(
                                  padding:
                                      const EdgeInsets.all(AppSpacing.s3),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? colors.brandSubtle
                                        : colors.surface,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                      color: isSel
                                          ? colors.brand
                                          : colors.borderHairline,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSel
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        size: 20,
                                        color: isSel
                                            ? colors.brand
                                            : colors.textTertiary,
                                      ),
                                      const SizedBox(width: AppSpacing.s3),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              opt.name,
                                              style: TextStyle(
                                                fontFamily:
                                                    'IBM Plex Sans Arabic',
                                                fontSize: 14,
                                                fontWeight: isSel
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                                color: isSel
                                                    ? colors.brand
                                                    : colors.textPrimary,
                                              ),
                                            ),
                                            if (opt.description != null &&
                                                opt.description!
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                opt.description!,
                                                style: TextStyle(
                                                  fontFamily:
                                                      'IBM Plex Sans Arabic',
                                                  fontSize: 12,
                                                  color: colors.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ] else ...[
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: nameCtrl,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                if (nameError != null) {
                                  setSheetState(() => nameError = null);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'custom_document_name'.tr,
                                hintText: 'custom_document_name_hint'.tr,
                                errorText: nameError,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s3),
                            TextField(
                              controller: descCtrl,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'custom_document_description'.tr,
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: !canSend
                          ? null
                          : () async {
                              if (mode == 'catalog') {
                                final ids = selected.toList();
                                Get.back<void>();
                                for (final id in ids) {
                                  await ctrl.requestDocument(id);
                                }
                              } else {
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  setSheetState(() => nameError =
                                      'custom_document_name_required'.tr);
                                  return;
                                }
                                Get.back<void>();
                                await ctrl.requestCustomDocument(
                                  name: name,
                                  description: descCtrl.text.trim(),
                                );
                              }
                            },
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s2),
                        child: Text(
                          mode == 'catalog' && selected.isNotEmpty
                              ? '${'send_request'.tr} (${selected.length})'
                              : 'send_request'.tr,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
    isScrollControlled: true,
  );
}

/// A single required-document row in the profile tab: shows the document the
/// company asked for and whether the employee has provided it.
class _RequiredDocTile extends StatelessWidget {
  final RequiredDocumentModel requiredDoc;
  final DocumentModel? document;
  final VoidCallback? onTap;
  const _RequiredDocTile({required this.requiredDoc, this.document, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final has = document != null;
    final status = document?.status ?? 'required';
    // An uploaded doc is only "confirmed" once it carries verifiedAt; until
    // then it still needs review, so reflect that in colour and icon too.
    final isVerified = status == 'uploaded' && document?.verifiedAt != null;
    final statusColor = !has
        ? colors.warning
        : (status == 'uploaded' && !isVerified
            ? colors.warning
            : _docStatusColor(status, colors));
    final statusLabel =
        has ? document!.statusLabel : 'document_missing'.tr;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            !has
                ? Icons.error_outline
                : (isVerified
                    ? Icons.check_circle_outline
                    : (status == 'uploaded'
                        ? Icons.hourglass_top
                        : Icons.description_outlined)),
            size: 22,
            color: statusColor,
          ),
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
                if (document?.expiryDate != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${'expires'.tr} ${document!.expiryDate!.year}-${document!.expiryDate!.month.toString().padLeft(2, '0')}-${document!.expiryDate!.day.toString().padLeft(2, '0')}',
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
                horizontal: AppSpacing.s2, vertical: 2),
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
        ],
      ),
      ),
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
    final statusColor = _docStatusColor(document.status, colors);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                horizontal: AppSpacing.s2, vertical: 2),
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
}

Color _docStatusColor(String status, AppColorScheme colors) {
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

/* ─────────────────────────────────────────────────────────────────────── */
/*  WARNINGS TAB                                                            */
/* ─────────────────────────────────────────────────────────────────────── */

class _WarningsTab extends StatefulWidget {
  final EmployeeDetailController ctrl;
  const _WarningsTab({required this.ctrl});

  @override
  State<_WarningsTab> createState() => _WarningsTabState();
}

class _WarningsTabState extends State<_WarningsTab> {
  EmployeeDetailController get ctrl => widget.ctrl;

  /// Warnings shown before the "show all" toggle is expanded.
  static const int _collapsedCount = 5;
  bool _showAllWarnings = false;

  /// System-generated alerts are part of the audit trail and cannot be removed.
  static const _deletableTypes = {'verbal', 'written', 'final'};

  @override
  void initState() {
    super.initState();
    // The disciplinary tab also shows the work-suspension log. Defer the load
    // to after the first frame: loadSuspensionHistory calls update() up-front
    // to show its loading state, which is illegal during the build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ctrl.loadSuspensionHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        await ctrl.loadEmployee();
        await ctrl.loadSuspensionHistory();
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          _SuspensionsCard(ctrl: ctrl),
          const SizedBox(height: AppSpacing.s4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.report_gmailerrorred_outlined,
                        size: 18, color: colors.warning),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        'warnings_log'.tr,
                        style: AppTextStyles.h3(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ctrl.canManageEmployees)
                      OutlinedButton.icon(
                        onPressed: () => _showAddWarningSheet(context, ctrl),
                        icon: Icon(Icons.add_circle_outline,
                            size: 16, color: colors.warning),
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
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                if (ctrl.warnings.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s5),
                    child: Center(
                      child: Text('no_warnings'.tr,
                          style: AppTextStyles.bodySecondary(context)),
                    ),
                  )
                else ...[
                  ...(_showAllWarnings
                          ? ctrl.warnings
                          : ctrl.warnings.take(_collapsedCount))
                      .map((w) => _WarningTile(
                            warning: w,
                            onDelete: ctrl.canManageEmployees &&
                                    _deletableTypes.contains(w.type)
                                ? () => _confirmDeleteWarning(context, ctrl, w.id)
                                : null,
                          )),
                  if (ctrl.warnings.length > _collapsedCount)
                    _ShowMoreButton(
                      expanded: _showAllWarnings,
                      total: ctrl.warnings.length,
                      onTap: () => setState(
                          () => _showAllWarnings = !_showAllWarnings),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteWarning(
    BuildContext context, EmployeeDetailController ctrl, int warningId) async {
  final confirmed = await Get.dialog<bool>(
    AlertDialog(
      title: Text('delete_warning'.tr),
      content: Text('confirm_delete_warning'.tr),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.of(context).error,
            foregroundColor: Colors.white,
          ),
          child: Text('delete'.tr),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ctrl.deleteWarning(warningId);
  }
}

/// A compact "Show all (N) / Show less" toggle used by the collapsible logs in
/// the disciplinary tab.
class _ShowMoreButton extends StatelessWidget {
  final bool expanded;
  final int total;
  final VoidCallback onTap;
  const _ShowMoreButton({
    required this.expanded,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: colors.brand,
        ),
        label: Text(
          expanded ? 'show_less'.tr : '${'show_all'.tr} ($total)',
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.brand,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

void _showAddWarningSheet(BuildContext context, EmployeeDetailController ctrl) {
  String selectedType = 'verbal';
  final reasonCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  Get.bottomSheet<void>(
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
                  Text(ctrl.employee?.name ?? '',
                      style: AppTextStyles.bodySecondary(context)),
                  const SizedBox(height: AppSpacing.s4),
                  Text('select_warning_type'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        color: colors.textTertiary,
                      )),
                  const SizedBox(height: AppSpacing.s2),
                  ...['verbal', 'written', 'final'].map((t) {
                    final selected = selectedType == t;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                      child: InkWell(
                        onTap: () => setSheetState(() => selectedType = t),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s3),
                          decoration: BoxDecoration(
                            color: selected
                                ? colors.brandSubtle
                                : colors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: selected
                                  ? colors.brand
                                  : colors.borderHairline,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 20,
                                color: selected
                                    ? colors.brand
                                    : colors.textTertiary,
                              ),
                              const SizedBox(width: AppSpacing.s3),
                              Text(
                                _warningTypeLabel(t),
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected
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
                              Get.back<void>();
                              await ctrl.addWarning(
                                  type: selectedType, reason: reason);
                            },
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s2),
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
  ).whenComplete(reasonCtrl.dispose);
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

/* ─────────────────────────────────────────────────────────────────────── */
/*  WORK SUSPENSION ("موقوف عن العمل")                                       */
/* ─────────────────────────────────────────────────────────────────────── */

String _fmtSuspensionDate(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String _suspensionPayModeLabel(String mode) {
  switch (mode) {
    case 'unpaid':
      return 'suspension_pay_unpaid'.tr;
    case 'partial':
      return 'suspension_pay_partial'.tr;
    case 'full':
      return 'suspension_pay_full'.tr;
    default:
      return mode;
  }
}

void _showSuspendSheet(BuildContext context, EmployeeDetailController ctrl) {
  final reasonCtrl = TextEditingController();
  final percentCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String payMode = 'unpaid';
  DateTime startDate = DateTime.now();
  DateTime? endDate;
  bool openEnded = true;

  Get.bottomSheet<void>(
    StatefulBuilder(
      builder: (sheetCtx, setSheetState) {
        final colors = AppColors.of(context);
        final isLoading = ctrl.suspensionStatus == StatusRequest.loading;

        Future<void> pickStart() async {
          final picked = await showDatePicker(
            context: context,
            initialDate: startDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setSheetState(() {
              startDate = picked;
              if (endDate != null && endDate!.isBefore(startDate)) {
                endDate = startDate;
              }
            });
          }
        }

        Future<void> pickEnd() async {
          final picked = await showDatePicker(
            context: context,
            initialDate: endDate ?? startDate,
            firstDate: startDate,
            lastDate: DateTime(2100),
          );
          if (picked != null) setSheetState(() => endDate = picked);
        }

        Widget payOption(String mode, IconData icon) {
          final selected = payMode == mode;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: InkWell(
              onTap: () => setSheetState(() => payMode = mode),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: selected ? colors.brandSubtle : colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: selected ? colors.brand : colors.borderHairline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: selected ? colors.brand : colors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Icon(icon,
                        size: 18,
                        color: selected ? colors.brand : colors.textTertiary),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        _suspensionPayModeLabel(mode),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? colors.brand : colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
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
                  Text('suspend_employee'.tr, style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(ctrl.employee?.name ?? '',
                      style: AppTextStyles.bodySecondary(context)),
                  const SizedBox(height: AppSpacing.s4),

                  // Reason
                  TextFormField(
                    controller: reasonCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'suspension_reason'.tr,
                      hintText: 'suspension_reason_hint'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'reason_required'.tr
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.s4),

                  // Pay treatment
                  Text('suspension_pay_treatment'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        color: colors.textTertiary,
                      )),
                  const SizedBox(height: AppSpacing.s2),
                  payOption('unpaid', Icons.money_off),
                  payOption('partial', Icons.percent),
                  payOption('full', Icons.payments_outlined),

                  if (payMode == 'partial') ...[
                    const SizedBox(height: AppSpacing.s1),
                    TextFormField(
                      controller: percentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'suspension_pay_percentage'.tr,
                        hintText: '50',
                        suffixText: '%',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      validator: (v) {
                        if (payMode != 'partial') return null;
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null || n <= 0 || n >= 100) {
                          return 'suspension_pay_percentage_invalid'.tr;
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s4),

                  // Dates
                  _SuspensionDateField(
                    label: 'suspension_start_date'.tr,
                    value: _fmtSuspensionDate(startDate),
                    onTap: pickStart,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('suspension_open_ended'.tr,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                        )),
                    subtitle: Text('suspension_open_ended_hint'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 12,
                          color: colors.textTertiary,
                        )),
                    value: openEnded,
                    activeThumbColor: colors.brand,
                    onChanged: (v) => setSheetState(() {
                      openEnded = v;
                      if (v) {
                        endDate = null;
                      } else {
                        endDate ??= startDate;
                      }
                    }),
                  ),
                  if (!openEnded) ...[
                    const SizedBox(height: AppSpacing.s2),
                    _SuspensionDateField(
                      label: 'suspension_end_date'.tr,
                      value: _fmtSuspensionDate(endDate),
                      onTap: pickEnd,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s6),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              final reason = reasonCtrl.text.trim();
                              final pct = payMode == 'partial'
                                  ? double.tryParse(percentCtrl.text.trim())
                                  : null;
                              final ok = await ctrl.suspendEmployee(
                                reason: reason,
                                payMode: payMode,
                                payPercentage: pct,
                                startDate: startDate,
                                endDate: openEnded ? null : endDate,
                              );
                              if (ok) Get.back<void>();
                            },
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.block),
                      label: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                        child: Text('suspend_confirm'.tr),
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
  ).whenComplete(() {
    reasonCtrl.dispose();
    percentCtrl.dispose();
  });
}

void _confirmEndSuspension(BuildContext context, EmployeeDetailController ctrl) {
  final noteCtrl = TextEditingController();
  final colors = AppColors.of(context);
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
          Text('end_suspension'.tr, style: AppTextStyles.h2(context)),
          const SizedBox(height: AppSpacing.s2),
          Text('end_suspension_hint'.tr,
              style: AppTextStyles.bodySecondary(context)),
          const SizedBox(height: AppSpacing.s4),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'suspension_end_note'.tr,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final note = noteCtrl.text.trim();
                final ok = await ctrl.endSuspension(
                    endNote: note.isEmpty ? null : note);
                if (ok) Get.back<void>();
              },
              icon: const Icon(Icons.play_circle_outline),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
                child: Text('end_suspension'.tr),
              ),
            ),
          ),
        ],
      ),
    ),
    isScrollControlled: true,
  ).whenComplete(noteCtrl.dispose);
}

class _SuspensionDateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _SuspensionDateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 14,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SuspensionsCard extends StatefulWidget {
  final EmployeeDetailController ctrl;
  const _SuspensionsCard({required this.ctrl});

  @override
  State<_SuspensionsCard> createState() => _SuspensionsCardState();
}

class _SuspensionsCardState extends State<_SuspensionsCard> {
  static const int _collapsedCount = 5;
  bool _showAll = false;

  EmployeeDetailController get ctrl => widget.ctrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final suspended = ctrl.isSuspended;
    final actionColor = suspended ? colors.success : colors.error;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, size: 18, color: colors.error),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  'suspension_history'.tr,
                  style: AppTextStyles.h3(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (ctrl.canManageEmployees &&
                  ctrl.employee != null &&
                  ctrl.employee!.status != 'terminated')
                OutlinedButton.icon(
                  onPressed: () => suspended
                      ? _confirmEndSuspension(context, ctrl)
                      : _showSuspendSheet(context, ctrl),
                  icon: Icon(
                    suspended ? Icons.play_circle_outline : Icons.block,
                    size: 16,
                    color: actionColor,
                  ),
                  label: Text(suspended
                      ? 'end_suspension'.tr
                      : 'suspend_employee'.tr),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: actionColor,
                    side: BorderSide(color: actionColor),
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
          if (suspended && ctrl.activeSuspension != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                'suspension_active_title'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          if (ctrl.suspensionHistory.isEmpty &&
              (ctrl.suspensionHistoryStatus == StatusRequest.loading ||
                  ctrl.suspensionHistoryStatus == StatusRequest.none))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s5),
              child: Center(child: CircularProgressIndicator.adaptive()),
            )
          else if (ctrl.suspensionHistory.isEmpty &&
              (ctrl.suspensionHistoryStatus == StatusRequest.failure ||
                  ctrl.suspensionHistoryStatus ==
                      StatusRequest.serverFailure ||
                  ctrl.suspensionHistoryStatus == StatusRequest.offline))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Center(
                child: Column(
                  children: [
                    Text('suspension_history_load_failed'.tr,
                        style: AppTextStyles.bodySecondary(context)),
                    const SizedBox(height: AppSpacing.s2),
                    TextButton.icon(
                      onPressed: ctrl.loadSuspensionHistory,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('retry'.tr),
                    ),
                  ],
                ),
              ),
            )
          else if (ctrl.suspensionHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s5),
              child: Center(
                child: Text('no_suspensions'.tr,
                    style: AppTextStyles.bodySecondary(context)),
              ),
            )
          else ...[
            ...(_showAll
                    ? ctrl.suspensionHistory
                    : ctrl.suspensionHistory.take(_collapsedCount))
                .map((s) => _SuspensionTile(item: s)),
            if (ctrl.suspensionHistory.length > _collapsedCount)
              _ShowMoreButton(
                expanded: _showAll,
                total: ctrl.suspensionHistory.length,
                onTap: () => setState(() => _showAll = !_showAll),
              ),
          ],
        ],
      ),
    );
  }
}

class _SuspensionBanner extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _SuspensionBanner({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final s = ctrl.activeSuspension;
    final period = s == null
        ? ''
        : s.isOpenEnded
            ? '${_fmtSuspensionDate(s.startDate)} — ${'suspension_open_ended_short'.tr}'
            : '${_fmtSuspensionDate(s.startDate)} → ${_fmtSuspensionDate(s.endDate)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, color: colors.error, size: 20),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Text(
                  'suspension_active_title'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.error,
                  ),
                ),
              ),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: AppSpacing.s3),
            _SuspensionRow(label: 'suspension_pay_treatment'.tr, value: s.payModeLabel),
            if (s.payMode == 'partial' && s.payPercentage != null)
              _SuspensionRow(
                  label: 'suspension_pay_percentage'.tr,
                  value: '${s.payPercentage!.toStringAsFixed(0)}%'),
            _SuspensionRow(label: 'suspension_period'.tr, value: period),
            if (s.reason.isNotEmpty)
              _SuspensionRow(label: 'suspension_reason'.tr, value: s.reason),
          ],
          if (ctrl.canManageEmployees) ...[
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmEndSuspension(context, ctrl),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: Text('end_suspension'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuspensionRow extends StatelessWidget {
  final String label;
  final String value;
  const _SuspensionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuspensionTile extends StatelessWidget {
  final SuspensionModel item;
  const _SuspensionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = item.isActive ? colors.error : colors.textTertiary;
    final period = item.isOpenEnded
        ? '${_fmtSuspensionDate(item.startDate)} — ${'suspension_open_ended_short'.tr}'
        : '${_fmtSuspensionDate(item.startDate)} → ${_fmtSuspensionDate(item.endDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  item.isActive
                      ? 'suspension_status_active'.tr
                      : 'suspension_status_ended'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s2),
              Text(
                item.payModeLabel +
                    (item.payMode == 'partial' && item.payPercentage != null
                        ? ' (${item.payPercentage!.toStringAsFixed(0)}%)'
                        : ''),
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(period,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              )),
          if (item.reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(item.reason,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: colors.textSecondary,
                )),
          ],
          if (item.createdByName != null) ...[
            const SizedBox(height: 2),
            Text('${'suspension_issued_by'.tr}: ${item.createdByName}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.textTertiary,
                )),
          ],
        ],
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  final WarningModel warning;
  final VoidCallback? onDelete;
  const _WarningTile({required this.warning, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typeColor = _warningColor(warning.type, colors);
    final date = warning.createdAt;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2, vertical: AppSpacing.s1),
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
                      Text('·',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary)),
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
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline,
                  size: 18, color: colors.textTertiary),
              tooltip: 'delete_warning'.tr,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
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

/* ─────────────────────────────────────────────────────────────────────── */
/*  REVIEWS TAB                                                             */
/* ─────────────────────────────────────────────────────────────────────── */

class _ReviewsTab extends StatelessWidget {
  final EmployeeDetailController ctrl;
  const _ReviewsTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: ctrl.loadReviews,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_outline, size: 18, color: colors.brand),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        'performance_reviews'.tr,
                        style: AppTextStyles.h3(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ctrl.canManageEmployees)
                      OutlinedButton.icon(
                        onPressed: () => _showAddReviewSheet(context, ctrl),
                        icon: Icon(Icons.star_outline,
                            size: 16, color: colors.brand),
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
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                if (ctrl.reviewStatus == StatusRequest.loading)
                  const Center(child: CircularProgressIndicator.adaptive())
                else if (ctrl.reviews.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s5),
                    child: Center(
                      child: Text('no_reviews_yet'.tr,
                          style: AppTextStyles.bodySecondary(context)),
                    ),
                  )
                else
                  ...ctrl.reviews.map((r) => _ReviewTile(
                        review: r,
                        onDelete: ctrl.canManageEmployees
                            ? () => _confirmDeleteReview(context, ctrl, r.id)
                            : null,
                      )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s7),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteReview(
    BuildContext context, EmployeeDetailController ctrl, int reviewId) async {
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
            backgroundColor: AppColors.of(context).error,
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

void _showAddReviewSheet(BuildContext context, EmployeeDetailController ctrl) {
  int selectedRating = 3;
  final periodCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  Get.bottomSheet<void>(
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
                  Text(ctrl.employee?.name ?? '',
                      style: AppTextStyles.bodySecondary(context)),
                  const SizedBox(height: AppSpacing.s4),
                  Text('review_rating'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        color: colors.textTertiary,
                      )),
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
                              Get.back<void>();
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
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s2),
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
              color: filled
                  ? _ratingColor(rating, colors)
                  : colors.textTertiary,
            ),
          ),
        );
      }),
    );
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
        color: colors.sunken.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                if ((review.notes ?? '').isNotEmpty) ...[
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
                      Text('·',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary)),
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
}

/* ── YTD button + dialog ──────────────────────────────────────────── */

class _YearToDateButton extends StatelessWidget {
  final int employeeId;
  const _YearToDateButton({required this.employeeId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showSheet(context),
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(
          'ytd_button'.tr,
          style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.brand,
          side: BorderSide(color: colors.brand),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  Future<void> _showSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _YearToDateSheet(employeeId: employeeId),
    );
  }
}

class _YearToDateSheet extends StatefulWidget {
  final int employeeId;
  const _YearToDateSheet({required this.employeeId});

  @override
  State<_YearToDateSheet> createState() => _YearToDateSheetState();
}

class _YearToDateSheetState extends State<_YearToDateSheet> {
  late int _year = DateTime.now().year;
  StatusRequest _status = StatusRequest.loading;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _status = StatusRequest.loading;
      _data = null;
    });
    final res = await Get.find<EmployeeData>()
        .getYearToDate(widget.employeeId, _year);
    if (!mounted) return;
    if (res['status'] == StatusRequest.success) {
      dynamic payload = res['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      setState(() {
        _data = payload is Map<String, dynamic> ? payload : null;
        _status = StatusRequest.success;
      });
    } else {
      setState(() => _status = StatusRequest.failure);
    }
  }

  String _money(dynamic v) {
    // The YTD endpoint returns money fields as JSON strings (e.g. "12500.00"),
    // so coerce strings/nums/null to a number before formatting.
    final num n =
        v is num ? v : (v is String ? (num.tryParse(v) ?? 0) : 0);
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final totals = (_data?['totals'] as Map?)?.cast<String, dynamic>();
    final monthly = (_data?['monthly'] as List?) ?? const [];
    // Lift the currency off the payroll controller if it happens to be
    // mounted (common path: user navigated here from the payroll page).
    // Falls back to EGP when this screen was reached without going through
    // payroll first.
    String iso = 'EGP';
    try {
      iso = Get.find<PayrollController>().currency;
    } catch (_) {/* controller not bound, keep default */}
    final cur = currencyLabel(iso);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.s2),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() => _year--);
                      _fetch();
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${'ytd_title'.tr} • $_year',
                        style: AppTextStyles.h2(context),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _year >= DateTime.now().year
                        ? null
                        : () {
                            setState(() => _year++);
                            _fetch();
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Expanded(
              child: _status == StatusRequest.loading
                  ? const Center(
                      child: CircularProgressIndicator.adaptive(),
                    )
                  : _status == StatusRequest.failure
                      ? Center(
                          child: Text('error'.tr,
                              style: AppTextStyles.bodySecondary(context)),
                        )
                      : ListView(
                          controller: scroll,
                          padding: const EdgeInsets.all(AppSpacing.s4),
                          children: [
                            if (totals != null) _totalsCard(totals, cur, colors),
                            const SizedBox(height: AppSpacing.s3),
                            Text('ytd_monthly_breakdown'.tr,
                                style: AppTextStyles.h3(context)),
                            const SizedBox(height: AppSpacing.s2),
                            if (monthly.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.s5),
                                  child: Text('ytd_no_data'.tr,
                                      style: AppTextStyles.bodySecondary(context)),
                                ),
                              )
                            else
                              ...monthly.map<Widget>((row) {
                                final r = (row as Map).cast<String, dynamic>();
                                return _monthRow(r, cur, colors);
                              }),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalsCard(
      Map<String, dynamic> t, String cur, AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brand, colors.brandHover],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ytd_total_net'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: Colors.white70,
              )),
          const SizedBox(height: 2),
          Text(
            '${_money(t['total_net'])} $cur',
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(child: _miniStat('ytd_total_base'.tr,
                  _money(t['total_base']),
                  Icons.account_balance_wallet_outlined)),
              const SizedBox(width: AppSpacing.s2),
              Expanded(child: _miniStat('ytd_total_bonuses'.tr,
                  _money(t['total_bonuses']),
                  Icons.north_rounded)),
              const SizedBox(width: AppSpacing.s2),
              Expanded(child: _miniStat('ytd_total_deductions'.tr,
                  _money(t['total_deductions']),
                  Icons.south_rounded)),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '${t['months_count'] ?? 0} ${'ytd_months'.tr} • '
            '${t['paid_count'] ?? 0} ${'status_paid'.tr} • '
            '${t['approved_count'] ?? 0} ${'status_approved'.tr} • '
            '${t['draft_count'] ?? 0} ${'status_draft'.tr}',
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 10,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        ],
      ),
    );
  }

  Widget _monthRow(
      Map<String, dynamic> r, String cur, AppColorScheme colors) {
    final month = (r['month'] as String?) ?? '';
    final parts = month.split('-');
    final monthNum = parts.length >= 2 ? int.tryParse(parts[1]) : null;
    final year = parts.isNotEmpty ? parts[0] : '';
    final monthLabel = monthNum != null ? '${'month_$monthNum'.tr} $year' : month;
    final status = (r['status'] as String?) ?? 'draft';
    final statusColor = status == 'paid'
        ? colors.brand
        : status == 'approved'
            ? colors.success
            : colors.warning;
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
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: statusColor, shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(monthLabel,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Text(
            '${_money(r['net_salary'])} $cur',
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.brand,
            ),
          ),
        ],
      ),
    );
  }
}
