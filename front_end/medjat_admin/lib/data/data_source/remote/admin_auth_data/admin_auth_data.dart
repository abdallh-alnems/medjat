import 'dart:convert';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../model/admin_model.dart';

class AdminAuthData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _crud.postData(
      AppLinks.adminLogin,
      {'username': username, 'password': password},
      auth: false,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        await TokenStorageService.saveToken(data['token'] as String? ?? '');
        if (data['admin'] != null) {
          await TokenStorageService.saveUserData(jsonEncode(data['admin']));
        } else if (data['user'] != null) {
          await TokenStorageService.saveUserData(jsonEncode(data['user']));
        }
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.adminMe);
  }

  /// Changing the password signs every other device out server-side, so no
  /// local cleanup is needed here.
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return await _crud.postData(AppLinks.adminChangePassword, {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> logout() async {
    final response = await _crud.postData(AppLinks.adminLogout, {});
    await TokenStorageService.clearAll();
    return response;
  }

  Future<AdminModel?> getCachedAdmin() async {
    final json = await TokenStorageService.getUserData();
    if (json == null) return null;
    try {
      return AdminModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
