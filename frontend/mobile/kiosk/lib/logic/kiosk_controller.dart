import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api/kiosk_api.dart';
import '../core/kiosk_lock.dart';
import '../core/network/kiosk_crud.dart';
import '../core/network/kiosk_result.dart';
import '../core/services/kiosk_firebase.dart';
import '../core/storage/kiosk_token_store.dart';
import 'identify_controller.dart';

/// What the tablet is currently doing.
///
/// Four of these mean "out of service", and the shell routes on them rather
/// than letting each screen decide. A worker standing at a door must never see
/// a spinner that means nothing — every one of these states has a sentence
/// attached and, where it matters, tells them who to go to instead.
enum KioskState {
  starting,

  /// No credential yet. Waiting for a pairing code.
  unpaired,

  /// Ready to identify people.
  ready,

  /// Cannot reach the server. Records nothing, and says so (FR-024).
  offline,

  /// Below `permedjat_kiosk_min_version`. The message is for a supervisor —
  /// there is no store to send anyone to (FR-053).
  updateRequired,

  /// Maintenance mode is on for the kiosk app.
  maintenance,
}

/// Owns the tablet's lifecycle: pair, heartbeat, and route.
class KioskController extends GetxController {
  KioskController({KioskCrud? crud}) : _crud = crud ?? KioskCrud();

  final KioskCrud _crud;

  final Rx<KioskState> state = KioskState.starting.obs;
  final RxString message = ''.obs;
  final RxString branchName = ''.obs;
  final RxString stationName = ''.obs;

  /// Branch settings, refreshed on every heartbeat so a change made in the
  /// management app reaches the tablet without anybody touching it.
  final Rx<Map<String, dynamic>> settings = Rx<Map<String, dynamic>>({});

  Timer? _heartbeat;
  String _appVersion = '0.0.0';

  bool get codeFallbackEnabled => settings.value['code_fallback_enabled'] == true;
  bool get livenessRequired => settings.value['liveness_required'] == true;

  @override
  void onInit() {
    super.onInit();

    // Every crash report from this tablet carries the state it was in. Reported
    // from one place rather than at each assignment, so a state added later
    // cannot be forgotten here.
    ever(state, (KioskState s) {
      KioskFirebase.setState(s.name);
      KioskFirebase.log('state -> ${s.name}');
    });

    bootstrap();
  }

  @override
  void onClose() {
    _heartbeat?.cancel();
    _crud.dispose();
    super.onClose();
  }

  Future<void> bootstrap() async {
    state.value = KioskState.starting;

    final info = await PackageInfo.fromPlatform();
    _appVersion = info.version;

    // Identifies the device, never a person. A fleet of identical tablets
    // produces identical crash reports without it, and "which branch?" is the
    // first question asked about every one of them.
    KioskFirebase.setStation(
      deviceId: await KioskTokenStore.getOrCreateDeviceId(),
    );

    if (!await KioskTokenStore.hasToken()) {
      state.value = KioskState.unpaired;
      return;
    }

    await heartbeat();
    _startHeartbeatTimer();
  }

  /// Every two minutes. Frequent enough that a revoked or outdated tablet stops
  /// serving people quickly, and that the dark-kiosk alert (which reads
  /// `last_seen_at`) fires on a real outage rather than on a quiet afternoon.
  void _startHeartbeatTimer() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(minutes: 2), (_) => heartbeat());
  }

  Future<void> heartbeat() async {
    final result = await _crud.post(KioskApi.heartbeat, {'app_version': _appVersion});

    switch (result.status) {
      case KioskStatus.success:
        final data = result.data;
        branchName.value = (data['branch']?['name'] ?? '') as String;
        stationName.value = (data['station']?['name'] ?? '') as String;
        settings.value =
            Map<String, dynamic>.from(data['settings'] as Map? ?? <String, dynamic>{});
        message.value = '';
        state.value = KioskState.ready;

        KioskFirebase.setStation(
          branchName: branchName.value,
          stationName: stationName.value,
        );

        // Pin once the tablet is genuinely in service. Doing it earlier would
        // trap a supervisor on the pairing screen of a device that turned out
        // to be revoked.
        unawaited(KioskLock.enter());

        // Coming back from an outage: replay any punch whose outcome was never
        // learned, using the key it was first sent with. The server recognises
        // the key and returns the original result, so a punch that did land is
        // not made twice.
        if (Get.isRegistered<IdentifyController>()) {
          final identify = Get.find<IdentifyController>();
          if (identify.hasPendingPunch) {
            unawaited(identify.retryPendingPunch());
          }
        }

      case KioskStatus.unauthorised:
        // Revoked or unpaired. Wipe the credential — leaving it would let a
        // stolen tablet keep retrying with a token that still exists on disk.
        await KioskTokenStore.clearToken();
        message.value = result.messageKey ?? '';
        state.value = KioskState.unpaired;

      case KioskStatus.updateRequired:
        message.value = result.messageKey ?? '';
        state.value = KioskState.updateRequired;

      case KioskStatus.maintenance:
        message.value = result.messageKey ?? '';
        state.value = KioskState.maintenance;

      case KioskStatus.offline:
        message.value = result.messageKey ?? '';
        state.value = KioskState.offline;

      default:
        // Anything else is treated as offline: from the point of view of the
        // person at the door, a server that answers nonsense and a server that
        // does not answer are the same thing. It is still recorded as a handled
        // error — the tablet coping with it silently is how a broken deploy
        // stays invisible for a week.
        KioskFirebase.recordError(
          StateError('unexpected heartbeat status: ${result.status.name}'),
          StackTrace.current,
          reason: 'heartbeat',
        );
        state.value = KioskState.offline;
    }
  }

  /// Redeems a pairing code. Returns null on success, or a message key.
  Future<String?> pair(String code) async {
    final deviceId = await KioskTokenStore.getOrCreateDeviceId();

    String? model;
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      model = '${android.manufacturer} ${android.model}';
    } catch (_) {
      // A tablet that will not report its model is still a usable kiosk.
    }

    final result = await _crud.post(
      KioskApi.pair,
      {
        'code': code.trim().toUpperCase(),
        'device_id': deviceId,
        'device_model': model,
        'app_version': _appVersion,
        'platform': 'android',
      },
      authenticated: false, // The code IS the credential; no token exists yet.
    );

    if (!result.isSuccess) {
      return result.messageKey ?? 'kiosk_pair_code_spent';
    }

    final token = result.data['kiosk_token'] as String?;
    if (token == null || token.isEmpty) {
      return 'kiosk_pair_code_spent';
    }

    await KioskTokenStore.saveToken(token);

    branchName.value = (result.data['branch']?['name'] ?? '') as String;
    stationName.value = (result.data['station']?['name'] ?? '') as String;

    // Pairing happens once per tablet, by a supervisor. Worth one event: it is
    // the only way to see a branch installing a kiosk without asking them.
    KioskFirebase.logEvent('kiosk_paired');
    KioskFirebase.setStation(
      branchName: branchName.value,
      stationName: stationName.value,
    );

    await heartbeat();
    _startHeartbeatTimer();
    return null;
  }

  /// Called when any screen sees a blocking result, so one refusal anywhere
  /// takes the whole tablet out of service rather than only that screen.
  void applyBlocking(KioskResult result) {
    switch (result.status) {
      case KioskStatus.unauthorised:
        KioskTokenStore.clearToken();
        state.value = KioskState.unpaired;
      case KioskStatus.updateRequired:
        state.value = KioskState.updateRequired;
      case KioskStatus.maintenance:
        state.value = KioskState.maintenance;
      case KioskStatus.offline:
        state.value = KioskState.offline;
      default:
        return;
    }
    message.value = result.messageKey ?? '';
  }
}
