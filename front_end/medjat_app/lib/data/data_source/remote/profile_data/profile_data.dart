import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ProfileData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.me);
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    return await _crud.postData(AppLinks.updateProfile, data);
  }
}
