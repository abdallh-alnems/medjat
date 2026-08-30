import 'package:get/get.dart';
import '../../../core/class/api_messages.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/advance_data/advance_data.dart';

class AdvanceController extends GetxController {
  final AdvanceData _advanceData = Get.find<AdvanceData>();

  StatusRequest myAdvancesStatus = StatusRequest.none;
  StatusRequest requestStatus = StatusRequest.none;
  List<Map<String, dynamic>> myAdvances = [];

  static const int maxPendingRequests = 3;

  @override
  void onInit() {
    super.onInit();
    loadMyAdvances();
  }

  int get pendingCount =>
      myAdvances.where((a) => (a['status'] as String?) == 'pending').length;

  bool get canRequest => pendingCount < maxPendingRequests;

  Future<void> loadMyAdvances() async {
    myAdvancesStatus = StatusRequest.loading;
    update();

    final response = await _advanceData.myAdvances();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      myAdvances = _extractItems(response['data']);
      myAdvancesStatus = StatusRequest.success;
    } else {
      myAdvancesStatus = responseStatus ?? StatusRequest.failure;
    }

    update();
  }

  List<Map<String, dynamic>> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map) {
      for (final key in const ['loans', 'items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          return (payload[key] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<bool> requestAdvance({
    required double totalAmount,
    required int installmentsCount,
    String? startMonth,
    String? reason,
  }) async {
    requestStatus = StatusRequest.loading;
    update();

    final response = await _advanceData.request(
      totalAmount: totalAmount,
      installmentsCount: installmentsCount,
      startMonth: startMonth,
      reason: reason,
    );
    final responseStatus = response['status'] as StatusRequest?;
    requestStatus = responseStatus ?? StatusRequest.failure;

    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'advance_requested'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadMyAdvances();
      return true;
    }

    update();
    if (responseStatus == StatusRequest.offline ||
        (responseStatus == StatusRequest.failure &&
            response['message'] == null)) {
      Get.snackbar('error'.tr, 'no_internet'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    Get.snackbar('error'.tr,
        ApiMessages.of(response, fallbackKey: 'advance_request_failed'),
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> cancelAdvance(int id) async {
    final response = await _advanceData.cancel(id);
    final responseStatus = response['status'] as StatusRequest?;
    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'advance_cancelled'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadMyAdvances();
      return true;
    }
    Get.snackbar('error'.tr, ApiMessages.of(response),
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }
}
