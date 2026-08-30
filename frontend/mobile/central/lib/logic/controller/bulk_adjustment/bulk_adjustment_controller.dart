import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/bulk_adjustment_data/bulk_adjustment_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/bulk_adjustment_model.dart';

/// A simple {id, name} pair used to populate the scope dropdowns.
class ScopeOption {
  final int id;
  final String name;
  const ScopeOption(this.id, this.name);
}

class BulkAdjustmentController extends GetxController {
  final BulkAdjustmentData _data = Get.find<BulkAdjustmentData>();
  final BranchData _branchData = Get.find<BranchData>();
  final CategoryData _categoryData = Get.find<CategoryData>();
  final EmployeeData _employeeData = Get.find<EmployeeData>();

  StatusRequest status = StatusRequest.none;
  List<BulkAdjustmentModel> batches = [];

  // Scope option lists for the create form (loaded on demand).
  List<ScopeOption> branches = [];
  List<ScopeOption> categories = [];
  List<ScopeOption> employees = [];
  bool optionsLoaded = false;
  bool loadingOptions = false;

  @override
  void onInit() {
    super.onInit();
    loadBatches();
  }

  Future<void> loadBatches() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getList();
    if (response['status'] == StatusRequest.success) {
      batches = _extractList(response['data'])
          .map(BulkAdjustmentModel.fromJson)
          .toList();
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadOptions() async {
    if (loadingOptions) return;
    loadingOptions = true;
    update();

    final results = await Future.wait([
      _branchData.getBranches(),
      _categoryData.getCategories(),
      _employeeData.getEmployees(status: 'active'),
    ]);

    branches = _toOptions(results[0]);
    categories = _toOptions(results[1]);
    employees = _toOptions(results[2]);

    optionsLoaded = true;
    loadingOptions = false;
    update();
  }

  /// Preview the effect of a batch without writing: returns
  /// {affected_count, eligible_count, locked_count, zero_count, duplicate, month}
  /// or null on failure.
  Future<Map<String, dynamic>?> preview({
    required String kind,
    required String scopeType,
    int? scopeId,
    required num amount,
    required String amountType,
    String? month,
  }) async {
    final response = await _data.create(
      kind: kind,
      scopeType: scopeType,
      scopeId: scopeId,
      amount: amount,
      amountType: amountType,
      month: month,
      dryRun: true,
    );
    if (response['status'] == StatusRequest.success) {
      return _payload(response['data']);
    }
    return null;
  }

  /// Apply a new bulk batch. Returns the success payload (count/skipped) or null.
  Future<Map<String, dynamic>?> create({
    required String kind,
    required String scopeType,
    int? scopeId,
    required num amount,
    required String amountType,
    String reason = '',
    String? month,
  }) async {
    final response = await _data.create(
      kind: kind,
      scopeType: scopeType,
      scopeId: scopeId,
      amount: amount,
      amountType: amountType,
      reason: reason,
      month: month,
    );
    if (response['status'] == StatusRequest.success) {
      await loadBatches();
      return _payload(response['data']);
    }
    return null;
  }

  Future<bool> deleteBatch(int id) async {
    final response = await _data.delete(id);
    if (response['status'] == StatusRequest.success) {
      batches.removeWhere((b) => b.id == id);
      update();
      return true;
    }
    return false;
  }

  List<ScopeOption> _toOptions(Map<String, dynamic> response) {
    if (response['status'] != StatusRequest.success) return [];
    return _extractList(response['data'])
        .map((m) => ScopeOption(
              (m['id'] as num?)?.toInt() ?? 0,
              (m['name'] as String?) ?? '',
            ))
        .where((o) => o.id > 0)
        .toList();
  }

  Map<String, dynamic>? _payload(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }
    return payload is Map ? Map<String, dynamic>.from(payload) : null;
  }

  /// Unwraps the common `{data:{items:[...]}}` / `{data:[...]}` shapes.
  List<Map<String, dynamic>> _extractList(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const [
        'items',
        'records',
        'list',
        'branches',
        'categories',
        'employees',
        'data',
      ]) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items.whereType<Map<String, dynamic>>().toList();
  }
}
