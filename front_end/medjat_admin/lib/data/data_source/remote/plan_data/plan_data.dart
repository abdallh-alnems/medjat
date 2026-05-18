import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class PlanData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list() async {
    return await _crud.postData(AppLinks.plans, {});
  }

  Future<Map<String, dynamic>> create({
    required String name,
    double price = 0,
    int maxEmployees = 10,
    int maxBranches = 1,
  }) async {
    return await _crud.postData(AppLinks.planCreate, {
      'name': name,
      'price': price,
      'max_employees': maxEmployees,
      'max_branches': maxBranches,
    });
  }

  Future<Map<String, dynamic>> update({
    required int id,
    String? name,
    double? price,
    int? maxEmployees,
    int? maxBranches,
  }) async {
    final data = <String, dynamic>{'id': id};
    if (name != null) data['name'] = name;
    if (price != null) data['price'] = price;
    if (maxEmployees != null) data['max_employees'] = maxEmployees;
    if (maxBranches != null) data['max_branches'] = maxBranches;
    return await _crud.postData(AppLinks.planUpdate, data);
  }
}
