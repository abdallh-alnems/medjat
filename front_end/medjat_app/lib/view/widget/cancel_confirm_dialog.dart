import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constant/theme/app_colors.dart';

void showCancelConfirmDialog(BuildContext context, VoidCallback onConfirm) {
  Get.dialog<void>(
    Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text('cancel_request'.tr),
        content: Text('cancel_request_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('no'.tr),
          ),
          TextButton(
            onPressed: () {
              Get.back<void>();
              onConfirm();
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.of(context).error),
            child: Text('yes'.tr),
          ),
        ],
      ),
    ),
  );
}
