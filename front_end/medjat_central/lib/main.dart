import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/constant/locale/translations.dart';
import 'core/constant/routes/app_pages.dart';
import 'core/constant/routes/app_routes.dart';
import 'core/constant/theme/theme.dart';
import 'core/services/initialization.dart';
import 'core/services/locale_service.dart';

void main() async {
  await initialServices();

  runApp(const MedjatCentralApp());
}

class MedjatCentralApp extends StatelessWidget {
  const MedjatCentralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Medjat Central',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      getPages: getPages,
      initialBinding: AppBindings(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      translations: AppTranslations(),
      locale: Get.find<LocaleService>().currentLocale,
      fallbackLocale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        CountryLocalizations.delegate,
      ],
      builder: (context, child) {
        final locale = Get.find<LocaleService>().currentLocale;
        return Directionality(
          textDirection:
              locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}