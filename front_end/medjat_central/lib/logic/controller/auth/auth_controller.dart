import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../data/model/user_model.dart';

class AuthController extends GetxController {
  AuthController({
    FirebaseAuth? auth,
    AuthData? authData,
    GoogleSignIn? googleSignIn,
  })  : _authOverride = auth,
        _authDataOverride = authData,
        _googleSignInOverride = googleSignIn;

  final FirebaseAuth? _authOverride;
  final AuthData? _authDataOverride;
  final GoogleSignIn? _googleSignInOverride;

  late final FirebaseAuth _auth;
  late final AuthData _authData;
  late final GoogleSignIn _googleSignIn;

  final status = StatusRequest.none.obs;
  final isLoggedIn = false.obs;
  final hasTenant = false.obs;
  final isEmailLoading = false.obs;
  final isGoogleLoading = false.obs;
  final isAppleLoading = false.obs;
  final isSendingVerification = false.obs;
  final isEmailVerified = false.obs;

  UserModel? user;
  bool _googleInitialized = false;
  Stream<User?>? _authStateStream;
  StreamSubscription<Uri>? _deepLinkSub;

  bool get isAppleSignInAvailable => Platform.isIOS || Platform.isMacOS;

  static const _kDeepLinkScheme = 'medjatcentral';

  @override
  void onInit() {
    super.onInit();
    _auth = _authOverride ?? FirebaseAuth.instance;
    _authData = _authDataOverride ?? Get.find<AuthData>();
    _googleSignIn = _googleSignInOverride ?? GoogleSignIn.instance;
    _loadCachedUser();
    _listenToAuthState();
    _listenToDeepLinks();
  }

  @override
  void onClose() {
    _deepLinkSub?.cancel();
    super.onClose();
  }

  void _listenToDeepLinks() {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final appLinks = AppLinks();
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
    _deepLinkSub = appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) => debugPrint('deep link error: $e'),
    );
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme != _kDeepLinkScheme) return;

    checkEmailVerified(silent: true);
  }

  void _listenToAuthState() {
    _authStateStream = _auth.authStateChanges();
    _authStateStream!.listen((firebaseUser) async {
      if (firebaseUser == null) {
        if (isLoggedIn.value) {
          isLoggedIn.value = false;
          user = null;
          Get.offAllNamed(AppRoutes.login);
        }
        return;
      }

      await firebaseUser.reload();
      isEmailVerified.value = firebaseUser.emailVerified;

      if (!firebaseUser.emailVerified && !isEmailVerified.value) {
        final current = Get.currentRoute;
        if (current != AppRoutes.verifyEmail &&
            current != AppRoutes.login &&
            current != AppRoutes.signup) {
          Get.offAllNamed(AppRoutes.verifyEmail);
        }
        return;
      }

      if (firebaseUser.emailVerified && isLoggedIn.value) {
        final token = await firebaseUser.getIdToken();
        if (token != null) {
          final success = await _sendTokenToBackend(token);
          if (success) _onSuccess();
        }
      }
    });
  }

  Future<void> _loadCachedUser() async {
    user = await _authData.getCachedUser();
    final firebaseUser = _auth.currentUser;
    if (user != null && firebaseUser != null) {
      isLoggedIn.value = true;
      hasTenant.value = user!.tenantId > 0;
    }
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    isEmailLoading.value = true;
    status.value = StatusRequest.loading;
    update();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        isEmailLoading.value = false;
        _onError('فشل تسجيل الدخول');
        return;
      }

      if (!userCredential.user!.emailVerified) {
        isEmailLoading.value = false;
        isEmailVerified.value = false;
        status.value = StatusRequest.success;
        Get.offAllNamed(AppRoutes.verifyEmail);
        update();
        return;
      }

      final firebaseToken = await userCredential.user!.getIdToken();
      if (firebaseToken == null) {
        isEmailLoading.value = false;
        _onError('فشل الحصول على رمز الدخول');
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isEmailLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('فشل الاتصال بالخادم');
      }
    } on FirebaseAuthException catch (e) {
      isEmailLoading.value = false;
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isEmailLoading.value = false;
      _onError('حدث خطأ أثناء تسجيل الدخول');
    }
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    isEmailLoading.value = true;
    status.value = StatusRequest.loading;
    update();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        isEmailLoading.value = false;
        _onError('فشل إنشاء الحساب');
        return;
      }

      await userCredential.user!.updateDisplayName(name);
      await userCredential.user!.reload();

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null && !firebaseUser.emailVerified) {
        try {
          await _auth.setLanguageCode(Get.locale?.languageCode ?? 'ar');
          await _sendVerificationEmail(firebaseUser);
        } catch (e) {
          debugPrint('⚠️ sendEmailVerification failed during signup: $e');
          Get.snackbar(
            'تنبيه',
            'تم إنشاء الحساب، لكن تعذّر إرسال بريد التفعيل. استخدم زر "إعادة الإرسال".',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        isEmailLoading.value = false;
        status.value = StatusRequest.success;
        isEmailVerified.value = false;
        Get.offAllNamed(AppRoutes.verifyEmail);
        update();
        return;
      }

      final firebaseToken = await _auth.currentUser?.getIdToken();
      if (firebaseToken == null) {
        isEmailLoading.value = false;
        _onError('فشل الحصول على رمز الدخول');
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isEmailLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('فشل الاتصال بالخادم');
      }
    } on FirebaseAuthException catch (e) {
      isEmailLoading.value = false;
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isEmailLoading.value = false;
      _onError('حدث خطأ أثناء إنشاء الحساب');
    }
  }

  Future<void> onGoogleSignIn() async {
    try {
      isGoogleLoading.value = true;
      status.value = StatusRequest.loading;
      update();

      if (!_googleInitialized) {
        await _googleSignIn.initialize(
          serverClientId:
              '510933674549-otcm2dholnti3pnq8iuoo2qo2jrh7amj.apps.googleusercontent.com',
        );
        _googleInitialized = true;
      }

      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email', 'profile']);
      final accessToken = authorization?.accessToken;

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        isGoogleLoading.value = false;
        _onError('فشل تسجيل الدخول');
        return;
      }

      final firebaseToken = await userCredential.user!.getIdToken();
      if (firebaseToken == null) {
        isGoogleLoading.value = false;
        _onError('فشل الحصول على رمز الدخول');
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isGoogleLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('فشل الاتصال بالخادم');
      }
    } on GoogleSignInException catch (e) {
      isGoogleLoading.value = false;
      status.value = StatusRequest.failure;
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      Get.snackbar('خطأ', _getGoogleErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } on FirebaseAuthException catch (e) {
      isGoogleLoading.value = false;
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isGoogleLoading.value = false;
      _onError('حدث خطأ أثناء تسجيل الدخول');
    }
  }

  Future<void> onAppleSignIn() async {
    if (!isAppleSignInAvailable) {
      Get.snackbar('خطأ', 'تسجيل الدخول بـ Apple متاح فقط على iOS',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      isAppleLoading.value = true;
      status.value = StatusRequest.loading;
      update();

      final appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');

      final userCredential = await _auth.signInWithProvider(appleProvider);

      if (userCredential.user == null) {
        isAppleLoading.value = false;
        _onError('فشل تسجيل الدخول');
        return;
      }

      final firebaseUser = userCredential.user!;
      if (firebaseUser.displayName == null ||
          firebaseUser.displayName!.isEmpty) {
        String? extractedName;
        final profile = userCredential.additionalUserInfo?.profile;
        if (profile != null) {
          final nameField = profile['name'];
          if (nameField is String && nameField.isNotEmpty) {
            extractedName = nameField;
          } else if (nameField is Map) {
            final first = nameField['firstName'] as String?;
            final last = nameField['lastName'] as String?;
            extractedName =
                [first, last].where((s) => s != null && s.isNotEmpty).join(' ');
          }
        }
        if (extractedName == null || extractedName.isEmpty) {
          extractedName = _extractNameFromEmail(firebaseUser.email);
        }
        if (extractedName != null && extractedName.isNotEmpty) {
          await firebaseUser.updateDisplayName(extractedName);
          await firebaseUser.reload();
        }
      }

      final firebaseToken = await _auth.currentUser?.getIdToken(true);
      if (firebaseToken == null) {
        isAppleLoading.value = false;
        _onError('فشل الحصول على رمز الدخول');
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isAppleLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('فشل الاتصال بالخادم');
      }
    } on FirebaseAuthException catch (e) {
      isAppleLoading.value = false;
      status.value = StatusRequest.failure;
      debugPrint('🍎 Apple FirebaseAuthException code=${e.code} message=${e.message}');
      if (e.code == 'canceled' || e.code == 'web-context-canceled') return;
      Get.snackbar('خطأ', _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isAppleLoading.value = false;
      debugPrint('🍎 Apple sign-in unexpected error: $e');
      _onError('حدث خطأ أثناء تسجيل الدخول');
    }
  }

  Future<bool> _sendTokenToBackend(String token) async {
    try {
      final response = await _authData.login(token);
      debugPrint('📦 backend response: $response');
      if (response['status'] == StatusRequest.success) {
        var payload = response['data'];
        if (payload is Map<String, dynamic> && payload.containsKey('data')) {
          payload = payload['data'];
        }
        if (payload is Map<String, dynamic> && payload['success'] == true) {
          final userData = payload['user'] as Map<String, dynamic>?;
          if (userData != null) {
            user = UserModel.fromJson(userData);
            await TokenStorageService.saveUserData(jsonEncode(user!.toJson()));
            hasTenant.value = user!.tenantId > 0;
            return true;
          }
        }
      }
      debugPrint('❌ _sendTokenToBackend unexpected response: ${response['data']}');
      return false;
    } catch (e) {
      debugPrint('❌ _sendTokenToBackend error: $e');
      return false;
    }
  }

  void _onSuccess() {
    isLoggedIn.value = true;
    status.value = StatusRequest.success;
    // Notification permission is requested from the home page (TabShell),
    // not here — so it only appears after the user has a company/tenant.
    if (hasTenant.value) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offAllNamed(AppRoutes.onboarding);
    }
    update();
  }

  void _onError(String message) {
    status.value = StatusRequest.failure;
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    update();
  }

  Future<void> _sendVerificationEmail(User user) async {
    await user.sendEmailVerification();
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (_) {}
    await _authData.logout();
    user = null;
    isLoggedIn.value = false;
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> resendVerificationEmail() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    isSendingVerification.value = true;
    try {
      await _auth.setLanguageCode(Get.locale?.languageCode ?? 'ar');
      await _sendVerificationEmail(firebaseUser);
      Get.snackbar('تم', 'تم إرسال رابط التفعيل إلى بريدك الإلكتروني',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('❌ sendEmailVerification error: $e');
      Get.snackbar('خطأ', e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    }
    isSendingVerification.value = false;
  }

  Future<void> checkEmailVerified({bool silent = false}) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    await firebaseUser.reload();
    isEmailVerified.value = firebaseUser.emailVerified;

    if (firebaseUser.emailVerified) {
      final token = await firebaseUser.getIdToken();
      if (token != null) {
        final success = await _sendTokenToBackend(token);
        if (success) {
          _onSuccess();
        } else {
          _onError('فشل الاتصال بالخادم');
        }
      }
    } else if (!silent) {
      Get.snackbar('تنبيه', 'لم يتم تفعيل البريد بعد، تحقق من بريدك الإلكتروني',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> loadProfile() async {
    final response = await _authData.getProfile();
    if (response['status'] == StatusRequest.success && response['data'] != null) {
      final data = response['data'];
      if (data['user'] != null) {
        user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await TokenStorageService.saveUserData(jsonEncode(user!.toJson()));
        update();
      }
    }
  }

  Future<bool> checkAuth() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return false;
    await _loadCachedUser();
    return user != null;
  }

  String? _extractNameFromEmail(String? email) {
    if (email == null || email.isEmpty || !email.contains('@')) return null;
    if (email.contains('@privaterelay.appleid.com')) return null;
    final localPart = email.split('@').first;
    if (localPart.isEmpty) return null;
    final cleaned = localPart
        .replaceAll(RegExp(r'[._\-+]+'), ' ')
        .replaceAll(RegExp(r'\d+'), '')
        .trim();
    if (cleaned.isEmpty) return null;
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-disabled':
        return 'تم تعطيل هذا الحساب';
      case 'user-not-found':
        return 'لم يتم العثور على حساب بهذا البريد';
      case 'wrong-password':
        return 'كلمة السر غير صحيحة';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'weak-password':
        return 'كلمة السر ضعيفة';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'network-request-failed':
        return 'فشل الاتصال بالشبكة';
      case 'account-exists-with-different-credential':
        return 'يوجد حساب مسجل بهذا البريد بطريقة أخرى';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة السر غير صحيحة';
      case 'operation-not-allowed':
        return 'طريقة تسجيل الدخول غير مفعلة';
      case 'invalid-continue-uri':
        return 'رابط التأكيد غير صالح';
      case 'unauthorized-continue-uri':
        return 'رابط التأكيد غير مصرح به';
      default:
        return 'حدث خطأ غير متوقع ($code)';
    }
  }

  String _getGoogleErrorMessage(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
        return 'تم إلغاء تسجيل الدخول';
      case GoogleSignInExceptionCode.interrupted:
        return 'تم مقاطعة عملية تسجيل الدخول';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'واجهة تسجيل الدخول غير متاحة';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'خطأ في إعدادات التطبيق';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'خطأ في إعدادات Google';
      case GoogleSignInExceptionCode.userMismatch:
        return 'عدم تطابق المستخدم';
      case GoogleSignInExceptionCode.unknownError:
        return 'حدث خطأ غير متوقع';
    }
  }
}
