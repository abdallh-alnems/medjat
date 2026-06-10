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

  runApp(const MedjatEmployeeApp());
}

class MedjatEmployeeApp extends StatelessWidget {
  const MedjatEmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeService = Get.find<LocaleService>();

    return GetMaterialApp(
      title: 'Medjat',
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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}