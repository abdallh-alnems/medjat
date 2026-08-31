import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/loan_data/loan_data.dart';
import '../../../data/model/loan_model.dart';

class LoanController extends GetxController {
  final LoanData _data = Get.find<LoanData>();

  StatusRequest status = StatusRequest.none;
  List<LoanModel> loans = [];
  String? statusFilter;

  @override
  void onInit() {
    super.onInit();
    loadLoans();
  }

  Future<void> loadLoans() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getLoans(status: statusFilter);

    if (response['status'] == StatusRequest.success) {
      loans = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<LoanModel> _extractItems(dynamic raw) {
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
        .map(LoanModel.fromJson)
        .toList();
  }

  void filterByStatus(String? value) {
    statusFilter = value;
    loadLoans();
  }

  Future<void> approve(int id) async {
    final response = await _data.approveLoan(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'loan_approved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      unawaited(loadLoans());
    } else {
      _failSnack(response);
    }
  }

  Future<void> cancel(int id) async {
    final response = await _data.cancelLoan(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'loan_cancelled_done'.tr,
          snackPosition: SnackPosition.BOTTOM);
      unawaited(loadLoans());
    } else {
      _failSnack(response);
    }
  }

  Future<bool> createLoan({
    required int employeeId,
    required String type,
    required double totalAmount,
    required int installmentsCount,
    required String startMonth,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'employee_id': employeeId,
      'type': type,
      'total_amount': totalAmount,
      'installments_count': installmentsCount,
      'start_month': startMonth,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    };

    final response = await _data.createLoan(data);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'loan_created'.tr,
          snackPosition: SnackPosition.BOTTOM);
      unawaited(loadLoans());
      return true;
    }
    _failSnack(response, fallback: 'loan_create_failed'.tr);
    return false;
  }

  void _failSnack(Map<String, dynamic> response, {String? fallback}) {
    final msg = response['message'];
    Get.snackbar('error'.tr,
        msg is String ? msg : (fallback ?? 'error'.tr),
        snackPosition: SnackPosition.BOTTOM);
  }
}
