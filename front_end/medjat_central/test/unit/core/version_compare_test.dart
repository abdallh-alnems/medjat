import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/core/utils/version_compare.dart';

void main() {
  group('isVersionLower', () {
    test('1.0.0 أقل من 2.0.0', () {
      expect(isVersionLower('1.0.0', '2.0.0'), isTrue);
    });

    test('2.0.0 ليس أقل من 1.0.0', () {
      expect(isVersionLower('2.0.0', '1.0.0'), isFalse);
    });

    test('1.0.0 ليس أقل من 1.0.0', () {
      expect(isVersionLower('1.0.0', '1.0.0'), isFalse);
    });

    test('1.2.0 أقل من 1.3.0', () {
      expect(isVersionLower('1.2.0', '1.3.0'), isTrue);
    });

    test('1.2.3 أقل من 1.2.4', () {
      expect(isVersionLower('1.2.3', '1.2.4'), isTrue);
    });

    test('1.2 ليس أقل من 1.2.0', () {
      expect(isVersionLower('1.2', '1.2.0'), isFalse);
    });

    test('1 أقل من 1.0.1', () {
      expect(isVersionLower('1', '1.0.1'), isTrue);
    });

    test('يتجاهل build metadata (+build)', () {
      expect(isVersionLower('1.0.0+5', '1.0.1'), isTrue);
    });

    test('يتجاهل pre-release (-beta)', () {
      expect(isVersionLower('1.0.0-beta', '1.0.1'), isTrue);
    });

    test('0.9.9 أقل من 1.0.0', () {
      expect(isVersionLower('0.9.9', '1.0.0'), isTrue);
    });

    test('2.0 ليس أقل من 1.9.9', () {
      expect(isVersionLower('2.0', '1.9.9'), isFalse);
    });
  });
}
