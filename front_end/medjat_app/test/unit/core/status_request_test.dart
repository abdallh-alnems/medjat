import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_app/core/class/status_request.dart';

void main() {
  group('StatusRequest', () {
    test('has all expected values', () {
      expect(StatusRequest.values, containsAll([
        StatusRequest.none,
        StatusRequest.loading,
        StatusRequest.offline,
        StatusRequest.serverFailure,
        StatusRequest.failure,
        StatusRequest.success,
      ]));
    });

    test('values count is 6', () {
      expect(StatusRequest.values.length, 6);
    });

    test('enum ordering matches declaration', () {
      expect(StatusRequest.values[0], StatusRequest.none);
      expect(StatusRequest.values[1], StatusRequest.loading);
      expect(StatusRequest.values[2], StatusRequest.offline);
      expect(StatusRequest.values[3], StatusRequest.serverFailure);
      expect(StatusRequest.values[4], StatusRequest.failure);
      expect(StatusRequest.values[5], StatusRequest.success);
    });

    test('name property is correct', () {
      expect(StatusRequest.none.name, 'none');
      expect(StatusRequest.loading.name, 'loading');
      expect(StatusRequest.offline.name, 'offline');
      expect(StatusRequest.serverFailure.name, 'serverFailure');
      expect(StatusRequest.failure.name, 'failure');
      expect(StatusRequest.success.name, 'success');
    });

    test('equality works correctly', () {
      expect(StatusRequest.success, equals(StatusRequest.success));
      expect(StatusRequest.failure, isNot(equals(StatusRequest.success)));
    });
  });
}
