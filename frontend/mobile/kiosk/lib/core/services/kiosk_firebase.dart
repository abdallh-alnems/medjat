import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'firebase_ready.dart';

/// Re-ask the server. Called when a signal arrives saying something changed;
/// see [KioskFirebase.start].
typedef RemoteSignal = Future<void> Function();

/// Every Firebase service the kiosk uses, in one place.
///
/// The division of labour is deliberate and worth stating once, because it is
/// the thing that keeps two sources of truth from appearing:
///
/// * **The server decides.** `kiosk/heartbeat.php` is the only thing that puts
///   this tablet in or out of service — 401 revoked, 426 too old, 503
///   maintenance. Nothing in this file ever sets [KioskState] itself.
/// * **Firebase reports and nudges.** Crashlytics carries out what a wall
///   mounted tablet cannot tell anybody; Analytics counts branch-level usage;
///   Messaging and Remote Config only shorten the wait for the *next*
///   heartbeat from two minutes to now.
///
/// So a Firebase outage costs the kiosk nothing but visibility, and a device
/// with no Google Play services still works exactly as before.
class KioskFirebase {
  KioskFirebase._();

  /// Every call below reaches a Google server. On a tablet without Google Play
  /// services — a real possibility for the cheapest hardware with a front
  /// camera — they do not fail, they hang, and a `try`/`catch` cannot recover
  /// from a hang. Each step is bounded by this instead.
  static const Duration _gmsTimeout = Duration(seconds: 8);

  /// The topic `app/admin_app_control/set.php` publishes to when the kiosk's
  /// maintenance switch is flipped, named the same way as the other apps:
  /// `maintenance_<app key>`.
  static const String maintenanceTopic = 'maintenance_medjat_kiosk';

  static const String _minVersionKey = 'medjat_kiosk_min_version';
  static const String _maintenanceKey = 'medjat_kiosk_maintenance_enabled';

  static RemoteSignal? _onRemoteSignal;
  static StreamSubscription<RemoteConfigUpdate>? _rcSub;
  static StreamSubscription<RemoteMessage>? _fcmSub;

  /// Brings Firebase up. Call after the first frame and never `await` it from
  /// `main()` — see [_gmsTimeout].
  ///
  /// [onRemoteSignal] runs when Messaging or Remote Config reports that
  /// something changed server-side; it should call
  /// `KioskController.heartbeat()`, so the server still gets to be the one
  /// that answers.
  static Future<void> start({required RemoteSignal onRemoteSignal}) async {
    _onRemoteSignal = onRemoteSignal;

    try {
      // Android-only app: options come from android/app/google-services.json,
      // so there is no generated firebase_options.dart to keep in step.
      await Firebase.initializeApp().timeout(_gmsTimeout);
      FirebaseReady.complete(true);
    } catch (e, s) {
      debugPrint('Firebase.initializeApp failed (no Play services?): $e\n$s');
      FirebaseReady.complete(false);
      return;
    }

    try {
      await _initCrashlytics().timeout(_gmsTimeout);
    } catch (e, s) {
      debugPrint('Crashlytics init failed: $e\n$s');
    }

    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(!kDebugMode)
          .timeout(_gmsTimeout);
    } catch (e, s) {
      debugPrint('Analytics init failed: $e\n$s');
    }

    try {
      await _initRemoteConfig().timeout(_gmsTimeout);
    } catch (e, s) {
      debugPrint('Remote Config init failed: $e\n$s');
    }

    try {
      _initMessaging();
    } catch (e, s) {
      debugPrint('Messaging init failed: $e\n$s');
    }
  }

  /// Crash reporting. This is the reason the SDK is on the tablet at all: a
  /// kiosk crashes to a wall, and the report reaches a supervisor days later
  /// as "the tablet stopped working" with no logs and no adb cable.
  static Future<void> _initCrashlytics() async {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );

    // Anything the kiosk learned about itself before Firebase finished coming
    // up — device id, branch, station, state.
    _flushKeys();
  }

  /// Remote Config is read here only to receive the *realtime* update stream.
  /// The kiosk is permanently foregrounded, which is the one condition that
  /// makes `onConfigUpdated` a live wire, so a maintenance switch flipped in
  /// the admin panel reaches the tablet in seconds. The value itself is
  /// deliberately not acted on — the heartbeat asks the server, which reads
  /// the same parameters with a cache and a fail-open path
  /// (`RemoteConfigService::gateFor`).
  static Future<void> _initRemoteConfig() async {
    final rc = FirebaseRemoteConfig.instance;

    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval:
          kDebugMode ? Duration.zero : const Duration(hours: 1),
    ));
    await rc.setDefaults(const {
      _minVersionKey: '0.0.0',
      _maintenanceKey: false,
    });

    unawaited(rc.fetchAndActivate().catchError((Object e) {
      debugPrint('Remote Config fetch failed: $e');
      return false;
    }));

    unawaited(_rcSub?.cancel());
    _rcSub = rc.onConfigUpdated.listen((update) async {
      if (!update.updatedKeys.contains(_maintenanceKey) &&
          !update.updatedKeys.contains(_minVersionKey)) {
        return;
      }
      try {
        await rc.activate();
      } catch (e) {
        debugPrint('Remote Config activate failed: $e');
      }
      log('remote config changed: ${update.updatedKeys.join(', ')}');
      await _onRemoteSignal?.call();
    }, onError: (Object e) {
      debugPrint('Remote Config stream failed: $e');
    });
  }

  /// Data-only messages on [maintenanceTopic]. Nothing is ever displayed: a
  /// kiosk must not carry a notification an employee can pull down or tap out
  /// of, and the backend sends no `notification` payload
  /// (`NotificationService::sendToTopic`) for exactly that reason.
  ///
  /// There is no background handler on purpose. The kiosk is a foreground
  /// appliance, and a signal that arrives while it is not running is covered
  /// by the heartbeat it runs on the way back up.
  static void _initMessaging() {
    // Only completes once FCM has registered a token, which never happens
    // without Play services — fired, never awaited.
    unawaited(
      FirebaseMessaging.instance
          .subscribeToTopic(maintenanceTopic)
          .timeout(_gmsTimeout)
          .catchError((Object e) {
        debugPrint('subscribeToTopic failed: $e');
      }),
    );

    _fcmSub?.cancel();
    _fcmSub = FirebaseMessaging.onMessage.listen((message) async {
      if (message.data['type'] != 'maintenance_mode') return;
      log('maintenance signal received: ${message.data['enabled']}');
      await _onRemoteSignal?.call();
    });
  }

  // ---------------------------------------------------------------------
  // Reporting surface. All of it is a no-op when Firebase never came up.
  // ---------------------------------------------------------------------

  static bool get _ready => FirebaseReady.value == true;

  /// A breadcrumb attached to the next crash report. Cheap; use it wherever a
  /// `debugPrint` would otherwise be the only trace of what the tablet did.
  static void log(String message) {
    debugPrint('[kiosk] $message');
    if (!_ready) return;
    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (_) {
      // Never let telemetry break the door.
    }
  }

  /// A handled failure — the app carried on, but somebody should see it.
  static void recordError(Object error, StackTrace? stack, {String? reason}) {
    debugPrint('[kiosk] error${reason == null ? '' : ' ($reason)'}: $error');
    if (!_ready) return;
    try {
      unawaited(
        FirebaseCrashlytics.instance.recordError(error, stack, reason: reason),
      );
    } catch (_) {}
  }

  /// Identifies the *device*, never a person. Crashlytics reports from a fleet
  /// of identical tablets are unreadable without this: "which branch" is the
  /// first question asked about every one of them.
  static void setStation({
    String? deviceId,
    String? branchName,
    String? stationName,
  }) {
    if (deviceId != null && deviceId.isNotEmpty) {
      _userId = deviceId;
      _keys['kiosk_device_id'] = deviceId;
    }
    if (branchName != null && branchName.isNotEmpty) {
      _keys['kiosk_branch'] = branchName;
    }
    if (stationName != null && stationName.isNotEmpty) {
      _keys['kiosk_station'] = stationName;
    }
    _flushKeys();
  }

  /// The tablet's current lifecycle state, so a crash report says whether it
  /// happened while serving people or while out of service.
  static void setState(String state) {
    _keys['kiosk_state'] = state;
    _flushKeys();
  }

  /// The keys are collected whether or not Firebase is up.
  ///
  /// The kiosk pairs and heartbeats within a second of launch, while Firebase
  /// is still coming up behind the first frame — without this, the branch name
  /// would be missing from precisely the early crashes that are hardest to
  /// reproduce. They are held and re-applied once Crashlytics exists.
  static final Map<String, String> _keys = {};
  static String? _userId;

  static void _flushKeys() {
    if (!_ready) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      if (_userId != null) crashlytics.setUserIdentifier(_userId!);
      _keys.forEach(crashlytics.setCustomKey);
    } catch (_) {}
  }

  /// Branch-level usage only.
  ///
  /// Nothing identifying an employee is ever passed here — no name, no id, no
  /// photo, no embedding. The tablet holds none of that between interactions
  /// and must not start leaking it through analytics; "an identification
  /// succeeded at this station" is the whole of what is counted.
  static void logEvent(String name, [Map<String, Object>? parameters]) {
    if (!_ready) return;
    try {
      unawaited(
        FirebaseAnalytics.instance
            .logEvent(name: name, parameters: parameters)
            .catchError((Object e) => debugPrint('logEvent failed: $e')),
      );
    } catch (_) {}
  }
}
