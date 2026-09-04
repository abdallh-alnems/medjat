import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:permedjat_app/core/class/crud.dart';
import 'package:permedjat_app/core/class/status_request.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockHttpClient mockClient;
  late CRUD crud;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockClient = MockHttpClient();
    crud = CRUD(client: mockClient);
  });

  group('CRUD', () {
    group('buildUri', () {
      test('keeps a query string baked into the URL', () {
        // The AppGallery payslip bug: month and format were dropped, so the
        // endpoint answered JSON for the current month instead of a PDF.
        final uri = CRUD.buildUri(
          'https://api.example.com/get_slip.php?month=2026-04&format=pdf',
          null,
        );

        expect(uri.queryParameters['month'], '2026-04');
        expect(uri.queryParameters['format'], 'pdf');
      });

      test('keeps the baked-in query when an empty map is passed', () {
        final uri = CRUD.buildUri(
          'https://api.example.com/get_slip.php?month=2026-04&format=pdf',
          <String, dynamic>{},
        );

        expect(uri.queryParameters['month'], '2026-04');
        expect(uri.queryParameters['format'], 'pdf');
      });

      test('merges explicit parameters on top of the baked-in ones', () {
        final uri = CRUD.buildUri(
          'https://api.example.com/list.php?month=2026-04',
          {'id': 7, 'page': 2},
        );

        expect(uri.queryParameters['month'], '2026-04');
        expect(uri.queryParameters['id'], '7');
        expect(uri.queryParameters['page'], '2');
      });

      test('explicit parameters win over a baked-in duplicate', () {
        final uri = CRUD.buildUri(
          'https://api.example.com/list.php?month=2026-04',
          {'month': '2026-05'},
        );

        expect(uri.queryParameters['month'], '2026-05');
      });
    });

    group('handleResponse', () {
      test('returns success on 200 with valid JSON', () {
        final response = fakeResponse(
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

      test('returns success on 202', () {
        final response = fakeResponse(
          statusCode: 202,
          body: jsonEncode({'accepted': true}),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.success);
        expect((result['data'] as Map)['accepted'], true);
      });

      test('returns success on 200 with list body', () {
        final response = fakeResponse(
          body: jsonEncode([1, 2, 3]),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.success);
        expect(result['data'], isA<List<dynamic>>());
      });

      test('returns serverFailure on 503 with message', () {
        final response = fakeResponse(
          statusCode: 503,
          body: jsonEncode({'message': 'Service unavailable'}),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.serverFailure);
        expect(result['statusCode'], 503);
        expect(result['message'], 'Service unavailable');
      });

      test('returns serverFailure on 502 default message', () {
        final response = fakeResponse(statusCode: 502, body: 'bad gateway');
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.serverFailure);
        expect(result['statusCode'], 502);
      });

      test('401 returns session expired message key', () {
        final response = fakeResponse(statusCode: 401);
        final result = crud.handleResponse(response);

        expect(result['message'], 'session_expired_server');
      });

      test('401 invokes onSessionExpired callback exactly once', () {
        int callCount = 0;
        CRUD.onSessionExpired = () {
          callCount++;
        };

        final response = fakeResponse(statusCode: 401);
        crud.handleResponse(response);

        expect(callCount, 1);

        CRUD.onSessionExpired = null;
      });

      test('401 does not invoke onSessionExpired when callback is null', () {
        CRUD.onSessionExpired = null;

        final response = fakeResponse(statusCode: 401);
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.failure);
      });

      test('403 returns permission denied message key', () {
        final response = fakeResponse(statusCode: 403);
        final result = crud.handleResponse(response);

        expect(result['message'], 'no_permission');
      });

      test('404 returns default message key', () {
        final response = fakeResponse(statusCode: 404, body: 'not json');
        final result = crud.handleResponse(response);

        expect(result['message'], 'data_not_found');
      });

      test('404 with empty message uses default', () {
        final response = fakeResponse(
          statusCode: 404,
          body: jsonEncode({'message': ''}),
        );
        final result = crud.handleResponse(response);

        expect(result['message'], 'data_not_found');
      });

      test('422 with non-json body uses default message', () {
        final response = fakeResponse(statusCode: 422, body: 'bad');
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.failure);
        expect(result['message'], 'invalid_data');
      });

      test('422 with null message uses default', () {
        final response = fakeResponse(
          statusCode: 422,
          body: jsonEncode({'errors': {'field': ['required']}}),
        );
        final result = crud.handleResponse(response);

        expect(result['message'], 'invalid_data');
      });

      test('500 with non-map body returns serverFailure', () {
        final response = fakeResponse(
          statusCode: 500,
          body: jsonEncode('just a string'),
        );
        final result = crud.handleResponse(response);

        expect(result['status'], StatusRequest.serverFailure);
        expect(result['message'], 'error_try_again');
      });

      test('500 with empty message returns default', () {
        final response = fakeResponse(
          statusCode: 500,
          body: jsonEncode({'message': ''}),
        );
        final result = crud.handleResponse(response);

        expect(result['message'], 'error_try_again');
      });
    });
  });
}
