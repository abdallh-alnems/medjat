import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DeductionRuleData {
  final CRUD _crud = Get.find<CRUD>();

  /// Returns the tenant deduction config: late-tier ladder + absence rate.
  Future<Map<String, dynamic>> getDeductionConfig() async {
    return await _crud.getData(AppLinks.deductionRules);
  }

  /// Persists the whole config atomically. [data] = { absence_days, tiers: [..] }.
  Future<Map<String, dynamic>> saveDeductionConfig(
      Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.deductionSaveConfig, data);
  }
}
