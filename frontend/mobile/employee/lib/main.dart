import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/constant/locale/translations.dart';
import 'core/constant/routes/app_pages.dart';
import 'core/constant/routes/app_routes.dart';
import 'core/constant/theme/theme.dart';
import 'core/services/initialization.dart';
import 'core/services/locale_service.dart';
import 'view/widget/ad/banner_ad_widget.dart';

void main() async {
  // initialServices() must stay free of network calls. Firebase and AdMob both
  // hang — rather than throw — on a device without Google Mobile Services (e.g.
  // Huawei) or on a network that cannot reach Google, so awaiting them here
  // would leave the app on a blank window forever. They start after the first
  // frame instead, and the app stays fully usable if they never finish.
  try {
    await initialServices();
  } catch (e, s) {
    debugPrint('initialServices failed: $e\n$s');
  }

  runApp(const PermedjatEmployeeApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(Get.find<MyServices>().initGmsServices());
  });
}

class PermedjatEmployeeApp extends StatelessWidget {
  const PermedjatEmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeService = Get.find<LocaleService>();

    return GetMaterialApp(
      title: 'Permedjat',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      getPages: getPages,
      initialBinding: AppBindings(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      translations: AppTranslations(),
      locale: localeService.currentLocale,
      fallbackLocale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final locale = Get.find<LocaleService>().currentLocale;
        return Directionality(
          textDirection:
              locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          // Host the app content above a persistent AdMob banner so the ad
          // appears on every screen across the app.
          child: Column(
            children: [
              Expanded(child: child ?? const SizedBox.shrink()),
              const BannerAdWidget(),
            ],
          ),
        );
      },
    );
  }
}