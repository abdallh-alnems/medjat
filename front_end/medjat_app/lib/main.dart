import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:hive_flutter/hive_flutter.dart';
import 'core/constant/routes/app_routes.dart';
import 'core/constant/routes/app_pages.dart';
import 'core/constant/theme/theme.dart';
import 'core/constant/firebase_options.dart';
import 'core/class/crud.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/token_storage_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  final analytics = FirebaseAnalytics.instance;
  await analytics.setAnalyticsCollectionEnabled(true);

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(seconds: 10),
    minimumFetchInterval:
        kDebugMode ? Duration.zero : const Duration(hours: 1),
  ));
  await remoteConfig.setDefaults(const {
    'medjat_app_min_version': '0.0.0',
    'medjat_app_maintenance_enabled': false,
  });

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  CRUD.onSessionExpired = () {
    TokenStorageService.clearSession();
    Get.offAllNamed<void>(AppRoutes.login);
    Get.snackbar(
      'انتهت الجلسة',
      'يرجى تسجيل الدخول مجدداً',
      snackPosition: SnackPosition.BOTTOM,
    );
  };

  runApp(const MedjatEmployeeApp());
}

class MedjatEmployeeApp extends StatelessWidget {
  const MedjatEmployeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Medjat',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      getPages: getPages,
      initialBinding: AppBindings(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      textDirection: TextDirection.rtl,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: _AppWrapper(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

class _AppWrapper extends StatefulWidget {
  final Widget child;
  const _AppWrapper({required this.child});

  @override
  State<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<_AppWrapper> {
  @override
  void initState() {
    super.initState();
    PushNotificationService.init();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
