import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'core/constant/routes/app_routes.dart';
import 'core/constant/routes/app_pages.dart';
import 'core/constant/theme/theme.dart';
import 'core/constant/locale/translations.dart';
import 'core/services/locale_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  await GetStorage.init();
  Get.put<GetStorage>(GetStorage(), permanent: true);
  Get.put<LocaleService>(LocaleService(), permanent: true);

  await Firebase.initializeApp();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);

  final analytics = FirebaseAnalytics.instance;
  await analytics.setAnalyticsCollectionEnabled(true);

  FirebaseAnalytics.instance.logAppOpen();

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
  ));
  await remoteConfig.setDefaults(const {
    'min_required_version': '0.0.0',
    'maintenance_enabled': false,
  });

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

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
      themeMode: ThemeMode.system,
      translations: AppTranslations(),
      locale: Get.find<LocaleService>().currentLocale,
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
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
