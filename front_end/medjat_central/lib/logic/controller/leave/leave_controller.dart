import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';
import '../../../data/model/leave_model.dart';

class LeaveController extends GetxController {
  final LeaveData _leaveData = Get.find<LeaveData>();

  StatusRequest status = StatusRequest.none;
  List<LeaveModel> leaves = [];
  String? statusFilter;

  Map<String, dynamic>? balanceInfo;
  bool balanceLoading = false;

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

  Future<void> loadBalance(int employeeId, {int? year}) async {
    balanceLoading = true;
    balanceInfo = null;
    update();
    try {
      final response =
          await _leaveData.leaveBalance(employeeId, year: year);
      if (response['status'] == StatusRequest.success) {
        final body = response['data'];
        if (body is Map && body['data'] is Map) {
          balanceInfo = body['data'] as Map<String, dynamic>;
        } else if (body is Map && body['remaining_days'] != null) {
          balanceInfo = body as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    balanceLoading = false;
    update();
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
      'start_date': _fmt(startDate),
      'end_date': _fmt(endDate ?? startDate),
    };
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }

    final response = await _leaveData.createLeave(data);

    if (response['status'] == StatusRequest.success) {
      final body = response['data'];
      Map<String, dynamic>? inner;
      if (body is Map && body['data'] is Map) {
        inner = body['data'] as Map<String, dynamic>;
      } else if (body is Map) {
        inner = body as Map<String, dynamic>;
      }

      if (inner != null && inner['warning'] == 'balance_exceeded') {
        Get.snackbar(
          'تنبيه',
          'سيتم احتساب ${inner['paid_days']} يوم بأجر و ${inner['unpaid_days']} يوم بدون أجر',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar('تم', 'تم إنشاء الإجازة بنجاح',
            snackPosition: SnackPosition.BOTTOM);
      }
      loadLeaves();
      return true;
    }

    if (response['statusCode'] == 409) {
      final msg = response['message'];
      Get.snackbar(
          'خطأ',
          msg is String
              ? msg
              : 'يوجد تداخل مع إجازة قائمة في هذه الفترة',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    final errMsg = response['message'];
    Get.snackbar(
        'خطأ',
        errMsg is String ? errMsg : 'فشل إنشاء الإجازة',
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> createRecurringLeave({
    required int employeeId,
    required String dayOfWeek,
    required String type,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'day_of_week': dayOfWeek,
      'type': type,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }

    final response = await _leaveData.createRecurringLeave(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إنشاء الإجازة المتكررة بنجاح',
          snackPosition: SnackPosition.BOTTOM);
      loadLeaves();
      return true;
    }

    Get.snackbar('خطأ', 'فشل إنشاء الإجازة المتكررة',
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
