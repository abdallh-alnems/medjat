import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';

class LeaveController extends GetxController {
  final LeaveData _leaveData = Get.find<LeaveData>();

  StatusRequest status = StatusRequest.none;
  StatusRequest applyStatus = StatusRequest.none;
  StatusRequest myLeavesStatus = StatusRequest.none;
  Map<String, dynamic>? balance;
  List<Map<String, dynamic>> myLeaves = [];

  /// 0 = current requests, 1 = ended & rejected archive.
  int requestsTab = 0;
  void setRequestsTab(int index) {
    if (requestsTab == index) return;
    requestsTab = index;
    update();
  }

  @override
  void onInit() {
    super.onInit();
    loadBalance();
    loadMyLeaves();
  }

  static const int maxPendingRequests = 2;

  int get pendingCount =>
      myLeaves.where((l) => (l['status'] as String?) == 'pending').length;

  bool get canApply => pendingCount < maxPendingRequests;

  Future<void> loadMyLeaves() async {
    myLeavesStatus = StatusRequest.loading;
    update();

    final response = await _leaveData.myLeaves();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      final data = response['data'];
      final raw = data is Map ? data['items'] : null;
      myLeaves = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      // Newest request first (by request date, then id as tie-breaker).
      myLeaves.sort((a, b) {
        final byDate = (b['created_at'] ?? '')
            .toString()
            .compareTo((a['created_at'] ?? '').toString());
        if (byDate != 0) return byDate;
        return ((b['id'] as int?) ?? 0).compareTo((a['id'] as int?) ?? 0);
      });
      myLeavesStatus = StatusRequest.success;
    } else {
      myLeavesStatus = responseStatus ?? StatusRequest.failure;
    }

    update();
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

  Future<bool> cancelLeave(int id) async {
    final response = await _leaveData.cancel(id);
    final responseStatus = response['status'] as StatusRequest?;
    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'leave_cancelled'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadBalance();
      await loadMyLeaves();
      return true;
    }
    final msg = (response['message'] as String?) ?? 'error'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> updateLeave({
    required int id,
    required String type,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    applyStatus = StatusRequest.loading;
    update();

    final response = await _leaveData.update(
      id: id,
      type: type,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
    );
    final responseStatus = response['status'] as StatusRequest?;
    applyStatus = responseStatus ?? StatusRequest.failure;
    update();
    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'leave_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadBalance();
      await loadMyLeaves();
      return true;
    }
    if (response['statusCode'] == 409) {
      final msg = (response['message'] as String?) ?? 'leave_overlap'.tr;
      Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    final msg = (response['message'] as String?) ?? 'leave_apply_failed'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    return false;
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
      await loadMyLeaves();
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
