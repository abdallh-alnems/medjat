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
    // --- Critical, GMS-free services (the UI cannot start without these) ---
    // Loaded first and individually guarded so that a device without Google
    // Mobile Services (e.g. Huawei) still reaches a usable UI instead of a
    // blank screen. See _initFirebase() for the GMS-dependent block.
    try {
      await dotenv.load();
    } catch (e, s) {
      debugPrint('dotenv.load failed: $e\n$s');
    }

    await Hive.initFlutter();
    await GetStorage.init();

    getStorage = GetStorage();
    Get.put<GetStorage>(getStorage, permanent: true);
    Get.put<LocaleService>(LocaleService(), permanent: true);
    Get.put<DarkLightService>(DarkLightService(), permanent: true);

    _initSessionExpiredHandler();

    // --- GMS-dependent services (Firebase + AdMob) ---
    // Wrapped so failures on GMS-less devices never abort startup.
    await _initFirebase();

    return this;
  }

  /// Initialize all Firebase + Google Mobile Ads services. Every step is
  /// individually guarded: on devices without Google Mobile Services these
  /// calls throw/hang, and a single failure must not prevent the app from
  /// launching. The app degrades gracefully (no push, analytics, or ads).
  Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, s) {
      // Without Firebase core, every dependent service below is unavailable.
      debugPrint('Firebase.initializeApp failed (GMS unavailable?): $e\n$s');
      _initAds();
      return;
    }

    try {
      await _initCrashlytics();
    } catch (e, s) {
      debugPrint('Crashlytics init failed: $e\n$s');
    }

    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    } catch (e, s) {
      debugPrint('Analytics init failed: $e\n$s');
    }

    try {
      await _initRemoteConfig();
    } catch (e, s) {
      debugPrint('Remote Config init failed: $e\n$s');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      await _initMaintenanceSignals();
    } catch (e, s) {
      debugPrint('Messaging init failed: $e\n$s');
    }

    _initAds();
  }

  /// Initialize the Google Mobile Ads SDK (banner + native ads shown app-wide).
  /// Fire-and-forget and guarded — AdMob also depends on GMS.
  void _initAds() {
    try {
      unawaited(MobileAds.instance.initialize());
    } catch (e, s) {
      debugPrint('MobileAds init failed: $e\n$s');
    }
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
