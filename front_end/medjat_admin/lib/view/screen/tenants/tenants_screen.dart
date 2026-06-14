import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/tenant_model.dart';
import '../../../logic/controller/tenant/tenant_controller.dart';

class TenantsScreen extends StatelessWidget {
  const TenantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الشركات')),
      body: GetBuilder<TenantController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status.value,
            onRetry: () => controller.loadTenants(),
            widget: RefreshIndicator(
              onRefresh: () => controller.loadTenants(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                itemCount: controller.tenants.length,
                itemBuilder: (context, index) {
                  final tenant = controller.tenants[index];
                  return _TenantCard(
                    tenant: tenant,
                    onActivate: () => controller.activateTenant(tenant.id),
                    onDeactivate: () => controller.deactivateTenant(tenant.id),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final ownerNameCtl = TextEditingController();
    final ownerEmailCtl = TextEditingController();
    final ownerPhoneCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إنشاء شركة جديدة', style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'اسم الشركة'),
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: ownerNameCtl,
                decoration: const InputDecoration(labelText: 'اسم المالك'),
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: ownerEmailCtl,
                decoration: const InputDecoration(labelText: 'بريد المالك'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: ownerPhoneCtl,
                decoration: const InputDecoration(labelText: 'هاتف المالك'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final tenant = TenantModel(
                      id: 0,
                      name: nameCtl.text.trim(),
                      ownerName: ownerNameCtl.text.trim(),
                      ownerEmail: ownerEmailCtl.text.trim(),
                      ownerPhone: ownerPhoneCtl.text.trim(),
                      isActive: 1,
                    );
                    Get.find<TenantController>().createTenant(tenant);
                    Get.back<void>();
                  }
                },
                child: const Text('إنشاء'),
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
}

class _TenantCard extends StatelessWidget {
  final TenantModel tenant;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  const _TenantCard({
    required this.tenant,
    required this.onActivate,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderHairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tenant.isActiveTenant
                      ? colors.success.withValues(alpha: 0.1)
                      : colors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  tenant.isActiveTenant ? 'نشطة' : 'متوقفة',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: tenant.isActiveTenant ? colors.success : colors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          if (tenant.ownerName != null)
            Text('المالك: ${tenant.ownerName}', style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, color: colors.textSecondary)),
          if (tenant.ownerEmail != null)
            Text(tenant.ownerEmail!, style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: colors.textTertiary)),
          const SizedBox(height: AppSpacing.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!tenant.isActiveTenant)
                TextButton(
                  onPressed: onActivate,
                  child: const Text('تفعيل'),
                ),
              if (tenant.isActiveTenant)
                TextButton(
                  onPressed: onDeactivate,
                  style: TextButton.styleFrom(foregroundColor: colors.error),
                  child: const Text('إيقاف'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
