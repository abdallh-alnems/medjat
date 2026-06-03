import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';

class LeaveController extends GetxController {
  final LeaveData _leaveData = Get.find<LeaveData>();

  StatusRequest status = StatusRequest.none;
  StatusRequest applyStatus = StatusRequest.none;
  Map<String, dynamic>? balance;

  @override
  void onInit() {
    super.onInit();
    loadBalance();
  }

  Future<void> loadBalance() async {
    status = StatusRequest.loading;
    update();

    final response = await _leaveData.getBalance();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      balance = response['data'] as Map<String, dynamic>?;
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }

    update();
  }

  Future<bool> applyLeave({
    required String date,
    required String type,
    String? reason,
    String? startDate,
    String? endDate,
  }) async {
    applyStatus = StatusRequest.loading;
    update();

    final response = await _leaveData.apply(
      date: date,
      type: type,
      reason: reason,
      startDate: startDate,
      endDate: endDate,
    );

    final responseStatus = response['status'] as StatusRequest?;
    applyStatus = responseStatus ?? StatusRequest.failure;

    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'leave_applied'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadBalance();
      update();
      return true;
    } else {
      final statusCode = response['statusCode'];
      if (statusCode == 409) {
        Get.snackbar('error'.tr, 'leave_overlap'.tr,
            snackPosition: SnackPosition.BOTTOM);
      } else {
        final msg = (response['message'] as String?) ?? 'leave_apply_failed'.tr;
        Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
      }
      update();
      return false;
    }
  }
}
