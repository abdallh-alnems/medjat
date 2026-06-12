import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/routes/app_routes.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../logic/controller/station/station_controller.dart';
import 'widgets/method_card.dart';

class KioskHomeScreen extends StatelessWidget {
  const KioskHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StationController>();

    return Scaffold(
      body: SafeArea(
        child: PopScope(
          canPop: false,
          child: Column(
            children: [
              _buildAppBar(context, controller),
              Expanded(
                child: Obx(() {
                  if (controller.isLocked.value) {
                    return _buildLockedBanner(context);
                  }
                  return _buildCheckInOptions(context, controller);
                }),
              ),
              _buildLastCheckIn(context, controller),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, StationController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand(context).withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: AppColors.brand(context))),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor, color: AppColors.brand(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() => Text(
                  controller.station?.branchName ?? 'kiosk'.tr,
                  style: AppTextStyles.h3(context),
                )),
          ),
          IconButton(
            onPressed: () => Get.toNamed<void>(AppRoutes.kioskSettings),
            icon: Icon(Icons.settings, color: AppColors.brand(context)),
          ),
          TextButton.icon(
            onPressed: () => _showExitDialog(context, controller),
            icon: const Icon(Icons.logout, size: 18),
            label: Text('exit'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedBanner(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.red.shade700),
          const SizedBox(height: 16),
          Text('kiosk_locked'.tr, style: AppTextStyles.h2(context)),
          const SizedBox(height: 8),
          Text(
            'kiosk_locked_reason'.tr,
            style: AppTextStyles.bodySecondary(context),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInOptions(BuildContext context, StationController controller) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'choose_checkin_method'.tr,
            style: AppTextStyles.h2(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (controller.supportsFace) ...[
            MethodCard(
              icon: Icons.face,
              title: 'face_checkin'.tr,
              subtitle: 'face_checkin_desc'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.kioskFaceCheckIn),
            ),
            const SizedBox(height: 16),
          ],
          if (controller.supportsQr) ...[
            MethodCard(
              icon: Icons.qr_code_scanner,
              title: 'qr_checkin'.tr,
              subtitle: 'qr_checkin_desc'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.kioskQrCheckIn),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLastCheckIn(BuildContext context, StationController controller) {
    return Obx(() {
      final result = controller.lastCheckIn;
      if (result == null) return const SizedBox.shrink();

      final isIn = result.action == 'check_in';
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isIn ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isIn ? Colors.green.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isIn ? Icons.login : Icons.logout,
              color: isIn ? Colors.green.shade700 : Colors.orange.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result.employeeName,
                    style: AppTextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    isIn ? 'check_in_registered'.tr : 'check_out_registered'.tr,
                    style: AppTextStyles.sm(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showExitDialog(BuildContext context, StationController controller) {
    final pinController = TextEditingController();

    Get.dialog<void>(
      AlertDialog(
        title: Text('exit_kiosk'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('enter_admin_code'.tr),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'admin_code'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              Get.back<void>();
              controller.exitKiosk(pinController.text);
            },
            child: Text('exit'.tr, style: TextStyle(color: Colors.red.shade700)),
          ),
        ],
      ),
    );
  }
}
