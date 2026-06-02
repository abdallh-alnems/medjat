import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ProfileData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.myProfile);
  }
}
