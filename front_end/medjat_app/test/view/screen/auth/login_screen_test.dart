import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/core/constant/locale/translations.dart';
import 'package:medjat_app/core/constant/theme/app_theme.dart';
import 'package:medjat_app/core/services/locale_service.dart';
import 'package:medjat_app/data/model/user_model.dart';
import 'package:medjat_app/logic/controller/auth/auth_controller.dart';
import 'package:medjat_app/view/screen/auth/login_screen.dart';

import '../../../helpers/test_helpers.dart';

class FakeAuthController extends GetxController implements AuthController {
  @override
  final Rx<StatusRequest> status = StatusRequest.none.obs;

  @override
  final RxBool isLoggedInObs = false.obs;

  @override
  UserModel? user;

  @override
  Future<void> login({required String phone, required String code}) async {}

  @override
  Future<bool> activateWithToken(String token) async => false;

  @override
  bool isLoggedIn() => isLoggedInObs.value && user != null;

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
    translations: AppTranslations(),
    locale: const Locale('ar'),
    fallbackLocale: const Locale('ar'),
    home: const LoginScreen(),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // GetStorage.init() needs path_provider, which has no implementation in
    // widget tests; stub the channel so LocaleService's storage works.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '.',
    );
    await GetStorage.init();
  });

  setUp(() {
    setupGetTestBindings();
    Get.put<GetStorage>(GetStorage());
    Get.put<LocaleService>(LocaleService());
    Get.put<AuthController>(FakeAuthController());
  });

  tearDown(() {
    Get.reset();
  });

  group('LoginScreen', () {
    testWidgets('renders phone and activation code fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الدخول'), findsNWidgets(2));
      expect(find.text('رقم الهاتف'), findsOneWidget);
      expect(find.text('كود التفعيل'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows helper text about requesting credentials',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(
        find.text('اطلب رقم هاتفك وكود التفعيل من إدارة الشركة'),
        findsOneWidget,
      );
    });

    testWidgets('shows kiosk mode button', (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('وضع الكيوسك'), findsOneWidget);
    });

    testWidgets('no email or password or Google controls',
        (WidgetTester tester) async {
      await tester.pumpWidget(_createTestApp());
      await tester.pumpAndSettle();

      expect(find.text('البريد الإلكتروني'), findsNothing);
      expect(find.text('كلمة المرور'), findsNothing);
      expect(find.text('الدخول بحساب Google'), findsNothing);
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
  });
}
