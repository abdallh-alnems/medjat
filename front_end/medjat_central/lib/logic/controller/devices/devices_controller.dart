import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/device_data/device_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/attendance_device_model.dart';
import '../../../data/model/branch_model.dart';

/// The list of fingerprint / face terminals, and everything done to a device
/// as a whole: registering it, moving it, disabling it, fixing its clock.
///
/// Linking User IDs to employees lives in DeviceUsersController — that is a
/// per-device job with its own screen.
class DevicesController extends GetxController {
  final DeviceData _deviceData = Get.find<DeviceData>();
  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  List<AttendanceDeviceModel> devices = [];
  List<BranchModel> branches = [];
  bool saving = false;

  int get pendingUsersTotal =>
      devices.fold(0, (sum, d) => sum + d.pendingUsers);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final results = await Future.wait([
      _deviceData.getDevices(),
      _branchData.getBranches(),
    ]);

    final deviceResponse = results[0];
    if (deviceResponse['status'] == StatusRequest.success) {
      final data = _unwrap(deviceResponse['data']);
      final list = data is Map ? data['devices'] : null;
      devices = list is List
          ? list
              .whereType<Map<dynamic, dynamic>>()
              .map((e) =>
                  AttendanceDeviceModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [];
      status = StatusRequest.success;
    } else {
      status = deviceResponse['status'] as StatusRequest;
    }

    final branchResponse = results[1];
    if (branchResponse['status'] == StatusRequest.success) {
      final data = _unwrap(branchResponse['data']);
      final list = data is Map ? data['branches'] : null;
      branches = list is List
          ? list
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => BranchModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [];
    }

    update();
  }

  /// Claims a terminal by serial number.
  ///
  /// Returns true on success. The caller shows the follow-up message, because
  /// the useful part is whether the device has actually reached the server yet
  /// — a correct serial on a device with no network still records nothing.
  Future<bool> register({
    required String serialNumber,
    required int branchId,
    String? name,
  }) async {
    if (serialNumber.trim().isEmpty || branchId <= 0) {
      return false;
    }

    saving = true;
    update();

    final response = await _deviceData.registerDevice(
      serialNumber: serialNumber.trim().toUpperCase(),
      branchId: branchId,
      name: name?.trim(),
    );

    saving = false;
    update();

    if (response['status'] != StatusRequest.success) {
      _failure(response);
      return false;
    }

    final data = _unwrap(response['data']);
    final connected = data is Map && data['has_contacted_server'] == true;
    final adopted =
        data is Map ? (data['adopted_punches'] as num?)?.toInt() ?? 0 : 0;

    await load();

    Get.snackbar(
      'done'.tr,
      connected
          ? (adopted > 0
              ? 'device_registered_with_punches'.trParams({'n': '$adopted'})
              : 'device_registered_online'.tr)
          : 'device_registered_offline'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 5),
    );
    return true;
  }

  Future<void> updateDevice({
    required int deviceId,
    String? name,
    int? branchId,
    String? status,
    String? directionMode,
    int? minIntervalSeconds,
    int? clockOffsetMinutes,
    bool? debugLogging,
  }) async {
    saving = true;
    update();

    final response = await _deviceData.updateDevice(
      deviceId: deviceId,
      name: name,
      branchId: branchId,
      status: status,
      directionMode: directionMode,
      minIntervalSeconds: minIntervalSeconds,
      clockOffsetMinutes: clockOffsetMinutes,
      debugLogging: debugLogging,
    );

    saving = false;

    if (response['status'] == StatusRequest.success) {
      await load();
      Get.snackbar('done'.tr, 'device_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      update();
      _failure(response);
    }
  }

  Future<void> release(int deviceId) async {
    final response = await _deviceData.releaseDevice(deviceId);
    if (response['status'] == StatusRequest.success) {
      await load();
      Get.snackbar('done'.tr, 'device_released'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      _failure(response);
    }
  }

  /// Commands are collected by the device on its next poll, not applied now.
  Future<void> sendCommand(int deviceId, String kind) async {
    final response = await _deviceData.sendCommand(
      deviceId: deviceId,
      kind: kind,
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'device_command_queued'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      _failure(response);
    }
  }

  /// Reads the "X minutes ago" line under each device.
  String lastSeenLabel(AttendanceDeviceModel device) {
    if (device.neverConnected) return 'device_never_connected'.tr;
    final seconds = device.secondsSinceSeen;
    if (seconds == null) return '—';
    if (seconds < 90) return 'device_seen_now'.tr;
    if (seconds < 3600) {
      return 'device_seen_minutes'.trParams({'n': '${seconds ~/ 60}'});
    }
    if (seconds < 86400) {
      return 'device_seen_hours'.trParams({'n': '${seconds ~/ 3600}'});
    }
    return 'device_seen_days'.trParams({'n': '${seconds ~/ 86400}'});
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) return data['data'];
    return data;
  }

  void _failure(Map<String, dynamic> response) {
    Get.snackbar(
      'error'.tr,
      (response['message'] as String?) ?? 'error'.tr,
      snackPosition: SnackPosition.BOTTOM,
      colorText: Get.theme.colorScheme.onErrorContainer,
      backgroundColor: Get.theme.colorScheme.errorContainer,
    );
  }
}
