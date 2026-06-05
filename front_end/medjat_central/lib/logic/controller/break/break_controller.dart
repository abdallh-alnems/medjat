import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/break_data/break_data.dart';
import '../../../data/model/break_request_model.dart';

class BreakController extends GetxController {
  final BreakData _breakData = Get.find<BreakData>();

  StatusRequest status = StatusRequest.none;
  List<BreakRequestModel> breaks = [];
  String? statusFilter;

  @override
  void onInit() {
    super.onInit();
    loadBreaks();
  }

  Future<void> loadBreaks() async {
    status = StatusRequest.loading;
    update();

    final response = await _breakData.getBreaks(status: statusFilter);

    if (response['status'] == StatusRequest.success) {
      breaks = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<BreakRequestModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['breaks', 'items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(BreakRequestModel.fromJson)
        .toList();
  }

  void filterByStatus(String? status) {
    statusFilter = status;
    loadBreaks();
  }

  Future<void> approveBreak(int id, {bool? deductFromSalary}) async {
    final response =
        await _breakData.approveBreak(id, deductFromSalary: deductFromSalary);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_approved'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }

  Future<void> rejectBreak(int id, {String? reason}) async {
    final response = await _breakData.rejectBreak(id, reason: reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_rejected'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }

  Future<void> postponeBreak(
    int id, {
    String? note,
    String? suggestedDate,
    String? suggestedStartTime,
    String? suggestedEndTime,
  }) async {
    final response = await _breakData.postponeBreak(
      id,
      note: note,
      suggestedDate: suggestedDate,
      suggestedStartTime: suggestedStartTime,
      suggestedEndTime: suggestedEndTime,
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_postponed'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }

  Future<bool> createBreak({
    required String date,
    required String startTime,
    required String endTime,
    required String type,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'type': type,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }

    final response = await _breakData.createBreak(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_created_success'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
      return true;
    }

    if (response['statusCode'] == 409) {
      final msg = response['message'];
      Get.snackbar('error'.tr, msg is String ? msg : 'break_overlap'.tr, snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    final errMsg = response['message'];
    Get.snackbar('error'.tr, errMsg is String ? errMsg : 'break_created_failed'.tr, snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<void> cancelBreak(int id) async {
    final response = await _breakData.cancelBreak(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_cancelled'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }
}
