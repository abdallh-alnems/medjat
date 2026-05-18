import 'dart:convert';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../model/user_model.dart';

class AuthData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _crud.postData(
      AppLinks.login,
      {'email': email, 'password': password},
      auth: false,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        await TokenStorageService.saveToken((data['token'] as String?) ?? '');
        if (data['refresh_token'] != null) {
          await TokenStorageService.saveRefreshToken(data['refresh_token'] as String);
        }
        if (data['user'] != null) {
          await TokenStorageService.saveUserData(jsonEncode(data['user']));
        }
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.me);
  }

  Future<Map<String, dynamic>> logout() async {
    final response = await _crud.postData(AppLinks.logout, {});
    await TokenStorageService.clearAll();
    return response;
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    return await _crud.postData(
      AppLinks.forgotPassword,
      {'email': email},
      auth: false,
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _crud.postData(AppLinks.changePassword, {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
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
