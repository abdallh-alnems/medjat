import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../core/class/api_messages.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/device_integrity_service.dart';
import '../../../core/services/local_biometric_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/network_service.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/model/face_proof_model.dart';
import '../../../data/model/today_status_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../home/home_controller.dart';

class AttendanceController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();

  StatusRequest status = StatusRequest.none;
  bool isProcessing = false;
  String? errorMessage;

  Future<void> processQrScan(String qrCode) => _process(qrCode: qrCode);

  /// GPS-only check-in / check-out: no QR scan. The backend resolves the
  /// method from the (absent) QR code and validates the branch configuration.
  Future<void> processGpsCheck() => _process();

  /// Selfie check-in / check-out. The proof carries the on-device embedding
  /// plus the server's single-use nonce; the server does the matching.
  Future<void> processFaceCheck(FaceProof proof) => _process(faceProof: proof);

  /// WiFi check-in: the employee must be on one of the branch's approved
  /// access points, on top of the usual geofence check.
  Future<void> processWifiCheck() => _process(wifiMethod: true);

  Future<void> _process({
    String? qrCode,
    FaceProof? faceProof,
    bool wifiMethod = false,
  }) async {
    if (isProcessing) return;
    isProcessing = true;
    status = StatusRequest.loading;
    errorMessage = null;
    update();

    try {
      final position = await LocationService().getCurrentPosition();
      final homeController = Get.find<HomeController>();

      // --- device integrity check ---
      final integrity = await DeviceIntegrityService.check(position);
      if (integrity.isBlocking) {
        errorMessage = integrity.isMockLocation
            ? 'mock_location_detected'.tr
            : 'rooted_device_detected'.tr;
        status = StatusRequest.failure;
        unawaited(_attendanceData.reportSecurityBlock(
          branchId: homeController.todayStatus?.branchId ?? _getBranchId() ?? 0,
          reason: integrity.isMockLocation ? 'mock_location' : 'rooted',
          latitude: position.latitude,
          longitude: position.longitude,
        ));
        isProcessing = false;
        update();
        return;
      }

      if (integrity.isVpn) {
        errorMessage = 'vpn_blocked_title'.tr;
        status = StatusRequest.failure;
        unawaited(_attendanceData.reportSecurityBlock(
          branchId: homeController.todayStatus?.branchId ?? _getBranchId() ?? 0,
          reason: 'vpn',
          latitude: position.latitude,
          longitude: position.longitude,
        ));
        isProcessing = false;
        update();
        return;
      }

      // --- device-biometric gate ---
      // Runs after the integrity checks so a device that is going to be blocked
      // anyway never raises a prompt, and before the online/offline split so a
      // queued offline punch is gated at capture time too. The server enforces
      // this independently; failing here only saves the employee from doing the
      // whole check-in and being refused at the end.
      var localBiometric = false;
      if (homeController.attendanceConfig.requireLocalBiometric) {
        final gate = await LocalBiometricService.authenticate(
          'local_biometric_reason'.tr,
        );
        localBiometric = gate.passed;
        if (!gate.passed) {
          errorMessage = gate.outcome == LocalBiometricOutcome.unavailable
              ? 'local_biometric_unavailable'.tr
              : 'local_biometric_failed'.tr;
          status = StatusRequest.failure;
          unawaited(_attendanceData.reportSecurityBlock(
            branchId: homeController.todayStatus?.branchId ?? _getBranchId() ?? 0,
            reason: 'no_local_biometric',
            latitude: position.latitude,
            longitude: position.longitude,
          ));
          isProcessing = false;
          update();
          return;
        }
      }

      final isCheckOut =
          homeController.attendanceStatus == AttendanceStatus.checkedIn;

      final isOnline = await ConnectivityService.checkOnline();

      // Read the WiFi network on every online check-in, not just the wifi_gps
      // method: this is what populates a branch's access-point list during its
      // learning phase, before anyone switches enforcement on.
      final wifi = await NetworkService.current();

      if (isOnline) {
        await _processOnline(qrCode, position, isCheckOut,
            isVpn: integrity.isVpn,
            isMockLocation: integrity.isMockLocation,
            faceProof: faceProof,
            wifi: wifi,
            wifiMethod: wifiMethod,
            localBiometric: localBiometric);
      } else if (faceProof != null) {
        // Face verification is server-side by design, so it cannot be queued
        // offline — the device has nothing to verify against.
        errorMessage = 'face_requires_connection'.tr;
        status = StatusRequest.failure;
      } else {
        await _processOffline(qrCode, position, isCheckOut,
            isVpn: integrity.isVpn, isMockLocation: integrity.isMockLocation);
      }
    } catch (e) {
      errorMessage = 'error_try_again'.tr;
      status = StatusRequest.failure;
    }

    isProcessing = false;
    update();
  }

  Future<void> _processOnline(
      String? qrCode, Position position, bool isCheckOut,
      {bool isVpn = false,
      bool isMockLocation = false,
      FaceProof? faceProof,
      WifiInfo? wifi,
      bool wifiMethod = false,
      bool localBiometric = false}) async {
    final homeController = Get.find<HomeController>();

    // The integrity flags are reported even though this app already refuses to
    // reach here with a mocked location: that refusal runs on the employee's
    // own device, so the server has to be able to make the call itself.
    final response = isCheckOut
        ? await _attendanceData.checkOut(
            faceProof: faceProof,
            wifi: wifi,
            wifiMethod: wifiMethod,
            isMockLocation: isMockLocation,
            latitude: position.latitude,
            longitude: position.longitude,
            localBiometric: localBiometric,
          )
        : await _attendanceData.checkIn(
            branchId: homeController.todayStatus?.branchId ??
                _getBranchId() ??
                0,
            latitude: position.latitude,
            longitude: position.longitude,
            qrCode: qrCode,
            isVpn: isVpn,
            isMockLocation: isMockLocation,
            faceProof: faceProof,
            wifi: wifi,
            wifiMethod: wifiMethod,
            localBiometric: localBiometric,
          );

    final responseStatus = response['status'];

    if (responseStatus == StatusRequest.success) {
      status = StatusRequest.success;
      // Refresh today's status before leaving the screen, but never let a
      // failure here turn an already-successful check-in into an error.
      try {
        await homeController.loadTodayStatus();
      } catch (_) {}
      _goHomeWithSuccess(isCheckOut: isCheckOut);
      return;
    } else if (responseStatus == StatusRequest.offline) {
      await _processOffline(qrCode, position, isCheckOut,
          isVpn: isVpn, isMockLocation: isMockLocation);
    } else {
      final statusCode = response['statusCode'];
      if (statusCode == 409) {
        // The backend signals an existing record via the 409 status alone.
        errorMessage = 'already_checked_in'.tr;
      } else {
        // Every other check-in failure carries a machine-readable error_code
        // (LOCATION_REQUIRED, GPS_OUT_OF_RANGE, INVALID_QR, …) which we
        // translate to the user's language instead of the raw server text.
        errorMessage = ApiMessages.of(response);
      }
      status = StatusRequest.failure;
    }
    update();
  }

  Future<void> _processOffline(
      String? qrCode, Position position, bool isCheckOut,
      {bool isVpn = false, bool isMockLocation = false}) async {
    final homeController = Get.find<HomeController>();
    final branch = homeController.todayStatus;

    if (branch != null &&
        branch.branchLat != null &&
        branch.branchLng != null &&
        branch.branchRadiusMeters != null) {
      final distance = LocationService.distanceBetween(
        position.latitude,
        position.longitude,
        branch.branchLat!,
        branch.branchLng!,
      );
      if (distance > branch.branchRadiusMeters!) {
        errorMessage = 'out_of_range'.tr;
        status = StatusRequest.failure;
        update();
        return;
      }
    }

    await _saveOfflineRecord(
      qrCode: qrCode,
      position: position,
      isCheckOut: isCheckOut,
      isVpn: isVpn,
      isMockLocation: isMockLocation,
    );

    status = StatusRequest.success;
    _goHomeWithSuccess(isCheckOut: isCheckOut, offline: true);
  }

  /// On a successful check-in / check-out, return to the home screen and
  /// surface a success message there — rather than a separate success screen.
  void _goHomeWithSuccess({required bool isCheckOut, bool offline = false}) {
    update();
    // Pop back to the home route that's already in the stack (check-in was
    // opened from home). Do NOT use offAllNamed — that disposes shared
    // data-source bindings (PayrollData, NotificationData, …) registered by
    // earlier routes and breaks other screens.
    Get.until((route) => route.settings.name == AppRoutes.home);
    final message = offline
        ? 'will_sync_online'.tr
        : (isCheckOut ? 'check_out_success'.tr : 'check_in_success'.tr);
    Get.snackbar(
      'success'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _saveOfflineRecord({
    required String? qrCode,
    required Position position,
    required bool isCheckOut,
    bool isVpn = false,
    bool isMockLocation = false,
  }) async {
    final box = await Hive.openBox<dynamic>('offline_attendance');
    final branchId = _getBranchId() ?? 0;
    final now = DateTime.now();

    final existingIndex = box.values.toList().indexWhere((r) {
      final recordDate = (r as Map)['date'] as String?;
      return recordDate == now.toIso8601String().substring(0, 10);
    });

    final record = {
      'client_record_id': now.millisecondsSinceEpoch.toString(),
      'branch_id': branchId,
      'date': now.toIso8601String().substring(0, 10),
      'captured_at': now.toIso8601String(),
      'qr_code': qrCode ?? '',
      'is_vpn': isVpn ? 1 : 0,
      // Carried into the queue so sync_offline can reject a spoofed location on
      // the server. Without it the backend's mock-location check was unreachable
      // — the queued record simply never had the field.
      'is_mock_location': isMockLocation ? 1 : 0,
      'check_in_latitude': position.latitude,
      'check_in_longitude': position.longitude,
      if (!isCheckOut) 'check_in_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      if (isCheckOut) 'check_out_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
    };

    if (existingIndex >= 0) {
      await box.putAt(existingIndex, record);
    } else {
      await box.add(record);
    }
  }

  Future<void> syncOfflineRecords() async {
    final box = await Hive.openBox<dynamic>('offline_attendance');
    if (box.isEmpty) return;

    final records = box.values.map((r) => Map<String, dynamic>.from(r as Map)).toList();

    final response = await _attendanceData.syncOffline(records);
    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      final results = (data?['results'] as List<dynamic>?) ?? [];
      final syncedIds = <String>{};
      for (final r in results) {
        if (r is Map<String, dynamic> && r['status'] == 'synced') {
          final id = r['client_record_id']?.toString();
          if (id != null) syncedIds.add(id);
        }
      }
      if (syncedIds.isNotEmpty) {
        final keysToDelete = <dynamic>[];
        for (int i = 0; i < box.length; i++) {
          final record = box.getAt(i);
          if (record is Map && syncedIds.contains(record['client_record_id']?.toString())) {
            keysToDelete.add(box.keyAt(i));
          }
        }
        for (final key in keysToDelete) {
          await box.delete(key);
        }
      }
    }
  }

  int? _getBranchId() {
    try {
      final authController = Get.find<AuthController>();
      return authController.user?.branchId;
    } catch (_) {
      return null;
    }
  }

  void showError(String message) {
    errorMessage = message;
    status = StatusRequest.failure;
    update();
  }

  void reset() {
    status = StatusRequest.none;
    isProcessing = false;
    errorMessage = null;
    update();
  }
}
