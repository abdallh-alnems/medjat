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
                title: 'قيّمنا',
                message:
                    'أهلاً! نرغب في سماع رأيك حول تطبيقنا\n\nهل يمكنك قضاء بعض الوقت لتقييم التطبيق؟\n\nتعليقاتك مهمة جدًا بالنسبة لنا لتحسين تجربتك',
                rateButton: 'تقييم',
                noButton: 'لا شكرًا',
                laterButton: 'لاحقاً',
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
