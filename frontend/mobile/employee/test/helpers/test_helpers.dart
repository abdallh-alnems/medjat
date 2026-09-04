import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:permedjat_app/core/class/crud.dart';
import 'package:permedjat_app/data/model/user_model.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockCRUD extends Mock implements CRUD {}

http.Response fakeResponse({
  int statusCode = 200,
  String body = '{}',
}) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void setupGetTestBindings() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Get.testMode = true;
}

void setupDotenvForTest() {
  dotenv.testLoad(mergeWith: {
    'API_HOST': 'http://test-api.example.com',
    'SECURITY_USER': 'testuser',
    'SECURITY_KEY': 'testkey',
  });
}

UserModel createTestUser({
  int id = 1,
  int tenantId = 1,
  int branchId = 1,
  String name = 'أحمد',
  String email = 'ahmed@test.com',
  String roleKey = 'employee',
  String? jobTitle = 'مهندس',
  String? branchName = 'الفرع الرئيسي',
}) {
  return UserModel(
    id: id,
    tenantId: tenantId,
    branchId: branchId,
    name: name,
    email: email,
    roleKey: roleKey,
    jobTitle: jobTitle,
    branchName: branchName,
  );
}

void registerFallbacks() {
  registerFallbackValue(Uri.parse('http://test.com'));
  registerFallbackValue(http.Request('GET', Uri.parse('http://test.com')));
  registerFallbackValue('');
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(<String, String>{});
}
