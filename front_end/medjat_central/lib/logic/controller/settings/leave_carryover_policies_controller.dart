import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';

/// Manages per-scope (branch/category) carryover overrides. The tenant-level
/// policy is edited on the leave-settings screen; this screen layers more
/// specific rules on top, resolved employee > category > branch > tenant.
class LeaveCarryoverPoliciesController extends GetxController {
  final CompanySettingsData _data = Get.find<CompanySettingsData>();
  final BranchData _branchData = Get.find<BranchData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  StatusRequest status = StatusRequest.none;
  bool saving = false;

  List<Map<String, dynamic>> policies = [];
  List<Map<String, dynamic>> branches = [];
  List<Map<String, dynamic>> categories = [];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final results = await Future.wait([
      _data.getCarryoverPolicies(),
      _branchData.getBranches(),
      _categoryData.getCategories(),
    ]);

    final policyResp = results[0];
    if (policyResp['status'] == StatusRequest.success) {
      policies = _extractList(policyResp, 'policies');
      branches = _extractList(results[1], 'branches');
      categories = _extractList(results[2], 'categories');
      status = StatusRequest.success;
    } else {
      status = (policyResp['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<Map<String, dynamic>> _extractList(
      Map<String, dynamic> response, String key) {
    dynamic body = response['data'];
    if (body is Map && body['data'] is Map) body = body['data'];
    final list = (body is Map ? body[key] : (body is List ? body : null));
    if (list is List) {
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  String scopeLabel(Map<String, dynamic> policy) {
    final type = (policy['scope_type'] ?? '').toString();
    final id = policy['scope_id'];
    if (type == 'branch') {
      final b = branches.firstWhereOrNull((e) => e['id'] == id);
      return '${'scope_branch'.tr}: ${b?['name'] ?? id}';
    }
    if (type == 'category') {
      final c = categories.firstWhereOrNull((e) => e['id'] == id);
      return '${'scope_category'.tr}: ${c?['name'] ?? id}';
    }
    if (type == 'employee') {
      return '${'scope_employee'.tr}: #$id';
    }
    return 'scope_tenant'.tr;
  }

  Future<bool> savePolicy({
    required String scopeType,
    required int scopeId,
    required int minSeniorityMonths,
    required bool carryoverEnabled,
    int? carryoverMaxDays,
    int? expiryMonths,
    bool encashExcess = false,
    int? legalMinCarryDays,
  }) async {
    saving = true;
    update();

    final response = await _data.saveCarryoverPolicy(
      scopeType: scopeType,
      scopeId: scopeId,
      minSeniorityMonths: minSeniorityMonths,
      carryoverEnabled: carryoverEnabled,
      carryoverMaxDays: carryoverMaxDays,
      expiryMonths: expiryMonths,
      encashExcess: encashExcess,
      legalMinCarryDays: legalMinCarryDays,
    );

    saving = false;
    final ok = response['status'] == StatusRequest.success;
    if (ok) {
      await load();
    } else {
      Get.snackbar('error'.tr, (response['message'] as String?) ?? 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
    }
    return ok;
  }

  Future<void> deletePolicy(int id) async {
    final response = await _data.deleteCarryoverPolicy(id);
    if (response['status'] == StatusRequest.success) {
      await load();
    } else {
      Get.snackbar('error'.tr, (response['message'] as String?) ?? 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
