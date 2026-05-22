import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../data/model/user_model.dart';

class AuthController extends GetxController {
  final AuthData _authData = Get.find<AuthData>();

  final status = StatusRequest.none.obs;
  final isLoggedIn = false.obs;
  final isActivated = false.obs;
  UserModel? user;

  @override
  void onInit() {
    super.onInit();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final cached = await _authData.getCachedUser();
      if (cached != null && cached.tenantId != 0) {
        user = cached;
        isLoggedIn.value = true;
        isActivated.value = true;
      } else {
        isLoggedIn.value = true;
        isActivated.value = false;
      }
    }
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    status.value = StatusRequest.loading;
    update();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final cached = await _authData.getCachedUser();
      if (cached != null && cached.tenantId != 0) {
        user = cached;
        isLoggedIn.value = true;
        isActivated.value = true;
        status.value = StatusRequest.success;
        Get.offAllNamed<void>(AppRoutes.home);
      } else {
        isLoggedIn.value = true;
        isActivated.value = false;
        status.value = StatusRequest.success;
        Get.offAllNamed<void>(AppRoutes.login);
      }
    } on FirebaseAuthException catch (e) {
      status.value = StatusRequest.failure;
      String message = 'حدث خطأ، حاول مرة أخرى';
      if (e.code == 'user-not-found') {
        message = 'البريد الإلكتروني غير مسجل';
      } else if (e.code == 'wrong-password') {
        message = 'كلمة المرور غير صحيحة';
      } else if (e.code == 'invalid-email') {
        message = 'البريد الإلكتروني غير صالح';
      } else if (e.code == 'invalid-credential') {
        message = 'بيانات الدخول غير صحيحة';
      } else if (e.code == 'too-many-requests') {
        message = 'محاولات كثيرة، حاول لاحقاً';
      }
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', 'حدث خطأ، حاول مرة أخرى',
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> signInWithGoogle() async {
    status.value = StatusRequest.loading;
    update();

    try {
      final googleUser = await GoogleSignIn.instance.authenticate();

      final auth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final cached = await _authData.getCachedUser();
      if (cached != null && cached.tenantId != 0) {
        user = cached;
        isLoggedIn.value = true;
        isActivated.value = true;
        status.value = StatusRequest.success;
        Get.offAllNamed<void>(AppRoutes.home);
      } else {
        isLoggedIn.value = true;
        isActivated.value = false;
        status.value = StatusRequest.success;
        Get.offAllNamed<void>(AppRoutes.login);
      }
    } on FirebaseAuthException catch (e) {
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', e.message ?? 'حدث خطأ في تسجيل الدخول',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', 'حدث خطأ، حاول مرة أخرى',
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> activateWithCode(String activationCode) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _authData.activateEmployee(
      activationCode: activationCode.trim(),
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data?['employee'] != null) {
        final employee = data!['employee'] as Map<String, dynamic>;
        user = UserModel(
          id: (employee['id'] as int?) ?? 0,
          tenantId: (employee['tenant_id'] as int?) ?? 0,
          branchId: (employee['branch_id'] as int?) ?? 0,
          name: (employee['name'] as String?) ?? '',
          email: FirebaseAuth.instance.currentUser?.email ?? '',
          branchName: employee['branch_name'] as String?,
          jobTitle: employee['job_title'] as String?,
          roleKey: 'employee',
        );
        isActivated.value = true;
        isLoggedIn.value = true;
        status.value = StatusRequest.success;
        Get.offAllNamed<void>(AppRoutes.home);
      }
    } else {
      status.value = StatusRequest.failure;
      final statusCode = response['statusCode'];
      String message =
          (response['message'] as String?) ?? 'حدث خطأ، حاول مرة أخرى';

      if (statusCode == 404) {
        message = 'كود التفعيل غير صالح أو منتهي';
      } else if (statusCode == 422) {
        message = 'كود التفعيل مطلوب';
      }

      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> loadProfile() async {
    final response = await _authData.getProfile();
    if (response['status'] == StatusRequest.success &&
        response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      if (data['employee'] != null) {
        final emp = data['employee'] as Map<String, dynamic>;
        user = UserModel(
          id: (emp['id'] as int?) ?? 0,
          tenantId: (emp['tenant_id'] as int?) ?? 0,
          branchId: (emp['branch_id'] as int?) ?? 0,
          name: (emp['name'] as String?) ?? '',
          email: FirebaseAuth.instance.currentUser?.email ?? '',
          phone: emp['phone'] as String?,
          photoUrl: emp['photo_url'] as String?,
          roleKey: 'employee',
          jobTitle: emp['job_title'] as String?,
          branchName: emp['branch_name'] as String?,
        );
        await TokenStorageService.saveUserData(jsonEncode(user!.toJson()));
        update();
      }
    }
  }

  Future<void> logout() async {
    await _authData.logout();
    user = null;
    isLoggedIn.value = false;
    isActivated.value = false;
    Get.offAllNamed<void>(AppRoutes.login);
  }

  Future<bool> checkAuth() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return false;

    final cached = await _authData.getCachedUser();
    if (cached != null) {
      user = cached;
      isLoggedIn.value = true;
      isActivated.value = cached.tenantId != 0;
      return true;
    }
    return false;
  }
}
