import 'dart:convert';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../model/user_model.dart';

class AuthData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> login(String firebaseToken) async {
    return await _crud.postData(
      AppLinks.login,
      {'token': firebaseToken},
    );
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.me);
  }

  Future<Map<String, dynamic>> logout() async {
    return await _crud.postData(AppLinks.logout, {});
  }

  Future<UserModel?> getCachedUser() async {
    final json = await TokenStorageService.getUserData();
    if (json == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
