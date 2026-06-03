import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../core/services/location_service.dart';
import '../../../data/data_source/remote/station_data/station_data.dart';
import '../../../data/model/station_model.dart';

class StationController extends GetxController {
  final StationData _stationData = Get.find<StationData>();

  final status = StatusRequest.none.obs;
  Station? station;
  final employees = <BranchEmployee>[].obs;
  KioskCheckInResult? lastCheckIn;
  final isLocked = false.obs;
  String? lockedReason;
  Timer? _heartbeatTimer;

  final isProcessing = false.obs;
  final faceCheckInStatus = ''.obs;
  final qrCheckInStatus = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await TokenStorageService.getStationToken();
    if (token != null && token.isNotEmpty) {
      await syncStation();
      await loadRoster();
      _startHeartbeat();
    }
  }

  Future<void> activate(String qrPayload) async {
    status.value = StatusRequest.loading;
    update();

    try {
      final deviceId = await TokenStorageService.getOrCreateDeviceId();
      final response = await _stationData.activate(
        qrPayload: qrPayload,
        deviceInfo: {'device_id': deviceId},
      );

      if (response['status'] == StatusRequest.success) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data?['token'] != null) {
          await TokenStorageService.saveStationToken(data!['token'] as String);
        }
        if (data?['station'] != null) {
          station = Station.fromJson(
              data!['station'] as Map<String, dynamic>);
        }
        status.value = StatusRequest.success;
        await loadRoster();
        await syncStation();
        Get.offAllNamed<void>(AppRoutes.kioskHome);
        _startHeartbeat();
      } else {
        status.value = StatusRequest.failure;
        final msg = (response['message'] as String?) ?? 'failed_activate_kiosk'.tr;
        Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      status.value = StatusRequest.failure;
      Get.snackbar('error'.tr, 'error_try_again'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> loadRoster() async {
    try {
      final response = await _stationData.branchEmployees();
      if (response['status'] == StatusRequest.success) {
        final data = response['data'] as Map<String, dynamic>?;
        final items = data?['items'] as List<dynamic>? ?? [];
        employees.value =
            items.map((e) => BranchEmployee.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> syncStation() async {
    try {
      final response = await _stationData.syncData();
      if (response['status'] == StatusRequest.success) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data?['station'] != null) {
          station = Station.fromJson(data!['station'] as Map<String, dynamic>);
          isLocked.value = station!.isLocked;
          lockedReason = station!.lockedReason;
        }
      } else if (response['statusCode'] == 403) {
        isLocked.value = true;
      }
    } catch (_) {}
  }

  Future<Position?> _getCurrentGps() async {
    try {
      final locService = Get.find<LocationService>();
      return await locService.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> checkInOutFace({
    required int employeeId,
    required double confidence,
    String? capturedImageBase64,
  }) async {
    if (isLocked.value) {
      Get.snackbar('kiosk_locked'.tr, 'kiosk_locked_no_checkin'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final pos = await _getCurrentGps();

    try {
      final response = await _stationData.checkInOut(
        employeeId: employeeId,
        method: 'face',
        confidence: confidence,
        gpsLat: pos?.latitude,
        gpsLng: pos?.longitude,
        capturedImageBase64: capturedImageBase64,
      );

      _handleCheckInOutResponse(response);
    } catch (_) {
      Get.snackbar('error'.tr, 'failed_checkin'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> checkInOutQr({required String qrToken}) async {
    if (isLocked.value) {
      Get.snackbar('kiosk_locked'.tr, 'kiosk_locked_no_checkin'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final pos = await _getCurrentGps();

    try {
      final response = await _stationData.checkInOut(
        method: 'qr',
        qrToken: qrToken,
        gpsLat: pos?.latitude,
        gpsLng: pos?.longitude,
      );

      _handleCheckInOutResponse(response);
    } catch (_) {
      Get.snackbar('error'.tr, 'failed_checkin'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _handleCheckInOutResponse(Map<String, dynamic> response) {
    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        lastCheckIn = KioskCheckInResult.fromJson(data);
      }
      update();
    } else if (response['statusCode'] == 429) {
      Get.snackbar('kiosk'.tr, 'already_registered'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else if (response['statusCode'] == 403) {
      final msg = (response['message'] as String?) ?? 'out_of_range'.tr;
      Get.snackbar('kiosk'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    } else {
      final msg = (response['message'] as String?) ?? 'failed_checkin'.tr;
      Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> verifyAdminPin(String pin) async {
    try {
      final response = await _stationData.verifyAdminPin(pin: pin);
      if (response['status'] == StatusRequest.success) {
        final data = response['data'] as Map<String, dynamic>?;
        return data?['valid'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>?> matchFace(List<double> embedding) async {
    try {
      final response = await _stationData.matchFace(embedding: embedding);
      if (response['status'] == StatusRequest.success) {
        return response['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> enrollEmployeeFace({
    required String adminPin,
    required int employeeId,
    required List<double> embedding,
  }) async {
    await _stationData.enrollBiometric(
      adminPin: adminPin,
      employeeId: employeeId,
      faceEmbedding: embedding,
    );
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _doHeartbeat(),
    );
  }

  Future<void> _doHeartbeat() async {
    try {
      final response = await _stationData.heartbeat();
      if (response['status'] == StatusRequest.success) {
        final data = response['data'] as Map<String, dynamic>?;
        final hbStatus = data?['status'] as String?;
        if (hbStatus == 'locked') {
          isLocked.value = true;
          lockedReason = data?['reason'] as String?;
        } else {
          isLocked.value = false;
          lockedReason = null;
        }
      }
    } catch (_) {}
  }

  Future<void> exitKiosk(String pin) async {
    final valid = await verifyAdminPin(pin);
    if (valid) {
      _heartbeatTimer?.cancel();
      await TokenStorageService.clearStationToken();
      station = null;
      employees.clear();
      isLocked.value = false;
      Get.offAllNamed<void>(AppRoutes.login);
    } else {
      Get.snackbar('error'.tr, 'admin_code_wrong'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  bool get supportsFace =>
      station?.methods == 'face_only' || station?.methods == 'both';

  bool get supportsQr => true;

  @override
  void onClose() {
    _heartbeatTimer?.cancel();
    super.onClose();
  }
}
