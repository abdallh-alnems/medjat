import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../model/user_model.dart';

class AuthData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> login({
    required String phone,
    required String activationCode,
  }) async {
    final deviceId = await TokenStorageService.getOrCreateDeviceId();
    String deviceModel = '';
    String platform = 'android';
    try {
      if (Platform.isIOS) {
        platform = 'ios';
      }
      deviceModel = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {}

    String appVersion = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final response = await _crud.postData(
      AppLinks.employeeLogin,
      {
        'phone': phone,
        'activation_code': activationCode.toUpperCase(),
        'device_id': deviceId,
        'device_model': deviceModel,
        'platform': platform,
        'app_version': appVersion,
      },
      auth: false,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data?['token'] != null) {
        await TokenStorageService.saveToken(data!['token'] as String);
      }
      if (data?['employee'] != null) {
        final employee = data!['employee'] as Map<String, dynamic>;
        final Map<String, dynamic> userData = {
          'id': employee['id'],
          'name': employee['name'],
          'tenant_id': employee['tenant_id'],
          'tenant_name': employee['tenant_name'],
          'branch_id': employee['branch_id'],
          'branch_name': employee['branch_name'],
          'job_title': employee['job_title'],
          'phone': employee['phone'],
          'profile_image': employee['profile_image'],
        };
        await TokenStorageService.saveUserData(jsonEncode(userData));
      }
    }

    return response;
  }

  Future<Map<String, dynamic>> logout() async {
    final response = await _crud.postData(AppLinks.employeeLogout, {});
    await TokenStorageService.clearSession();
    return response;
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

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.myProfile);
  }
}
