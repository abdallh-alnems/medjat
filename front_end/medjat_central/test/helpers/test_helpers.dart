import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void setupTestBinding() {
  TestWidgetsFlutterBinding.ensureInitialized();
  dotenv.testLoad(fileInput: 'SECURITY_USER=u\nSECURITY_KEY=k\nAPI_HOST=https://api.test.com');
}

void setupGetX() {
  Get.testMode = true;
}

void teardownGetX() {
  Get.reset();
}
