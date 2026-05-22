import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/core/constant/theme/app_theme.dart';
import 'package:medjat_app/data/data_source/remote/auth_data/auth_data.dart';
import 'package:medjat_app/data/model/user_model.dart';
import 'package:medjat_app/logic/controller/auth/auth_controller.dart';
import 'package:medjat_app/view/screen/auth/login_screen.dart';

import '../../../helpers/test_helpers.dart';

class FakeAuthController extends GetxController implements AuthController {
  @override
  final Rx<StatusRequest> status = StatusRequest.none.obs;

  @override
  final RxBool isLoggedIn = false.obs;

  @override
  final RxBool isActivated = false.obs;

  @override
  UserModel? user;

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> activateWithCode(String activationCode) async {}

  @override
  Future<void> loadProfile() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<bool> checkAuth() async => false;
}

Widget _createTestApp() {
  return GetMaterialApp(
    theme: AppTheme.light(),
    home: const LoginScreen(),
  );
}

void main() {
  setUp(() {
    setupGetTestBindings();
    Get.put<AuthController>(FakeAuthController());
  });

  tearDown(() {
    Get.reset();
  });

  group('LoginScreen', () {
    testWidgets('renders login form with expected fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الدخول'), findsNWidgets(2));
      expect(find.text('سجّل دخولك بحسابك لتفعيل التطبيق'), findsOneWidget);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows validation errors on empty submit',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      final loginButton = find.byType(ElevatedButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.text('مطلوب'), findsWidgets);
    });

    testWidgets('shows validation error for invalid email',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'invalid-email',
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('بريد غير صالح'), findsOneWidget);
    });

    testWidgets('shows validation error for short password',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).last,
        '12345',
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('6 أحرف على الأقل'), findsOneWidget);
    });

    testWidgets('toggles to activation form', (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('كود التفعيل'), findsNothing);

      final toggleButton = find.text('لديّ كود تفعيل');
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('أدخل كود التفعيل'), findsOneWidget);
      expect(find.text('كود التفعيل'), findsOneWidget);
      expect(find.text('تفعيل'), findsOneWidget);
    });

    testWidgets('toggles back to login form', (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('لديّ كود تفعيل'));
      await tester.pumpAndSettle();

      expect(find.text('العودة لتسجيل الدخول'), findsOneWidget);

      await tester.tap(find.text('العودة لتسجيل الدخول'));
      await tester.pumpAndSettle();

      expect(find.text('البريد الإلكتروني'), findsOneWidget);
    });

    testWidgets('activation form validates empty code',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('لديّ كود تفعيل'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تفعيل'));
      await tester.pumpAndSettle();

      expect(find.text('مطلوب'), findsOneWidget);
    });

    testWidgets('shows Google sign-in button', (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('الدخول بحساب Google'), findsOneWidget);
    });

    testWidgets('shows fingerprint icon', (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });
  });
}
