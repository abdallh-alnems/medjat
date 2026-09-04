import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import '../../helpers/test_helpers.dart';

http.Response utf8Response(String body, int statusCode) {
  return http.Response.bytes(utf8.encode(body), statusCode);
}

void main() {
  setUp(() {
    setupTestBinding();
  });

  group('CRUD.handleResponse', () {
    late CRUD crud;

    setUp(() {
      crud = CRUD();
    });

    test('2xx مع body صالح ⇒ success + data', () {
      final response = utf8Response(jsonEncode({'user': {'id': 1}}), 200);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.success);
      expect((result['data'] as Map)['user']['id'], 1);
    });

    test('2xx مع body غير قابل للتحليل ⇒ success + data == null', () {
      final response = http.Response('not json', 200);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.success);
      expect(result['data'], isNull);
    });

    test('201 (Created) ⇒ success', () {
      final response = utf8Response(jsonEncode({'id': 5}), 201);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.success);
    });

    test('401 ⇒ failure + statusCode 401 + رسالة عربية', () {
      final response = http.Response('', 401);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.failure);
      expect(result['statusCode'], 401);
      expect(result['message'], 'جلستك انتهت، يرجى تسجيل الدخول مجدداً');
    });

    test('403 ⇒ failure + رسالة صلاحية', () {
      final response = http.Response('', 403);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.failure);
      expect(result['statusCode'], 403);
      expect(result['message'], 'ليس لديك صلاحية');
    });

    test('404 بدون message في body ⇒ رسالة افتراضية', () {
      final response = http.Response('', 404);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.failure);
      expect(result['statusCode'], 404);
      expect(result['message'], 'لم يتم العثور على البيانات');
    });

    test('404 مع message فارغ ⇒ رسالة افتراضية', () {
      final response = utf8Response(jsonEncode({'message': ''}), 404);
      final result = crud.handleResponse(response);

      expect(result['message'], 'لم يتم العثور على البيانات');
    });

    test('404 مع message في body ⇒ يقرأ الرسالة', () {
      final response = utf8Response(jsonEncode({'message': 'Employee not found'}), 404);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.failure);
      expect(result['message'], 'Employee not found');
    });

    test('422 مع message و errors', () {
      final response = utf8Response(
        jsonEncode({
          'message': 'Validation failed',
          'errors': {'email': ['already taken']},
        }),
        422,
      );
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.failure);
      expect(result['statusCode'], 422);
      expect(result['message'], 'Validation failed');
      expect(result['errors'], isNotNull);
      expect((result['errors'] as Map)['email'], isNotNull);
    });

    test('422 بدون message ⇒ رسالة افتراضية', () {
      final response = utf8Response(jsonEncode({}), 422);
      final result = crud.handleResponse(response);

      expect(result['statusCode'], 422);
      expect(result['message'], 'البيانات غير صحيحة');
    });

    test('422 مع body غير صالح ⇒ رسالة افتراضية', () {
      final response = http.Response('invalid', 422);
      final result = crud.handleResponse(response);

      expect(result['statusCode'], 422);
      expect(result['message'], 'البيانات غير صحيحة');
      expect(result.containsKey('errors'), isFalse);
    });

    test('5xx ⇒ serverFailure', () {
      final response = utf8Response(jsonEncode({'message': 'Internal error'}), 500);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.serverFailure);
      expect(result['statusCode'], 500);
      expect(result['message'], 'Internal error');
    });

    test('5xx بدون message ⇒ رسالة افتراضية', () {
      final response = http.Response('', 503);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.serverFailure);
      expect(result['message'], 'حدث خطأ، حاول مرة أخرى');
    });

    test('502 مع message في body', () {
      final response = utf8Response(jsonEncode({'message': 'Bad Gateway'}), 502);
      final result = crud.handleResponse(response);

      expect(result['status'], StatusRequest.serverFailure);
      expect(result['message'], 'Bad Gateway');
    });
  });
}
