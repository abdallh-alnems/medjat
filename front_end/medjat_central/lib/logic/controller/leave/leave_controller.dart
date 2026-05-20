import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';
import '../../../data/model/leave_model.dart';

class LeaveController extends GetxController {
  final LeaveData _leaveData = Get.find<LeaveData>();

  StatusRequest status = StatusRequest.none;
  List<LeaveModel> leaves = [];
  String? statusFilter;

  @override
  void onInit() {
    super.onInit();
    loadLeaves();
  }

  Future<void> loadLeaves() async {
    status = StatusRequest.loading;
    update();

    final response = await _leaveData.getLeaves(status: statusFilter);

    if (response['status'] == StatusRequest.success) {
      leaves = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<LeaveModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
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
    return items
        .whereType<Map<String, dynamic>>()
        .map(LeaveModel.fromJson)
        .toList();
  }

  void filterByStatus(String? status) {
    statusFilter = status;
    loadLeaves();
  }

  Future<void> approveLeave(int id) async {
    final response = await _leaveData.approveLeave(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم قبول الإجازة', snackPosition: SnackPosition.BOTTOM);
      loadLeaves();
    }
  }

  Future<void> rejectLeave(int id, {String? reason}) async {
    final response = await _leaveData.rejectLeave(id, reason: reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم رفض الإجازة', snackPosition: SnackPosition.BOTTOM);
      loadLeaves();
    }
  }

  Future<bool> createLeave({
    required int employeeId,
    required String type,
    required DateTime startDate,
    DateTime? endDate,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'employee_id': employeeId,
      'type': type,
      'start_date':
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
    };
    if (endDate != null) {
      data['end_date'] =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    }
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }

    final response = await _leaveData.createLeave(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar(
        'done'.tr,
        'leave_created_success'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      loadLeaves();
      return true;
    } else {
      Get.snackbar(
        'error'.tr,
        'leave_created_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
  }
}
