import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/token_storage_service.dart';
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
        final msg = (response['message'] as String?) ?? 'فشل تفعيل الكيوسك';
        Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', 'حدث خطأ، حاول مرة أخرى',
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

  Future<void> checkInOut({
    required int employeeId,
    required String method,
    double? confidence,
    double? gpsLat,
    double? gpsLng,
  }) async {
    if (isLocked.value) {
      Get.snackbar('مقفل', 'الكيوسك مقفل، لا يمكن تسجيل الحضور',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      final response = await _stationData.checkInOut(
        employeeId: employeeId,
        method: method,
        confidence: confidence,
        gpsLat: gpsLat,
        gpsLng: gpsLng,
      );

      if (response['status'] == StatusRequest.success) {
        final data = response['data'] as Map<String, dynamic>?;
        if (data != null) {
          lastCheckIn = KioskCheckInResult.fromJson(data);
        }
        update();
      } else if (response['statusCode'] == 429) {
        Get.snackbar('تنبيه', 'تم التسجيل مسبقاً، حاول لاحقاً',
            snackPosition: SnackPosition.BOTTOM);
      } else if (response['statusCode'] == 403) {
        isLocked.value = true;
        Get.snackbar('مقفل', 'الكيوسك مقفل',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('خطأ', 'فشل تسجيل الحضور',
          snackPosition: SnackPosition.BOTTOM);
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
        final status = data?['status'] as String?;
        if (status == 'locked') {
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
      Get.snackbar('خطأ', 'رمز المدير غير صحيح',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  void onClose() {
    _heartbeatTimer?.cancel();
    super.onClose();
  }
}
