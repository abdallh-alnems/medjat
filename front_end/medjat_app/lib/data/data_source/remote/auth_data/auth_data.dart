import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../../core/services/token_storage_service.dart';
import '../../../model/user_model.dart';

class AuthData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> activateEmployee({
    required String activationCode,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'status': StatusRequest.failure, 'message': 'غير مسجل الدخول'};
    }

    final idToken = await user.getIdToken();

    final response = await _crud.postData(
      AppLinks.activateEmployee,
      {
        'token': idToken,
        'activation_code': activationCode,
      },
      auth: false,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
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
          'email': user.email,
        };
        await TokenStorageService.saveUserData(jsonEncode(userData));
      }
    }

    return response;
  }

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.me);
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await TokenStorageService.clearAll();
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
