import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rate_my_app/rate_my_app.dart';

class RateMyAppController extends GetxController {
  final RateMyApp rateMyApp = RateMyApp(
    minDays: 3,
    remindDays: 7,
    minLaunches: 7,
    remindLaunches: 10,
    appStoreIdentifier: '',
    googlePlayIdentifier: 'com.khawarizmie.medjat',
  );

  @override
  void onInit() {
    super.onInit();
    _showRateDialog();
  }

  void _showRateDialog() {
    rateMyApp.init().then((_) {
      if (rateMyApp.shouldOpenDialog) {
        final context = Get.context;
        if (context != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentContext = Get.context;
            if (currentContext != null && Navigator.canPop(currentContext)) {
              rateMyApp.showRateDialog(
                currentContext,
                title: 'rate_us'.tr,
                message: 'rate_us_message'.tr,
                rateButton: 'rate'.tr,
                noButton: 'no_thanks'.tr,
                laterButton: 'later'.tr,
                ignoreNativeDialog: true,
                onDismissed: () =>
                    rateMyApp.callEvent(RateMyAppEventType.laterButtonPressed),
              );
            }
          });
        }
      }
    });
  }

  void launchStore() {
    rateMyApp.launchStore();
  }
}
