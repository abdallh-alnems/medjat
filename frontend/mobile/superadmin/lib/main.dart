import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'core/constant/routes/app_routes.dart';
import 'core/constant/routes/app_pages.dart';
import 'core/constant/theme/theme.dart';

/// Whether Firebase actually came up. Everything Firebase-backed in this app
/// (push notifications, crash reporting) is optional at runtime and checks this
/// rather than assuming — the panel must still work if Firebase does not.
///
/// This was false in every build until 2026-08-06: the app had no
/// `android/app/google-services.json` and no `google-services` Gradle plugin,
/// so `Firebase.initializeApp()` threw and was swallowed below, which is why
/// support push notifications never actually arrived here. The Android app is
/// now registered in the `permedjat` Firebase project as
/// `com.khawarizmie.medjat_admin` and both Gradle plugins are applied.
bool firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  if (firebaseReady) {
    // Crash reporting: the panel is the tool used while a client is on the
    // phone, so a silent crash there is the worst kind.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]));

  runApp(const PermedjatAdminApp());
}

class PermedjatAdminApp extends StatelessWidget {
  const PermedjatAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Permedjat Admin',
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
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
