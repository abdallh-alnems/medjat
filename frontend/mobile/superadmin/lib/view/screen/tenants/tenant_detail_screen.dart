import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/tenant_detail_model.dart';
import '../../../data/model/tenant_diagnostics_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/tenant/tenant_detail_controller.dart';
import '../../../logic/controller/user/user_controller.dart' show ContactActions;
import '../shared/panel_widgets.dart';
import 'tenants_screen.dart' show showInvitationDialog;

/// One company, end to end: who they are, how they are configured, how much
/// they use the system, who to call — and, on demand, why their attendance is
/// failing.
class TenantDetailScreen extends StatelessWidget {
  const TenantDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canWrite = Get.find<AuthController>().admin?.canWrite ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ملف الشركة'),
        actions: [
          GetBuilder<TenantDetailController>(
            builder: (c) => IconButton(
              onPressed: c.refreshAll,
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
            ),
          ),
        ],
      ),
      body: GetBuilder<TenantDetailController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status.value,
            onRetry: controller.loadDetail,
            widget: RefreshIndicator(
              onRefresh: controller.refreshAll,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
                children: [
                  if (controller.detail.value != null) ...[
                    _HeaderCard(controller: controller, canWrite: canWrite),
                    _StatsCard(stats: controller.detail.value!.stats),
                    _ActivityCard(
                      activity: controller.detail.value!.activity,
                      settings: controller.detail.value!.settings,
                    ),
                    _ContactCard(controller: controller, canWrite: canWrite),
                    _ManagersCard(controller: controller, canWrite: canWrite),
                    _DiagnosticsSection(controller: controller),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final TenantDetailController controller;
  final bool canWrite;

  const _HeaderCard({required this.controller, required this.canWrite});

  @override
  Widget build(BuildContext context) {
    final tenant = controller.detail.value!.tenant;
    final colors = panelColors(context);

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tenant.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                text: tenant.isActiveTenant ? 'نشطة' : 'متوقفة',
                tone: tenant.isActiveTenant ? PillTone.success : PillTone.error,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '#${tenant.id} · ${tenant.timezone ?? ''} · ${tenant.currency ?? ''}',
            style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: colors.textTertiary),
          ),
          Text(
            'عميل منذ ${shortDate(tenant.createdAt)}',
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          if (canWrite) ...[
            const SizedBox(height: AppSpacing.s3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: controller.busy.value ? null : controller.toggleActive,
                icon: Icon(
                  tenant.isActiveTenant ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 18,
                ),
                label: Text(tenant.isActiveTenant ? 'إيقاف الشركة' : 'تفعيل الشركة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tenant.isActiveTenant ? colors.error : colors.success,
                  minimumSize: const Size(0, 40),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final TenantStats stats;

  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return PanelCard(
      title: 'الحجم والاستخدام',
      child: Wrap(
        spacing: AppSpacing.s2,
        runSpacing: AppSpacing.s2,
        children: [
          StatTile(label: 'موظف نشط', value: '${stats.employeesActive}'),
          StatTile(label: 'بانتظار التفعيل', value: '${stats.employeesPending}'),
          StatTile(label: 'فرع', value: '${stats.branches}'),
          StatTile(label: 'مدير', value: '${stats.admins}'),
          StatTile(
            label: 'حضور اليوم',
            value: '${stats.attendanceToday}',
            color: stats.attendanceToday > 0 ? colors.success : colors.textTertiary,
          ),
          StatTile(label: 'حضور ٧ أيام', value: '${stats.attendanceLast7Days}'),
          StatTile(label: 'مسجّل بالبصمة', value: '${stats.employeesBiometric}'),
          if (stats.pendingInvitations > 0)
            StatTile(
              label: 'دعوة معلّقة',
              value: '${stats.pendingInvitations}',
              color: colors.warning,
            ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final TenantActivity activity;
  final TenantSettings settings;

  const _ActivityCard({required this.activity, required this.settings});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final methods = settings.methodLabels;

    return PanelCard(
      title: 'الإعدادات والنشاط',
      child: Column(
        children: [
          InfoRow(
            label: 'طريقة الحضور',
            value: methods.isEmpty ? '—' : methods.join('، '),
          ),
          InfoRow(
            label: 'بصمة الوجه',
            value: settings.faceEnforceMode == 'enforce'
                ? 'مُفعَّلة (عتبة ${settings.faceThreshold})'
                : 'تسجيل فقط (عتبة ${settings.faceThreshold})',
            valueColor:
                settings.faceEnforceMode == 'enforce' ? colors.warning : colors.textPrimary,
          ),
          InfoRow(
            label: 'الحضور من المتصفح',
            value: settings.webAttendanceEnabled ? 'مُفعَّل' : 'مُعطَّل',
          ),
          InfoRow(
            label: 'رفض الموقع المزيّف',
            value: settings.rejectMockLocation ? 'مُفعَّل' : 'مُعطَّل',
          ),
          const Divider(height: AppSpacing.s5),
          InfoRow(
            label: 'آخر حضور مسجّل',
            value: relativeAge(activity.lastAttendanceDate, never: 'لم يبدأوا'),
          ),
          InfoRow(
            label: 'آخر دخول لمدير',
            value: relativeAge(activity.lastAdminLoginAt, never: 'لم يدخل أحد'),
          ),
          InfoRow(
            label: 'آخر ترحيل غياب',
            value: shortDate(activity.lastAbsenceRun),
            numeric: true,
          ),
          InfoRow(
            label: 'اليوم لدى الشركة',
            value: shortDate(activity.today),
            numeric: true,
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final TenantDetailController controller;
  final bool canWrite;

  const _ContactCard({required this.controller, required this.canWrite});

  @override
  Widget build(BuildContext context) {
    final tenant = controller.detail.value!.tenant;
    final colors = panelColors(context);
    final phone = tenant.contactPhone?.trim();
    final email = tenant.contactEmail?.trim();

    return PanelCard(
      title: 'جهة الاتصال وملاحظاتنا',
      trailing: canWrite
          ? TextButton(
              onPressed: () => _showEditSheet(context, controller),
              child: const Text('تعديل'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((tenant.contactName ?? '').isEmpty &&
              (phone ?? '').isEmpty &&
              (email ?? '').isEmpty)
            Text(
              'لم نسجّل جهة اتصال لهذه الشركة بعد.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            )
          else ...[
            InfoRow(label: 'الاسم', value: tenant.contactName ?? '—'),
            InfoRow(label: 'الهاتف', value: phone?.isNotEmpty == true ? phone! : '—', numeric: true),
            InfoRow(label: 'البريد', value: email?.isNotEmpty == true ? email! : '—', numeric: true),
            if ((phone ?? '').isNotEmpty || (email ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s3),
              Row(
                children: [
                  if ((phone ?? '').isNotEmpty) ...[
                    _ContactButton(
                      icon: Icons.phone,
                      label: 'اتصال',
                      onTap: () => ContactActions.call(phone!),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    _ContactButton(
                      icon: Icons.chat,
                      label: 'واتساب',
                      onTap: () => ContactActions.whatsapp(phone!),
                    ),
                  ],
                  if ((email ?? '').isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.s2),
                    _ContactButton(
                      icon: Icons.mail_outline,
                      label: 'بريد',
                      onTap: () => ContactActions.email(email!),
                    ),
                  ],
                ],
              ),
            ],
          ],
          if ((tenant.opsNotes ?? '').isNotEmpty) ...[
            const Divider(height: AppSpacing.s5),
            Text(
              tenant.opsNotes!,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void _showEditSheet(BuildContext context, TenantDetailController controller) {
  final tenant = controller.detail.value!.tenant;
  final nameCtl = TextEditingController(text: tenant.name);
  final contactNameCtl = TextEditingController(text: tenant.contactName ?? '');
  final phoneCtl = TextEditingController(text: tenant.contactPhone ?? '');
  final emailCtl = TextEditingController(text: tenant.contactEmail ?? '');
  final notesCtl = TextEditingController(text: tenant.opsNotes ?? '');

  Get.bottomSheet<void>(
    SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.s4,
          right: AppSpacing.s4,
          top: AppSpacing.s4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تعديل بيانات الشركة',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'اسم الشركة'),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextField(
              controller: contactNameCtl,
              decoration: const InputDecoration(labelText: 'جهة الاتصال'),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextField(
              controller: phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'الهاتف',
                hintText: '+201000000000',
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextField(
              controller: emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد'),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextField(
              controller: notesCtl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'ملاحظات داخلية'),
            ),
            const SizedBox(height: AppSpacing.s5),
            ElevatedButton(
              onPressed: () async {
                final saved = await controller.saveContact(
                  name: nameCtl.text.trim(),
                  contactName: contactNameCtl.text.trim(),
                  contactPhone: phoneCtl.text.trim(),
                  contactEmail: emailCtl.text.trim(),
                  opsNotes: notesCtl.text.trim(),
                );
                if (saved) Get.back<void>();
              },
              child: const Text('حفظ'),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
        ),
      ),
    ),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    isScrollControlled: true,
  );
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderHairline),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.brand),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagersCard extends StatelessWidget {
  final TenantDetailController controller;
  final bool canWrite;

  const _ManagersCard({required this.controller, required this.canWrite});

  @override
  Widget build(BuildContext context) {
    final managers = controller.detail.value!.managers;
    final colors = panelColors(context);

    return PanelCard(
      title: 'مديرو الشركة (${managers.length})',
      trailing: canWrite
          ? TextButton(
              onPressed: () => _showInviteSheet(context, controller),
              child: const Text('دعوة'),
            )
          : null,
      child: managers.isEmpty
          ? Text(
              'لا يوجد مدير — لا أحد يستطيع الدخول لهذه الشركة. أرسل دعوة.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.error,
              ),
            )
          : Column(
              children: managers.map((m) => _ManagerRow(manager: m)).toList(),
            ),
    );
  }
}

class _ManagerRow extends StatelessWidget {
  final CompanyManager manager;

  const _ManagerRow({required this.manager});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final phone = manager.phone?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        manager.name,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    if (!manager.isActiveManager)
                      const StatusPill(text: 'موقوف', tone: PillTone.error),
                  ],
                ),
                Text(
                  '${manager.role != null ? _roleLabel(manager.role!) : ''} · آخر دخول ${relativeAge(manager.lastLoginAt, never: 'لم يدخل')}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty)
            IconButton(
              onPressed: () => ContactActions.call(phone),
              icon: const Icon(Icons.phone, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'اتصال',
            ),
          if ((manager.email ?? '').isNotEmpty)
            IconButton(
              onPressed: () => ContactActions.email(manager.email!),
              icon: const Icon(Icons.mail_outline, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'بريد',
            ),
        ],
      ),
    );
  }

  static String _roleLabel(String role) {
    const labels = {
      'general_manager': 'مدير عام',
      'hr': 'موارد بشرية',
      'branch_manager': 'مدير فرع',
      'attendance': 'مسؤول حضور',
      'viewer': 'مشاهد',
    };
    return labels[role] ?? role;
  }
}

void _showInviteSheet(BuildContext context, TenantDetailController controller) {
  final emailCtl = TextEditingController();
  final nameCtl = TextEditingController();
  final role = 'general_manager'.obs;

  Get.bottomSheet<void>(
    SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.s4,
          right: AppSpacing.s4,
          top: AppSpacing.s4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'دعوة مدير للشركة',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            Text(
              'يُستخدم عندما يفقد العميل كل مديريه ولا يستطيع دعوة أحد بنفسه.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: panelColors(context).textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            TextField(
              controller: emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(labelText: 'الاسم (اختياري)'),
            ),
            const SizedBox(height: AppSpacing.s3),
            Obx(
              () => DropdownButtonFormField<String>(
                initialValue: role.value,
                decoration: const InputDecoration(labelText: 'الدور'),
                items: const [
                  DropdownMenuItem(value: 'general_manager', child: Text('مدير عام')),
                  DropdownMenuItem(value: 'hr', child: Text('موارد بشرية')),
                  DropdownMenuItem(value: 'branch_manager', child: Text('مدير فرع')),
                  DropdownMenuItem(value: 'attendance', child: Text('مسؤول حضور')),
                  DropdownMenuItem(value: 'viewer', child: Text('مشاهد')),
                ],
                onChanged: (v) => role.value = v ?? 'general_manager',
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtl.text.trim();
                if (!GetUtils.isEmail(email)) {
                  Get.snackbar('خطأ', 'بريد غير صالح', snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                final invitation = await controller.inviteManager(
                  email: email,
                  name: nameCtl.text.trim(),
                  role: role.value,
                );
                if (invitation != null) {
                  Get.back<void>();
                  showInvitationDialog(invitation);
                }
              },
              child: const Text('إرسال الدعوة'),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
        ),
      ),
    ),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    isScrollControlled: true,
  );
}

/// Diagnostics load only when asked for: they are the heavier query, and most
/// visits to this screen are not about a failure.
class _DiagnosticsSection extends StatelessWidget {
  final TenantDetailController controller;

  const _DiagnosticsSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    if (!controller.diagnosticsLoaded.value) {
      return PanelCard(
        title: 'تشخيص الحضور',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بصمة الوجه، محاولات الرفض، تغطية WiFi، أجهزة البصمة والأكشاك، وقنوات التسجيل خلال ٣٠ يومًا.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: controller.diagnosticsStatus.value == StatusRequest.loading
                    ? null
                    : () => controller.loadDiagnostics(),
                icon: const Icon(Icons.troubleshoot, size: 18),
                label: Text(
                  controller.diagnosticsStatus.value == StatusRequest.loading
                      ? 'جارٍ الفحص…'
                      : 'تشغيل التشخيص',
                ),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
            ),
          ],
        ),
      );
    }

    final d = controller.diagnostics.value;
    if (d == null) {
      return const PanelCard(child: Text('تعذّر تحميل التشخيص'));
    }

    return Column(
      children: [
        _FaceCard(face: d.face, windowDays: d.windowDays),
        _SecurityCard(security: d.security, windowDays: d.windowDays),
        _WifiCard(coverage: d.wifi),
        _HardwareCard(devices: d.devices, kiosks: d.kiosks),
        _ChannelsCard(channels: d.channels, windowDays: d.windowDays),
      ],
    );
  }
}

class _FaceCard extends StatelessWidget {
  final FaceDiagnostics face;
  final int windowDays;

  const _FaceCard({required this.face, required this.windowDays});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return PanelCard(
      title: 'بصمة الوجه — آخر $windowDays يومًا',
      trailing: StatusPill(
        text: face.isEnforcing ? 'إلزامي' : 'تسجيل فقط',
        tone: face.isEnforcing ? PillTone.warning : PillTone.neutral,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (face.attempts == 0)
            Text(
              'لا توجد محاولات في هذه الفترة.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            )
          else ...[
            if (face.thresholdLooksWrong)
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'نسبة الرفض مرتفعة (${((face.rejectionRate ?? 0) * 100).round()}%) — العتبة ${face.threshold} قد تكون عالية على بيانات هذه الشركة.',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.warning,
                    height: 1.5,
                  ),
                ),
              ),
            InfoRow(label: 'المحاولات', value: '${face.attempts}', numeric: true),
            InfoRow(label: 'مقبولة', value: '${face.accepted}', numeric: true),
            InfoRow(
              label: 'أقل من العتبة',
              value: '${face.belowThreshold}',
              numeric: true,
              valueColor: face.belowThreshold > 0 ? colors.warning : null,
            ),
            InfoRow(label: 'فشل اختبار الحياة', value: '${face.livenessFailed}', numeric: true),
            InfoRow(label: 'غير مسجَّل', value: '${face.notEnrolled}', numeric: true),
            InfoRow(
              label: 'متوسط الدرجة',
              value: face.avgScore?.toStringAsFixed(3) ?? '—',
              numeric: true,
            ),
            InfoRow(
              label: 'المدى',
              value: face.minScore == null
                  ? '—'
                  : '${face.minScore!.toStringAsFixed(3)} → ${face.maxScore!.toStringAsFixed(3)}',
              numeric: true,
            ),
            if (face.recentRejections.isNotEmpty) ...[
              const Divider(height: AppSpacing.s5),
              Text(
                'آخر المحاولات المرفوضة',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              ...face.recentRejections.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.employeeName ?? 'موظف #${r.employeeId}',
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${r.resultLabel} ${r.matchScore != null ? '(${r.matchScore!.toStringAsFixed(2)})' : ''}',
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SecurityCard extends StatelessWidget {
  final SecurityDiagnostics security;
  final int windowDays;

  const _SecurityCard({required this.security, required this.windowDays});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return PanelCard(
      title: 'الحماية والتزوير — آخر $windowDays يومًا',
      child: security.byReason.isEmpty
          ? Text(
              'لا توجد محاولات محجوبة أو مُعلَّمة.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            )
          : Column(
              children: [
                ...security.byReason.map(
                  (r) => InfoRow(
                    label: '${r.reasonLabel} — ${r.actionLabel}',
                    value: '${r.count}',
                    numeric: true,
                    valueColor: r.action == 'blocked' ? colors.error : colors.warning,
                  ),
                ),
                if (security.recent.isNotEmpty) ...[
                  const Divider(height: AppSpacing.s5),
                  ...security.recent.take(5).map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.employeeName ?? 'موظف #${e.employeeId}',
                                  style: const TextStyle(
                                    fontFamily: 'IBM Plex Sans Arabic',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Text(
                                '${e.reasonLabel} · ${relativeAge(e.createdAt)}',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 11,
                                  color: colors.textSecondary,
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
  }
}

class _WifiCard extends StatelessWidget {
  final List<BranchWifiCoverage> coverage;

  const _WifiCard({required this.coverage});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return PanelCard(
      title: 'شبكات الفروع',
      child: coverage.isEmpty
          ? Text(
              'لا توجد فروع.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            )
          : Column(
              children: coverage
                  .map(
                    (c) => InfoRow(
                      label: c.branchName ?? 'فرع #${c.branchId}',
                      value: c.networks == 0
                          ? 'لا توجد شبكات'
                          : '${c.approved} معتمدة من ${c.networks}'
                              '${c.hasPartialCoverage ? ' · ${c.pendingApproval} بانتظار الاعتماد' : ''}',
                      valueColor: c.hasPartialCoverage ? colors.warning : null,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _HardwareCard extends StatelessWidget {
  final List<TerminalDevice> devices;
  final List<KioskStation>? kiosks;

  const _HardwareCard({required this.devices, required this.kiosks});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final hasNothing = devices.isEmpty && (kiosks == null || kiosks!.isEmpty);

    return PanelCard(
      title: 'الأجهزة والأكشاك',
      child: hasNothing
          ? Text(
              'لا توجد أجهزة بصمة أو أكشاك لهذه الشركة.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...devices.map(
                  (d) => InfoRow(
                    label: '${d.name ?? d.serialNumber ?? 'جهاز'} (${d.branchName ?? '—'})',
                    value: 'ظهر ${relativeAge(d.lastSeenAt, never: 'لم يتصل')}',
                    valueColor: d.status == 'active' ? null : colors.textTertiary,
                  ),
                ),
                if (kiosks != null)
                  ...kiosks!.map(
                    (k) => InfoRow(
                      label: 'كشك ${k.name ?? k.id} (${k.branchName ?? '—'})',
                      value: 'ظهر ${relativeAge(k.lastSeenAt, never: 'لم يتصل')}',
                      valueColor: k.status == 'active' ? null : colors.textTertiary,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ChannelsCard extends StatelessWidget {
  final List<ChannelUsage> channels;
  final int windowDays;

  const _ChannelsCard({required this.channels, required this.windowDays});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final total = channels.fold<int>(0, (sum, c) => sum + c.count);

    return PanelCard(
      title: 'قنوات التسجيل — آخر $windowDays يومًا',
      child: channels.isEmpty
          ? Text(
              'لا يوجد حضور مسجّل في هذه الفترة.',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                color: colors.textSecondary,
              ),
            )
          : Column(
              children: channels
                  .map(
                    (c) => InfoRow(
                      label: c.label,
                      value: total > 0
                          ? '${c.count} (${((c.count / total) * 100).round()}%)'
                          : '${c.count}',
                      numeric: true,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
