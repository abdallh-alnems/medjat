import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DeductionRuleData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getDeductionRules() async {
    return await _crud.getData(AppLinks.deductionRules);
  }

  Future<Map<String, dynamic>> createDeductionRule(
      Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.deductionRules, data);
  }

  Future<Map<String, dynamic>> updateDeductionRule(
      int id, Map<String, dynamic> data) async {
    return await _crud.putData('${AppLinks.deductionRules}/$id', data);
  }

  Future<Map<String, dynamic>> deleteDeductionRule(int id) async {
    return await _crud.deleteData('${AppLinks.deductionRules}/$id');
  }
}
