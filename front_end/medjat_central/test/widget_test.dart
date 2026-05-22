import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_helpers.dart';

void main() {
  test('smoke test — التأكد من إعداد بيئة الاختبار', () {
    setupTestBinding();
    expect(true, isTrue);
  });
}
