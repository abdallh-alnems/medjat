import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void setupTestBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
  dotenv.testLoad(fileInput: 'SECURITY_USER=u\nSECURITY_KEY=k\nAPI_HOST=https://api.test.com');

  // `flutter_timezone` has no implementation under test. Left unmocked it is
  // answered through the platform message queue, which a `testWidgets` fake
  // clock never turns — so a controller awaiting it (CompanySettingsController
  // auto-detects the zone for a company that never chose one) hangs until the
  // 10-minute wall-clock guard, and `--timeout` cannot cut it short because
  // fake time never advances. Answering null resolves it immediately and keeps
  // the production path identical: detection simply finds nothing.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter_timezone'),
    (_) async => null,
  );
}

void setupGetX() {
  Get.testMode = true;
}

void teardownGetX() {
  Get.reset();
}

/// Pumps a minimal [GetMaterialApp] so that controller code calling
/// `Get.snackbar(...)` has a valid navigator overlay during unit tests.
Future<void> pumpSnackbarHost(WidgetTester tester) async {
  await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
}

/// Lets any snackbar triggered by the action display and auto-dismiss so the
/// test ends with no pending timers.
Future<void> settleSnackbars(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}
