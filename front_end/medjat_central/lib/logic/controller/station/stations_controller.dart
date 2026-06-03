import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/station_data/station_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/attendance_station_model.dart';
import '../../../data/model/branch_model.dart';

class StationsController extends GetxController {
  final StationData _data = Get.find<StationData>();
  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  List<AttendanceStationModel> stations = [];
  List<BranchModel> branches = [];
  int? filterBranchId;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();
    await Future.wait([loadStations(), loadBranches()]);
    status = StatusRequest.success;
    update();
  }

  Future<void> loadStations() async {
    final response = await _data.getStations(branchId: filterBranchId);
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['items'] is List) {
        payload = payload['items'];
      } else if (payload is Map && payload['data'] is Map) {
        payload = payload['data']['items'] ?? [];
      }
      if (payload is List) {
        stations = payload
            .whereType<Map<String, dynamic>>()
            .map((e) => AttendanceStationModel.fromJson(e))
            .toList();
      }
    }
  }

  Future<void> loadBranches() async {
    final response = await _branchData.getBranches();
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) {
        payload = payload['data'];
      }
      if (payload is Map && payload['branches'] is List) {
        payload = payload['branches'];
      }
      if (payload is List) {
        branches = payload
            .whereType<Map<String, dynamic>>()
            .map((e) => BranchModel.fromJson(e))
            .toList();
      }
    }
  }

  void setFilter(int? branchId) {
    filterBranchId = branchId;
    loadStations();
    update();
  }

  Future<Map<String, dynamic>?> createStation(
      int branchId, String deviceName, String adminPin) async {
    final response = await _data.createStation({
      'branch_id': branchId,
      'device_name': deviceName,
      'admin_pin': adminPin,
    });
    if (response['status'] == StatusRequest.success) {
      await loadStations();
      update();
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      return payload as Map<String, dynamic>?;
    }
    return null;
  }

  Future<bool> deleteStation(int id) async {
    final response = await _data.deleteStation(id);
    if (response['status'] == StatusRequest.success) {
      await loadStations();
      update();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> regenerateQR(int id) async {
    final response = await _data.regenerateQR(id);
    if (response['status'] == StatusRequest.success) {
      await loadStations();
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      return payload as Map<String, dynamic>?;
    }
    return null;
  }

  Future<bool> unlockStation(int id) async {
    final response = await _data.unlockStation(id);
    if (response['status'] == StatusRequest.success) {
      await loadStations();
      update();
      return true;
    }
    return false;
  }

  Future<bool> toggleActive(int id, bool active) async {
    final response = await _data.updateStation(id, {'is_active': active ? 1 : 0});
    if (response['status'] == StatusRequest.success) {
      await loadStations();
      update();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> generateKioskPin(int stationId) async {
    final response = await _data.generateKioskPin(stationId);
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      return payload as Map<String, dynamic>?;
    }
    return null;
  }
}
