import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/services/kiosk_firebase.dart';
import 'core/theme/kiosk_theme.dart';
import 'logic/kiosk_controller.dart';
import 'view/identify_screen.dart';
import 'view/pairing_screen.dart';
import 'view/status_screen.dart';

/// The Medjat branch kiosk.
///
/// A separate application from the employee app — separate package, separate
/// release, separate permissions — sharing only the face pipeline through the
/// `medjat_shared` package, because both products must extract embeddings the
/// same way for the server to match them against one stored vector.
///
/// This app never signs anybody in. It holds a credential bound to a **branch**
/// and identifies employees one interaction at a time, against the server. It
/// stores nothing about them.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load();
  } catch (e) {
    // A missing .env means no API host, which the pairing screen reports
    // plainly. Throwing here instead would leave a blank window on a wall.
    debugPrint('dotenv.load failed: $e');
  }

  // Landscape is wrong for this: a standing person and a camera preview are
  // both portrait, and a wall mount is fixed.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Nothing on a kiosk should be reachable by swiping in from an edge.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MedjatKioskApp());

  // Firebase starts after the first frame and is never awaited. On a tablet
  // without Google Play services these calls hang rather than throw, and a
  // kiosk that shows a blank screen on a wall because a crash reporter could
  // not reach Google is a far worse outcome than having no crash reports.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(KioskFirebase.start(onRemoteSignal: () async {
      // A maintenance switch was flipped, or Remote Config changed. Ask the
      // server rather than deciding here — heartbeat is the only thing that
      // takes this tablet in or out of service.
      if (Get.isRegistered<KioskController>()) {
        await Get.find<KioskController>().heartbeat();
      }
    }));
  });
}

class MedjatKioskApp extends StatelessWidget {
  const MedjatKioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'مجات كيوسك',
      debugShowCheckedModeBanner: false,
      theme: KioskTheme.light(),
      darkTheme: KioskTheme.dark(),
      themeMode: ThemeMode.light,
      locale: const Locale('ar'),
      fallbackLocale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const KioskBootstrap(),
    );
  }
}

/// Routes the whole tablet on one piece of state.
///
/// Deliberately not a navigator. A kiosk has no back stack and no history: when
/// the server says this device is revoked or out of date, the identification
/// screen must not remain reachable underneath a dialog. Swapping the entire
/// body means there is nothing left behind to return to.
class KioskBootstrap extends StatelessWidget {
  const KioskBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final kiosk = Get.put(KioskController(), permanent: true);

    return Obx(() => switch (kiosk.state.value) {
          KioskState.ready => const IdentifyScreen(),
          KioskState.unpaired => const PairingScreen(),
          final blocked => StatusScreen(state: blocked),
        });
  }
}
