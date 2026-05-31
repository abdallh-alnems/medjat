import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/shift_data/shift_data.dart';
import '../../../data/model/shift_model.dart';

class ShiftController extends GetxController {
  final ShiftData _data = Get.find<ShiftData>();

  StatusRequest status = StatusRequest.none;
  List<ShiftModel> shifts = [];

  @override
  void onInit() {
    super.onInit();
    loadShifts();
  }

  Future<void> loadShifts() async {
    status = StatusRequest.loading;
    update();
    final response = await _data.getShifts();
    if (response['status'] == StatusRequest.success) {
      shifts = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  Future<bool> createShift({
    required String name,
    required String startTime,
    required String endTime,
    int? branchId,
  }) async {
    final response = await _data.createShift({
      'name': name,
      'start_time': startTime,
      'end_time': endTime,
      if (branchId != null) 'branch_id': branchId,
    });
    if (response['status'] == StatusRequest.success) {
      await loadShifts();
      return true;
    }
    return false;
  }

  Future<bool> updateShift(int id, Map<String, dynamic> data) async {
    final response = await _data.updateShift(id, data);
    if (response['status'] == StatusRequest.success) {
      await loadShifts();
      return true;
    }
    return false;
  }

  Future<bool> deleteShift(int id) async {
    final response = await _data.deleteShift(id);
    if (response['status'] == StatusRequest.success) {
      await loadShifts();
      return true;
    }
    return false;
  }

  Future<int> assignEmployees(int shiftId, List<int> employeeIds) async {
    final response = await _data.assignEmployees(
      shiftId: shiftId,
      employeeIds: employeeIds,
    );
    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is Map && data['data'] is Map) {
        return (data['data']['assigned'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  Future<int> unassignEmployees(int shiftId, List<int> employeeIds) async {
    final response = await _data.unassignEmployees(
      shiftId: shiftId,
      employeeIds: employeeIds,
    );
    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is Map && data['data'] is Map) {
        return (data['data']['unassigned'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  List<ShiftModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items.whereType<Map<String, dynamic>>().map(ShiftModel.fromJson).toList();
  }
}
