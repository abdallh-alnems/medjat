import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class CompanySettingsData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getCompanySettings() async {
    return await _crud.getData(AppLinks.companySettings);
  }

  Future<Map<String, dynamic>> updateCompanySettings(
      Map<String, dynamic> data) async {
    return await _crud.putData(AppLinks.companySettings, data);
  }
}
