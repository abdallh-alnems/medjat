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

  Future<Map<String, dynamic>> forgotPasswordSend(String email) async {
    return await _crud.postData(
      AppLinks.forgotPasswordSend,
      {'email': email},
      auth: false,
    );
  }

  Future<Map<String, dynamic>> forgotPasswordVerify(
      String email, String code) async {
    return await _crud.postData(
      AppLinks.forgotPasswordVerify,
      {'email': email, 'code': code},
      auth: false,
    );
  }

  Future<Map<String, dynamic>> forgotPasswordReset(
      String email, String code, String newPassword) async {
    return await _crud.postData(
      AppLinks.forgotPasswordReset,
      {'email': email, 'code': code, 'new_password': newPassword},
      auth: false,
    );
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
