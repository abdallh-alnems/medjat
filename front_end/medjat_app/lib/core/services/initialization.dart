import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../class/crud.dart';
import '../constant/firebase_options.dart';
import '../constant/routes/app_routes.dart';
import '../widget/maintenance_gate.dart';
import 'locale_service.dart';
import 'dark_light_service.dart';
import 'token_storage_service.dart';

/// هل تحمل الرسالة إشارة تفعيل الصيانة؟ (enabled=='1'/'true')
bool _isMaintenanceEnabled(RemoteMessage message) {
  final e = message.data['enabled'];
  return e == '1' || e == 'true';
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // إشارة الصيانة والتطبيق في الخلفية/مغلق: خزّن العلم لتقرأه البوابة عند الفتح.
  if (message.data['type'] == 'maintenance_mode') {
    await GetStorage.init();
    await GetStorage().write(kPendingMaintenanceKey, _isMaintenanceEnabled(message));
  }
}

class MyServices extends GetxService {
  late GetStorage getStorage;

  Future<MyServices> init() async {
    await dotenv.load();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await Hive.initFlutter();
    await GetStorage.init();

    getStorage = GetStorage();
    Get.put<GetStorage>(getStorage, permanent: true);
    Get.put<LocaleService>(LocaleService(), permanent: true);
    Get.put<DarkLightService>(DarkLightService(), permanent: true);

    await _initCrashlytics();

    final analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);

    await _initRemoteConfig();

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initMaintenanceSignals();

    _initSessionExpiredHandler();

    // Initialize the Google Mobile Ads SDK (banner + native ads shown app-wide).
    unawaited(MobileAds.instance.initialize());

    return this;
  }

  /// Initialize Firebase Crashlytics for crash reporting.
  Future<void> _initCrashlytics() async {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  }

  /// Configure Firebase Remote Config (version gating + maintenance flag).
  Future<void> _initRemoteConfig() async {
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
  }

  /// اشترك في موضوع الصيانة واستقبل إشارات FCM الفورية. في المقدمة نطبّق الحالة
  /// مباشرةً عبر [MaintenanceGate.trigger]؛ وعند الفتح من إشعار نخزّن العلم لتقرأه
  /// البوابة. (حالة الخلفية/المغلق يعالجها معالج الخلفية.)
  Future<void> _initMaintenanceSignals() async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(kMaintenanceTopic);
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'maintenance_mode') {
        MaintenanceGate.trigger(_isMaintenanceEnabled(message));
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['type'] == 'maintenance_mode') {
        MaintenanceGate.trigger(_isMaintenanceEnabled(message));
      }
    });
  }

  /// Clear the local session and route to login when the API reports a 401.
  void _initSessionExpiredHandler() {
    CRUD.onSessionExpired = () {
      TokenStorageService.clearSession();
      Get.offAllNamed<void>(AppRoutes.login);
      Get.snackbar(
        'session_expired'.tr,
        'login_again'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    };
  }
}

Future<void> initialServices() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Get.putAsync(() => MyServices().init());

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}
