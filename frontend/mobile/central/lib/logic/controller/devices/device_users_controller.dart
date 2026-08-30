import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/device_data/device_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/attendance_device_model.dart';
import '../../../data/model/employee_model.dart';

/// One device's User IDs and its raw punch feed.
///
/// The whole setup task after a terminal is mounted is: enrol people on the
/// device, then say who each User ID is. That list is the screen, and it is
/// done when nothing is left unlinked.
class DeviceUsersController extends GetxController {
  DeviceUsersController(this.deviceId, this.deviceLabel);

  final int deviceId;
  final String deviceLabel;

  final DeviceData _deviceData = Get.find<DeviceData>();
  final EmployeeData _employeeData = Get.find<EmployeeData>();

  StatusRequest status = StatusRequest.none;
  List<DeviceUserModel> users = [];
  List<DevicePunchModel> punches = [];
  List<EmployeeModel> employees = [];
  Map<String, int> punchStats = const {};
  bool linking = false;
  int tab = 0; // 0 = users, 1 = punches

  List<DeviceUserModel> get pending => users.where((u) => !u.isLinked).toList();
  List<DeviceUserModel> get linked => users.where((u) => u.isLinked).toList();

  /// Employees not already claimed by another User ID on this device.
  List<EmployeeModel> availableEmployees(int? keepEmployeeId) {
    final taken = users
        .where((u) => u.isLinked && u.employeeId != keepEmployeeId)
        .map((u) => u.employeeId)
        .toSet();
    return employees.where((e) => !taken.contains(e.id)).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void setTab(int index) {
    tab = index;
    update();
    if (index == 1 && punches.isEmpty) {
      loadPunches();
    }
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final results = await Future.wait([
      _deviceData.getDeviceUsers(deviceId),
      _employeeData.getEmployees(status: 'active', limit: 500),
    ]);

    final userResponse = results[0];
    if (userResponse['status'] == StatusRequest.success) {
      final data = _unwrap(userResponse['data']);
      final list = data is Map ? data['users'] : null;
      users = list is List
          ? list
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => DeviceUserModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [];
      final stats = data is Map ? data['punch_stats'] : null;
      punchStats = stats is Map
          ? stats.map((k, v) =>
              MapEntry(k.toString(), (v as num?)?.toInt() ?? 0))
          : const {};
      status = StatusRequest.success;
    } else {
      status = userResponse['status'] as StatusRequest;
    }

    final employeeResponse = results[1];
    if (employeeResponse['status'] == StatusRequest.success) {
      final data = _unwrap(employeeResponse['data']);
      final list = data is Map ? data['employees'] : null;
      employees = list is List
          ? list
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => EmployeeModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [];
    }

    update();
  }

  Future<void> loadPunches({String? state}) async {
    final response = await _deviceData.getPunches(
      deviceId: deviceId,
      state: state,
    );
    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response['data']);
      final list = data is Map ? data['punches'] : null;
      punches = list is List
          ? list
              .whereType<Map<dynamic, dynamic>>()
              .map((e) =>
                  DevicePunchModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [];
      update();
    }
  }

  /// Links a User ID to an employee, or unlinks it when [employeeId] is null.
  ///
  /// The backend replays the punches that arrived before the link existed, so
  /// the message says how many days of attendance just appeared — that number
  /// is the reason linking is worth doing before the end of the first day.
  Future<void> link(int deviceUserRowId, int? employeeId) async {
    linking = true;
    update();

    final response = await _deviceData.linkUser(
      deviceUserRowId: deviceUserRowId,
      employeeId: employeeId,
    );

    linking = false;

    if (response['status'] != StatusRequest.success) {
      update();
      Get.snackbar(
        'error'.tr,
        (response['message'] as String?) ?? 'error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        colorText: Get.theme.colorScheme.onErrorContainer,
        backgroundColor: Get.theme.colorScheme.errorContainer,
      );
      return;
    }

    final data = _unwrap(response['data']);
    final replayed = data is Map ? data['replayed'] : null;
    final applied =
        replayed is Map ? (replayed['applied'] as num?)?.toInt() ?? 0 : 0;

    await load();
    if (punches.isNotEmpty) {
      await loadPunches();
    }

    Get.snackbar(
      'done'.tr,
      employeeId == null
          ? 'device_user_unlinked'.tr
          : (applied > 0
              ? 'device_user_linked_with_replay'.trParams({'n': '$applied'})
              : 'device_user_linked'.tr),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  dynamic _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) return data['data'];
    return data;
  }
}
