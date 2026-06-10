import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/break_data/break_data.dart';

class BreakController extends GetxController {
  final BreakData _breakData = Get.find<BreakData>();

  StatusRequest myBreaksStatus = StatusRequest.none;
  StatusRequest requestStatus = StatusRequest.none;
  List<Map<String, dynamic>> myBreaks = [];

  @override
  void onInit() {
    super.onInit();
    loadMyBreaks();
  }

  static const int maxPendingRequests = 3;

  int get pendingCount =>
      myBreaks.where((b) => (b['status'] as String?) == 'pending').length;

  bool get canRequest => pendingCount < maxPendingRequests;

  Future<void> loadMyBreaks() async {
    myBreaksStatus = StatusRequest.loading;
    update();

    final response = await _breakData.myBreaks();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      myBreaks = _extractItems(response['data']);
      myBreaksStatus = StatusRequest.success;
    } else {
      myBreaksStatus = responseStatus ?? StatusRequest.failure;
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
      for (final key in const ['breaks', 'items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          return (payload[key] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<bool> requestBreak({
    required String date,
    required String startTime,
    required String endTime,
    required String type,
    String? reason,
  }) async {
    requestStatus = StatusRequest.loading;
    update();

    final response = await _breakData.request(
      date: date,
      startTime: startTime,
      endTime: endTime,
      type: type,
      reason: reason,
    );
    final responseStatus = response['status'] as StatusRequest?;
    requestStatus = responseStatus ?? StatusRequest.failure;

    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'break_requested'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadMyBreaks();
      return true;
    }

    update();
    // No connection / couldn't reach the server: a generic "failed" hides the
    // real cause, so show a connection-specific message instead.
    if (responseStatus == StatusRequest.offline ||
        (responseStatus == StatusRequest.failure &&
            response['message'] == null)) {
      Get.snackbar('error'.tr, 'no_internet'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (response['statusCode'] == 409) {
      final msg = (response['message'] as String?) ?? 'break_overlap'.tr;
      Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    // Surface the server's own message (past window, validation, etc.).
    final msg = (response['message'] as String?) ?? 'break_request_failed'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> cancelBreak(int id) async {
    final response = await _breakData.cancel(id);
    final responseStatus = response['status'] as StatusRequest?;
    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'break_cancelled'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadMyBreaks();
      return true;
    }
    final msg = (response['message'] as String?) ?? 'error'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    return false;
  }
}
