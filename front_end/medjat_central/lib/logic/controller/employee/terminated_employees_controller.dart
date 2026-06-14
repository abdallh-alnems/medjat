import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/employee_data/terminated_employee_data.dart';
import '../../../data/model/terminated_employee_model.dart';

class TerminatedEmployeesController extends GetxController {
  final TerminatedEmployeeData _data = Get.find<TerminatedEmployeeData>();

  StatusRequest status = StatusRequest.none;
  StatusRequest actionStatus = StatusRequest.none;

  List<TerminatedEmployeeModel> employees = [];
  int total = 0;
  String searchQuery = '';

  /// ISO currency code from tenant settings (drives the settlement amount label).
  String currency = 'EGP';

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  /// Unwrap the {status:'success', data:{...}} envelope to the inner payload.
  Map<String, dynamic>? _payload(Map<String, dynamic> response) {
    final body = response['data'];
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.listTerminated(
      search: searchQuery.isNotEmpty ? searchQuery : null,
    );

    if (response['status'] != StatusRequest.success) {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
      update();
      return;
    }

    final payload = _payload(response);
    final items = payload?['items'];
    employees = (items is List)
        ? items
            .whereType<Map<String, dynamic>>()
            .map(TerminatedEmployeeModel.fromJson)
            .toList()
        : [];
    total = (payload?['total'] as num?)?.toInt() ?? employees.length;
    final cur = payload?['currency'];
    if (cur is String && cur.isNotEmpty) currency = cur;

    status = StatusRequest.success;
    update();
  }

  /// Debounced search: waits 400ms after the last keystroke before querying.
  void onSearch(String query) {
    searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), load);
  }

  /// Re-hire a terminated employee (restores them to pending_activation) and
  /// returns the fresh login details (activation code / join link / phone) so
  /// the screen can show them. Returns null on failure.
  Future<Map<String, dynamic>?> reactivate(int employeeId) async {
    actionStatus = StatusRequest.loading;
    update();

    final response = await _data.reactivate(employeeId);
    actionStatus = StatusRequest.none;

    if (response['status'] == StatusRequest.success) {
      employees.removeWhere((e) => e.id == employeeId);
      if (total > 0) total -= 1;
      update();
      return _payload(response) ?? {};
    }

    final msg = response['message'];
    Get.snackbar('error'.tr, msg is String ? msg : 'rehire_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return null;
  }
}
