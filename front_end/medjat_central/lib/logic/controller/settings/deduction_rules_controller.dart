import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
import '../../../data/model/deduction_rule_model.dart';

class DeductionRulesController extends GetxController {
  final DeductionRuleData _deductionRuleData = Get.find<DeductionRuleData>();

  StatusRequest status = StatusRequest.none;
  List<DeductionRuleModel> rules = [];

  @override
  void onInit() {
    super.onInit();
    loadRules();
  }

  Future<void> loadRules() async {
    status = StatusRequest.loading;
    update();

    final response = await _deductionRuleData.getDeductionRules();

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        rules = data
            .map((e) => DeductionRuleModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> createRule(Map<String, dynamic> data) async {
    final response = await _deductionRuleData.createDeductionRule(data);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'rule_added'.tr, snackPosition: SnackPosition.BOTTOM);
      loadRules();
    } else {
      Get.snackbar(
          'error'.tr, (response['message'] as String?) ?? 'an_error_occurred'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> updateRule(int id, Map<String, dynamic> data) async {
    final response = await _deductionRuleData.updateDeductionRule(id, data);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'rule_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadRules();
    } else {
      Get.snackbar(
          'error'.tr, (response['message'] as String?) ?? 'an_error_occurred'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> deleteRule(int id) async {
    final response = await _deductionRuleData.deleteDeductionRule(id);
    if (response['status'] == StatusRequest.success) {
      rules.removeWhere((r) => r.id == id);
      Get.snackbar('done'.tr, 'rule_deleted'.tr, snackPosition: SnackPosition.BOTTOM);
      update();
    }
  }
}
