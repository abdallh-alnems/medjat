import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AdminAccountData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> create({
    required String username,
    required String password,
    required String role,
    String? displayName,
    String? email,
  }) async {
    final data = <String, dynamic>{
      'username': username,
      'password': password,
      'role': role,
    };
    if (displayName != null && displayName.isNotEmpty) data['display_name'] = displayName;
    if (email != null && email.isNotEmpty) data['email'] = email;
    return await _crud.postData(AppLinks.userCreate, data);
  }
}
