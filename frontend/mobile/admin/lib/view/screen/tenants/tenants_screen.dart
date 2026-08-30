import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/tenant_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/tenant/tenant_controller.dart';
import '../../../logic/controller/user/user_controller.dart' show ContactActions;
import '../shared/panel_widgets.dart';

/// The client list. A card answers three questions without opening anything:
/// how big is this company, is anyone still using it, and who do I call.
class TenantsScreen extends StatelessWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = Get.find<AuthController>().admin?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('الشركات')),
      body: GetBuilder<TenantController>(
        builder: (controller) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s3,
                  AppSpacing.s4,
                  0,
                ),
                child: Column(
                  children: [
                    PanelSearchField(
                      hint: 'ابحث باسم الشركة أو جهة الاتصال أو الهاتف',
                      onChanged: controller.onSearchChanged,
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      children: [
                        _FilterChip(
                          label: 'الكل',
                          selected: controller.statusFilter.value.isEmpty,
                          onTap: () => controller.setStatusFilter(''),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        _FilterChip(
                          label: 'نشطة',
                          selected: controller.statusFilter.value == 'active',
                          onTap: () => controller.setStatusFilter('active'),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        _FilterChip(
                          label: 'متوقفة',
                          selected: controller.statusFilter.value == 'inactive',
                          onTap: () => controller.setStatusFilter('inactive'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: controller.status.value,
                  onRetry: () => controller.loadTenants(),
                  widget: RefreshIndicator(
                    onRefresh: () => controller.loadTenants(),
                    child: controller.tenants.isEmpty
                        ? ListView(
                            children: const [
                              EmptyHint(message: 'لا توجد شركات مطابقة للبحث'),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              AppSpacing.s3,
                              AppSpacing.s4,
                              AppSpacing.s8,
                            ),
                            itemCount: controller.tenants.length + 1,
                            itemBuilder: (context, index) {
                              if (index == controller.tenants.length) {
                                return PagerBar(
                                  page: controller.currentPage.value,
                                  totalPages: controller.totalPages.value,
                                  total: controller.total.value,
                                  onPrevious: controller.previousPage,
                                  onNext: controller.nextPage,
                                );
                              }
                              return _TenantCard(tenant: controller.tenants[index]);
                            },
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      // Creating a company requires superadmin on the backend; showing the
      // button to anyone else only buys them a 403.
      floatingActionButton: isSuperAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showOnboardingSheet(context),
              icon: const Icon(Icons.add_business),
              label: const Text('شركة جديدة'),
            )
          : null,
    );
  }
}

/// Onboarding: the company plus the invitation that lets someone log into it.
void _showOnboardingSheet(BuildContext context) {
  final nameCtl = TextEditingController();
  final contactNameCtl = TextEditingController();
  final contactPhoneCtl = TextEditingController();
  final contactEmailCtl = TextEditingController();
  final ownerEmailCtl = TextEditingController();
  final notesCtl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final controller = Get.find<TenantController>();

  Get.bottomSheet<void>(
    SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSpacing.s4,
          right: AppSpacing.s4,
          top: AppSpacing.s4,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تشغيل عميل جديد',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'بريد المالك يُنشئ دعوة «مدير عام» تصله بالبريد — بدونها لن يستطيع أحد الدخول للشركة.',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: panelColors(context).textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'اسم الشركة *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: ownerEmailCtl,
                decoration: const InputDecoration(
                  labelText: 'بريد المالك (لدعوة المدير العام)',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return null;
                  return GetUtils.isEmail(value) ? null : 'بريد غير صالح';
                },
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: contactNameCtl,
                decoration: const InputDecoration(labelText: 'جهة الاتصال لدينا'),
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: contactPhoneCtl,
                decoration: const InputDecoration(
                  labelText: 'هاتف جهة الاتصال',
                  hintText: '+201000000000',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: contactEmailCtl,
                decoration: const InputDecoration(labelText: 'بريد جهة الاتصال'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return null;
                  return GetUtils.isEmail(value) ? null : 'بريد غير صالح';
                },
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: notesCtl,
                decoration: const InputDecoration(labelText: 'ملاحظات داخلية'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final created = await controller.createTenant(
                    name: nameCtl.text.trim(),
                    contactName: contactNameCtl.text,
                    contactPhone: contactPhoneCtl.text,
                    contactEmail: contactEmailCtl.text,
                    opsNotes: notesCtl.text,
                    ownerEmail: ownerEmailCtl.text,
                    ownerName: contactNameCtl.text,
                  );
                  if (!created) return;

                  Get.back<void>();
                  final invitation = controller.lastInvitation.value;
                  if (invitation != null) {
                    showInvitationDialog(invitation);
                  }
                },
                child: const Text('إنشاء الشركة'),
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
          ),
        ),
      ),
    ),
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    isScrollControlled: true,
  );
}

/// The invitation code is shown once and cannot be retrieved later, so it gets
/// a dialog with a copy button rather than a snackbar.
void showInvitationDialog(Map<String, dynamic> invitation) {
  final code = invitation['code'] as String? ?? '';
  final email = invitation['email'] as String? ?? '';
  final joinUrl = invitation['join_url'] as String? ?? '';

  Get.dialog<void>(
    AlertDialog(
      title: const Text('رمز الدعوة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أُرسلت دعوة إلى $email وصلاحيتها 72 ساعة.',
            style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.s4),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: joinUrl.isNotEmpty ? joinUrl : code));
            Get.back<void>();
            Get.snackbar('تم النسخ', 'يمكنك إرساله للعميل مباشرة',
                snackPosition: SnackPosition.BOTTOM);
          },
          child: const Text('نسخ الرابط'),
        ),
        TextButton(onPressed: () => Get.back<void>(), child: const Text('تم')),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : Colors.transparent,
          border: Border.all(color: selected ? colors.brand : colors.borderHairline),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  final TenantModel tenant;

  const _TenantCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);
    final phone = tenant.callablePhone;

    return PanelCard(
      onTap: () => Get.toNamed<void>(AppRoutes.tenantDetail, arguments: tenant.id),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusPill(
                text: tenant.isActiveTenant ? 'نشطة' : 'متوقفة',
                tone: tenant.isActiveTenant ? PillTone.success : PillTone.error,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              _MiniStat(value: '${tenant.employeeCount}', label: 'موظف'),
              const SizedBox(width: AppSpacing.s4),
              _MiniStat(value: '${tenant.branchCount}', label: 'فرع'),
              const SizedBox(width: AppSpacing.s4),
              _MiniStat(value: '${tenant.adminCount}', label: 'مدير'),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: colors.textTertiary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'آخر حضور: ${relativeAge(tenant.lastAttendanceDate, never: 'لم يبدأوا بعد')}',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (tenant.contactName != null || phone != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: colors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tenant.contactName ?? phone!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (phone != null) ...[
                  IconButton(
                    onPressed: () => ContactActions.call(phone),
                    icon: const Icon(Icons.phone, size: 18),
                    tooltip: 'اتصال',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => ContactActions.whatsapp(phone),
                    icon: const Icon(Icons.chat, size: 18),
                    tooltip: 'واتساب',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = panelColors(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 11,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
