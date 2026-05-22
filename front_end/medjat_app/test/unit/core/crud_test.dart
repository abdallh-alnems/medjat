import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockHttpClient mockClient;
  late CRUD crud;

  setUp(() {
    registerFallbacks();
    mockClient = MockHttpClient();
    crud = CRUD(client: mockClient);
  });

  group('CRUD', () {
    group('handleResponse', () {
      test('returns success on 200 with valid JSON', () {
        final response = fakeResponse(
          statusCode: 200,
          body: jsonEncode({'message': 'ok'}),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.success);
        expect((result['data'] as Map)['message'], 'ok');
      });

      test('returns success on 201 with null body', () {
        final response = fakeResponse(statusCode: 201, body: 'not json');
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.success);
        expect(result['data'], isNull);
      });

      test('returns failure with 401 message', () {
        final response = fakeResponse(statusCode: 401);
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.failure);
        expect(result['statusCode'], 401);
      });

      test('returns failure with 403 message', () {
        final response = fakeResponse(statusCode: 403);
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.failure);
        expect(result['statusCode'], 403);
      });

      test('returns failure with 404 and custom message', () {
        final response = fakeResponse(
          statusCode: 404,
          body: jsonEncode({'message': 'غير موجود'}),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.failure);
        expect(result['statusCode'], 404);
        expect(result['message'], 'غير موجود');
      });

      test('returns failure with 404 default message when no body', () {
        final response = fakeResponse(statusCode: 404, body: 'bad');
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.failure);
        expect(result['statusCode'], 404);
      });

      test('returns failure with 422 and errors', () {
        final response = fakeResponse(
          statusCode: 422,
          body: jsonEncode({
            'message': 'Validation failed',
            'errors': {'field': ['required']},
          }),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.failure);
        expect(result['statusCode'], 422);
        expect(result['message'], 'Validation failed');
        expect(result['errors'], isNotNull);
      });

      test('returns serverFailure on 500 with custom message', () {
        final response = fakeResponse(
          statusCode: 500,
          body: jsonEncode({'message': 'Internal server error'}),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.serverFailure);
        expect(result['statusCode'], 500);
        expect(result['message'], 'Internal server error');
      });

      test('returns serverFailure on 500 with default message', () {
        final response = fakeResponse(statusCode: 500, body: 'not json');
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.serverFailure);
      });

      test('returns success on 204', () {
        final response = fakeResponse(statusCode: 204, body: '');
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.success);
      });
    });
  });
}
