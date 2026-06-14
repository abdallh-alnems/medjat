import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/app_control_model.dart';
import '../../../logic/controller/app_control/app_control_controller.dart';

class AppControlScreen extends StatelessWidget {
  const AppControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('التحكم بالتطبيقات'),
      ),
      body: GetBuilder<AppControlController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: () => controller.loadApps(),
            color: colors.brand,
            child: HandlingDataRequest(
              statusRequest: controller.status.value,
              onRetry: () => controller.loadApps(),
              widget: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.s4),
                itemCount: controller.apps.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s3),
                itemBuilder: (context, index) {
                  return _AppCard(app: controller.apps[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final AppControlModel app;

  const _AppCard({required this.app});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Card(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: colors.borderHairline),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _appIcon(app.key),
                  color: colors.brand,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    app.name,
                    style: AppTextStyles.h3(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s3),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s3),
            _VersionRow(app: app),
            if (app.supportsMaintenance) ...[
              const SizedBox(height: AppSpacing.s3),
              _MaintenanceRow(app: app),
            ],
          ],
        ),
      ),
    );
  }

  IconData _appIcon(String key) {
    switch (key) {
      case 'medjat_app':
        return Icons.person;
      case 'medjat_central':
        return Icons.business_center;
      case 'medjat_admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.phone_android;
    }
  }
}

class _VersionRow extends StatelessWidget {
  final AppControlModel app;

  const _VersionRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;
    final controller = Get.find<AppControlController>();

    return Obx(() {
      final isEditing = controller.editingApp.value == app.key;

      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإصدار الأدنى',
                  style: AppTextStyles.sm(context),
                ),
                const SizedBox(height: 4),
                if (isEditing)
                  TextField(
                    controller: TextEditingController(text: controller.versionInput.value)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.versionInput.value.length),
                      ),
                    onChanged: (v) => controller.versionInput.value = v,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'مثال: 1.2.0',
                      hintStyle: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        color: colors.textTertiary,
                      ),
                      filled: true,
                      fillColor: colors.canvas,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(color: colors.borderHairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(color: colors.borderHairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide(color: colors.brand),
                      ),
                      errorText: controller.versionErrors.isNotEmpty
                          ? controller.versionErrors.first
                          : null,
                    ),
                    style: const TextStyle(fontFamily: 'Geist', fontSize: 16),
                  )
                else
                  Text(
                    app.minVersion == '0.0.0' || app.minVersion.isEmpty
                        ? 'غير محدد'
                        : app.minVersion,
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          if (isEditing) ...[
            IconButton(
              onPressed: () => controller.cancelEditing(),
              icon: Icon(Icons.close, color: colors.error),
            ),
            IconButton.filled(
              onPressed: () => _confirmSaveVersion(context, controller, app),
              icon: const Icon(Icons.check),
            ),
          ] else
            IconButton.outlined(
              onPressed: () => controller.startEditing(app.key, app.minVersion),
              icon: const Icon(Icons.edit, size: 20),
            ),
        ],
      );
    });
  }

  void _confirmSaveVersion(
    BuildContext context,
    AppControlController controller,
    AppControlModel app,
  ) {
    final newVersion = controller.versionInput.value.trim();
    final currentVersion = app.minVersion;

    if (newVersion.isEmpty || !controller.isValidVersion(newVersion)) {
      controller.versionErrors.value = ['صيغة الإصدار غير صحيحة'];
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تغيير الإصدار'),
        content: Text(
          'سيتم تغيير الإصدار الأدنى لتطبيق "${app.name}" من $currentVersion إلى $newVersion. '
          'المستخدمون بإصدار أقدم سيُجبرون على التحديث.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.saveVersion(app.key);
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceRow extends StatelessWidget {
  final AppControlModel app;

  const _MaintenanceRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;
    final controller = Get.find<AppControlController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'وضع الصيانة',
              style: AppTextStyles.sm(context),
            ),
            const SizedBox(height: 2),
            Text(
              app.maintenance == true ? 'مفعّل — التطبيق متوقف' : 'معطّل',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: app.maintenance == true ? colors.error : colors.success,
              ),
            ),
          ],
        ),
        Obx(() {
          final currentApp = controller.apps.firstWhereOrNull((a) => a.key == app.key);
          final isEnabled = currentApp?.maintenance ?? app.maintenance ?? false;

          return Switch.adaptive(
            value: isEnabled,
            activeTrackColor: colors.error,
            onChanged: (value) {
              _confirmAndToggle(context, controller, value);
            },
          );
        }),
      ],
    );
  }

  void _confirmAndToggle(
    BuildContext context,
    AppControlController controller,
    bool newValue,
  ) {
    if (newValue) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد تفعيل الصيانة'),
          content: Text(
            'سيتم إيقاف تطبيق "${app.name}" للمستخدمين. هل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.toggleMaintenance(app.key, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('تفعيل'),
            ),
          ],
        ),
      );
    } else {
      controller.toggleMaintenance(app.key, false);
    }
  }
}
