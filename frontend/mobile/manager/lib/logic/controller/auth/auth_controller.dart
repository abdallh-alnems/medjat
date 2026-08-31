import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/class/crud.dart';
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
  final isDeletingAccount = false.obs;
  final isUpdatingProfile = false.obs;

  UserModel? user;

  /// A team invitation waiting for the signed-in email (set from the login
  /// response when the user has no company yet). Lets onboarding offer a
  /// one-tap "Join {company}". Null when there's no pending invitation.
  Map<String, dynamic>? pendingInvitation;

  /// Invite code captured from a `medjatcentral://join?code=...` deep link
  /// (the email's "open the app and join" button). Consumed by the onboarding
  /// screen, which joins the company automatically once the user is signed in.
  String? pendingInviteCode;

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
    CRUD.onSessionSuperseded = _onSessionSuperseded;
    CRUD.onForceLogout = _forceLogout;
  }

  bool _handlingForceLogout = false;

  /// Called by CRUD when the backend reports this device's session was
  /// replaced by a login on another phone.
  void _onSessionSuperseded() => _forceLogout(
        'تم تسجيل الدخول من جهاز آخر، تم إنهاء الجلسة على هذا الجهاز',
      );

  /// Sign out locally (no network call — it would just fail again) and return
  /// to the login screen with [message]. Used when the session is superseded,
  /// or when the account was removed from the company / suspended.
  void _forceLogout(String message) {
    if (_handlingForceLogout) return;
    _handlingForceLogout = true;
    () async {
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {}
      await TokenStorageService.clearAll();
      user = null;
      isLoggedIn.value = false;
      hasTenant.value = false;
      if (Get.currentRoute != AppRoutes.login) {
        unawaited(Get.offAllNamed<void>(AppRoutes.login));
      }
      Get.snackbar(
        'تنبيه',
        message,
        snackPosition: SnackPosition.BOTTOM,
      );
      _handlingForceLogout = false;
    }();
  }

  @override
  void onClose() {
    _deepLinkSub?.cancel();
    if (CRUD.onSessionSuperseded == _onSessionSuperseded) {
      CRUD.onSessionSuperseded = null;
    }
    if (CRUD.onForceLogout == _forceLogout) {
      CRUD.onForceLogout = null;
    }
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
      onError: (Object e) => debugPrint('deep link error: $e'),
    );
  }

  void _handleDeepLink(Uri uri) {
    // Team-invitation hand-off from the email, via either:
    //   • Universal / App Link:  https://medjatapp.com/join_team?code=XXXX
    //   • custom-scheme bridge:  medjatcentral://join?code=XXXX
    final isHttpsInvite =
        (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.path.contains('join_team');
    final isSchemeInvite = uri.scheme == _kDeepLinkScheme &&
        (uri.host == 'join' || uri.pathSegments.contains('join'));
    if (isHttpsInvite || isSchemeInvite) {
      final code = uri.queryParameters['code']?.trim();
      if (code != null && code.isNotEmpty) {
        _handleInviteCode(code);
        return;
      }
    }

    // Other links only concern the custom scheme (e.g. email-verification).
    if (uri.scheme != _kDeepLinkScheme) return;
    checkEmailVerified(silent: true);
  }

  /// Route an invite code captured from a deep link. Onboarding consumes
  /// [pendingInviteCode] and joins automatically once the user is signed in.
  void _handleInviteCode(String code) {
    pendingInviteCode = code;
    if (isLoggedIn.value && !hasTenant.value) {
      Get.offAllNamed<void>(AppRoutes.onboarding);
    } else if (!isLoggedIn.value) {
      if (Get.currentRoute != AppRoutes.login) {
        Get.offAllNamed<void>(AppRoutes.login);
      }
    } else {
      Get.snackbar('alert'.tr, 'already_in_company'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _listenToAuthState() {
    _authStateStream = _auth.authStateChanges();
    _authStateStream!.listen((firebaseUser) async {
      if (firebaseUser == null) {
        if (isLoggedIn.value) {
          isLoggedIn.value = false;
          user = null;
          unawaited(Get.offAllNamed<void>(AppRoutes.login));
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
          unawaited(Get.offAllNamed<void>(AppRoutes.verifyEmail));
        }
        return;
      }

      if (firebaseUser.emailVerified && isLoggedIn.value) {
        // Force-refresh so the freshly minted token carries the `name` claim
        // set via updateDisplayName at signup; otherwise the backend falls
        // back to the email's local-part as the name.
        final token = await firebaseUser.getIdToken(true);
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
        _onError('login_failed'.tr);
        return;
      }

      if (!userCredential.user!.emailVerified) {
        isEmailLoading.value = false;
        isEmailVerified.value = false;
        status.value = StatusRequest.success;
        unawaited(Get.offAllNamed<void>(AppRoutes.verifyEmail));
        update();
        return;
      }

      final firebaseToken = await userCredential.user!.getIdToken();
      if (firebaseToken == null) {
        isEmailLoading.value = false;
        _onError('token_failed'.tr);
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isEmailLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('server_failed'.tr);
      }
    } on FirebaseAuthException catch (e) {
      isEmailLoading.value = false;
      status.value = StatusRequest.failure;
      Get.snackbar('error'.tr, _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isEmailLoading.value = false;
      _onError('login_error'.tr);
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
        _onError('signup_failed'.tr);
        return;
      }

      await userCredential.user!.updateDisplayName(name);
      await userCredential.user!.reload();

      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null && !firebaseUser.emailVerified) {
        try {
          await _sendVerificationEmail();
        } catch (e) {
          debugPrint('⚠️ sendEmailVerification failed during signup: $e');
          Get.snackbar(
            'alert'.tr,
            'signup_verification_failed'.tr,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        isEmailLoading.value = false;
        status.value = StatusRequest.success;
        isEmailVerified.value = false;
        unawaited(Get.offAllNamed<void>(AppRoutes.verifyEmail));
        update();
        return;
      }

      // Force-refresh so the token carries the `name` claim just set via
      // updateDisplayName; otherwise the backend names the admin after the
      // email's local-part on this first (creating) call.
      final firebaseToken = await _auth.currentUser?.getIdToken(true);
      if (firebaseToken == null) {
        isEmailLoading.value = false;
        _onError('token_failed'.tr);
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isEmailLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('server_failed'.tr);
      }
    } on FirebaseAuthException catch (e) {
      isEmailLoading.value = false;
      status.value = StatusRequest.failure;
      Get.snackbar('error'.tr, _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isEmailLoading.value = false;
      _onError('signup_error'.tr);
    }
  }

  Future<void> onGoogleSignIn() async {
    try {
      isGoogleLoading.value = true;
      status.value = StatusRequest.loading;
      update();

      final UserCredential userCredential;
      if (Platform.isIOS) {
        // On iOS the google_sign_in plugin's authenticate() flow is unreliable
        // (it errors before reaching the backend), so we use Firebase's native
        // OAuth provider flow instead — the exact mechanism already used for
        // Apple sign-in below. It reuses the reversed-client-id URL scheme that
        // is already configured in Info.plist, so no extra setup is needed.
        final googleProvider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        userCredential = await _auth.signInWithProvider(googleProvider);
      } else {
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

        userCredential = await _auth.signInWithCredential(credential);
      }

      if (userCredential.user == null) {
        isGoogleLoading.value = false;
        _onError('login_failed'.tr);
        return;
      }

      final firebaseToken = await userCredential.user!.getIdToken();
      if (firebaseToken == null) {
        isGoogleLoading.value = false;
        _onError('token_failed'.tr);
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isGoogleLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('server_failed'.tr);
      }
    } on GoogleSignInException catch (e) {
      isGoogleLoading.value = false;
      status.value = StatusRequest.failure;
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      Get.snackbar('error'.tr, _getGoogleErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } on FirebaseAuthException catch (e) {
      isGoogleLoading.value = false;
      status.value = StatusRequest.failure;
      // User dismissed the OAuth sheet — not an error worth surfacing.
      if (e.code == 'canceled' || e.code == 'web-context-canceled') return;
      Get.snackbar('error'.tr, _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isGoogleLoading.value = false;
      _onError('login_error'.tr);
    }
  }

  Future<void> onAppleSignIn() async {
    if (!isAppleSignInAvailable) {
      Get.snackbar('error'.tr, 'apple_ios_only'.tr,
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
        _onError('login_failed'.tr);
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
        _onError('token_failed'.tr);
        return;
      }

      final success = await _sendTokenToBackend(firebaseToken);
      isAppleLoading.value = false;

      if (success) {
        _onSuccess();
      } else {
        _onError('server_failed'.tr);
      }
    } on FirebaseAuthException catch (e) {
      isAppleLoading.value = false;
      status.value = StatusRequest.failure;
      debugPrint('🍎 Apple FirebaseAuthException code=${e.code} message=${e.message}');
      if (e.code == 'canceled' || e.code == 'web-context-canceled') return;
      Get.snackbar('error'.tr, _getFirebaseErrorMessage(e.code),
          snackPosition: SnackPosition.BOTTOM);
      update();
    } catch (e) {
      isAppleLoading.value = false;
      debugPrint('🍎 Apple sign-in unexpected error: $e');
      _onError('login_error'.tr);
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
          final pi = payload['pending_invitation'];
          pendingInvitation = pi is Map ? Map<String, dynamic>.from(pi) : null;
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
      Get.offAllNamed<void>(AppRoutes.home);
    } else {
      Get.offAllNamed<void>(AppRoutes.onboarding);
    }
    update();
  }

  void _onError(String message) {
    status.value = StatusRequest.failure;
    Get.snackbar('error'.tr, message, snackPosition: SnackPosition.BOTTOM);
    update();
  }

  /// Sends our own branded verification email via the backend. The link inside
  /// opens Firebase's default verification page.
  Future<void> _sendVerificationEmail() async {
    final lang = Get.locale?.languageCode ?? 'ar';
    final response = await _authData.sendVerification(lang);
    if (response['status'] != StatusRequest.success) {
      throw Exception('send_verification_failed');
    }
  }

  Future<void> logout() async {
    // Notify the backend first, while the Firebase token is still valid, so it
    // can clear our active session device. Failures are ignored — the local
    // session is cleared regardless.
    try {
      await _authData.logout();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (_) {}
    user = null;
    isLoggedIn.value = false;
    unawaited(Get.offAllNamed<void>(AppRoutes.login));
  }

  /// Permanently deletes the account from the backend (DB + Firebase) and then
  /// clears the local session. If the caller is the last general_manager, the
  /// backend deletes the whole company too.
  /// Updates the signed-in user's own name and/or phone. Persists to the
  /// backend, mirrors the name to the Firebase display name, then refreshes
  /// the cached [user] so the UI reflects the change immediately.
  Future<bool> updateProfile({
    required String name,
    String? phone,
  }) async {
    if (isUpdatingProfile.value) return false;
    isUpdatingProfile.value = true;
    try {
      final response = await _authData.updateProfile(name: name, phone: phone);
      if (response.containsKey('error')) {
        Get.snackbar('error'.tr, 'profile_update_error'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      // Best-effort: keep Firebase display name in sync (non-blocking).
      try {
        await _auth.currentUser?.updateDisplayName(name);
      } catch (_) {}

      if (user != null) {
        user = user!.copyWith(
          name: name,
          phone: (phone == null || phone.isEmpty) ? null : phone,
        );
        await TokenStorageService.saveUserData(jsonEncode(user!.toJson()));
        update();
      }

      Get.back<void>();
      Get.snackbar('done'.tr, 'profile_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      debugPrint('updateProfile error: $e');
      Get.snackbar('error'.tr, 'profile_update_error'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isUpdatingProfile.value = false;
    }
  }

  Future<void> deleteAccount() async {
    if (isDeletingAccount.value) return;
    isDeletingAccount.value = true;
    try {
      final response = await _authData.deleteAccount();
      if (response['status'] != StatusRequest.success) {
        isDeletingAccount.value = false;
        Get.snackbar('error'.tr, 'delete_account_failed'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      // Backend already removed the Firebase user; sign out locally to clear
      // any cached credentials/state.
      try {
        await _googleSignIn.signOut();
        await _auth.signOut();
      } catch (_) {}

      await _authData.logout();
      user = null;
      isLoggedIn.value = false;
      isDeletingAccount.value = false;
      unawaited(Get.offAllNamed<void>(AppRoutes.login));
      Get.snackbar('done'.tr, 'delete_account_success'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      isDeletingAccount.value = false;
      debugPrint('❌ deleteAccount error: $e');
      Get.snackbar('error'.tr, 'delete_account_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> resendVerificationEmail() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    isSendingVerification.value = true;
    try {
      await _sendVerificationEmail();
      Get.snackbar('done'.tr, 'activation_link_resent'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('❌ sendEmailVerification error: $e');
      Get.snackbar('error'.tr, e.toString(),
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
      // Force-refresh so the token carries the `name` claim from
      // updateDisplayName; the backend creates the admin row on this first
      // call and would otherwise name it after the email's local-part.
      final token = await firebaseUser.getIdToken(true);
      if (token != null) {
        final success = await _sendTokenToBackend(token);
        if (success) {
          _onSuccess();
        } else {
          _onError('server_failed'.tr);
        }
      }
    } else if (!silent) {
      Get.snackbar('alert'.tr, 'email_not_verified'.tr,
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
        return 'firebase_invalid_email'.tr;
      case 'user-disabled':
        return 'firebase_user_disabled'.tr;
      case 'user-not-found':
        return 'firebase_user_not_found'.tr;
      case 'wrong-password':
        return 'firebase_wrong_password'.tr;
      case 'email-already-in-use':
        return 'firebase_email_in_use'.tr;
      case 'weak-password':
        return 'firebase_weak_password'.tr;
      case 'too-many-requests':
        return 'firebase_too_many_requests'.tr;
      case 'network-request-failed':
        return 'firebase_network_failed'.tr;
      case 'account-exists-with-different-credential':
        return 'firebase_account_exists'.tr;
      case 'invalid-credential':
        return 'firebase_invalid_credential'.tr;
      case 'operation-not-allowed':
        return 'firebase_operation_not_allowed'.tr;
      case 'invalid-continue-uri':
        return 'firebase_invalid_continue_uri'.tr;
      case 'unauthorized-continue-uri':
        return 'firebase_unauthorized_uri'.tr;
      default:
        return 'firebase_unknown_error'.tr;
    }
  }

  String _getGoogleErrorMessage(GoogleSignInExceptionCode code) {
    switch (code) {
      case GoogleSignInExceptionCode.canceled:
        return 'google_canceled'.tr;
      case GoogleSignInExceptionCode.interrupted:
        return 'google_interrupted'.tr;
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'google_ui_unavailable'.tr;
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'google_client_error'.tr;
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'google_provider_error'.tr;
      case GoogleSignInExceptionCode.userMismatch:
        return 'google_user_mismatch'.tr;
      case GoogleSignInExceptionCode.unknownError:
        return 'google_unknown_error'.tr;
    }
  }
}
