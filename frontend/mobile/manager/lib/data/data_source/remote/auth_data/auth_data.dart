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

  /// Asks the backend to send our own branded verification email.
  /// The link inside opens Firebase's default verification page.
  /// The firebase id token is attached automatically by CRUD as a header.
  Future<Map<String, dynamic>> sendVerification(String lang) async {
    return await _crud.postData(
      AppLinks.sendVerification,
      {'lang': lang},
    );
  }

  /// Asks the backend to send our own branded password-reset email.
  /// The link inside opens Firebase's default reset page.
  /// Unauthenticated; the backend always returns success (enumeration safe).
  Future<Map<String, dynamic>> sendPasswordReset(
      String email, String lang) async {
    return await _crud.postData(
      AppLinks.sendPasswordReset,
      {'email': email, 'lang': lang},
      auth: false,
    );
  }

  Future<Map<String, dynamic>> logout() async {
    return await _crud.postData(AppLinks.logout, {});
  }

  /// Updates the signed-in admin's own name and/or phone in the backend.
  /// Sending an empty phone clears it.
  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
  }) async {
    return await _crud.postData(AppLinks.updateProfile, {
      'name': ?name,
      'phone': ?phone,
    });
  }

  /// Permanently deletes the account (and the company, if the caller is the
  /// last general_manager) from the backend DB and Firebase.
  Future<Map<String, dynamic>> deleteAccount() async {
    return await _crud.postData(AppLinks.deleteAccount, {});
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
