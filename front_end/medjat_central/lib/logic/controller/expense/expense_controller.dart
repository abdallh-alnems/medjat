import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/expense_data/expense_data.dart';
import '../../../data/model/expense_claim_model.dart';

class ExpenseController extends GetxController {
  final ExpenseData _data = Get.find<ExpenseData>();

  StatusRequest status = StatusRequest.none;
  List<ExpenseClaimModel> expenses = [];
  String? statusFilter;

  @override
  void onInit() {
    super.onInit();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getExpenses(status: statusFilter);

    if (response['status'] == StatusRequest.success) {
      expenses = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<ExpenseClaimModel> _extractItems(dynamic raw) {
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
        .map(ExpenseClaimModel.fromJson)
        .toList();
  }

  void filterByStatus(String? value) {
    statusFilter = value;
    loadExpenses();
  }

  Future<void> approve(int id) async {
    final response = await _data.approveExpense(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'expense_approved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadExpenses();
    } else {
      _failSnack(response);
    }
  }

  Future<void> reject(int id, {String? reason}) async {
    final response = await _data.rejectExpense(id, reason: reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'expense_rejected'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadExpenses();
    } else {
      _failSnack(response);
    }
  }

  Future<void> reimburse(int id) async {
    final response = await _data.reimburseExpense(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'expense_marked_reimbursed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadExpenses();
    } else {
      _failSnack(response);
    }
  }

  Future<bool> createExpense({
    required int employeeId,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
  }) async {
    final data = <String, dynamic>{
      'employee_id': employeeId,
      'category': category,
      'amount': amount,
      'expense_date': _fmt(expenseDate),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    };

    final response = await _data.createExpense(data);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'expense_created'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadExpenses();
      return true;
    }
    _failSnack(response, fallback: 'expense_create_failed'.tr);
    return false;
  }

  void _failSnack(Map<String, dynamic> response, {String? fallback}) {
    final msg = response['message'];
    Get.snackbar('error'.tr,
        msg is String ? msg : (fallback ?? 'error'.tr),
        snackPosition: SnackPosition.BOTTOM);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
