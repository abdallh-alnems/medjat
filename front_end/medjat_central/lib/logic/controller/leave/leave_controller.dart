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
      final data = response['data'];
      if (data is List) {
        leaves =
            data.map((e) => LeaveModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
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
}
