import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

import 'package:medjat_app/data/model/user_model.dart';

class MockHttpClient extends Mock implements http.Client {}

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
}
