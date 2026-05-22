import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_app/core/utils/version_compare.dart';

void main() {
  group('isVersionLower', () {
    test('1.0.0 is lower than 2.0.0', () {
      expect(isVersionLower('1.0.0', '2.0.0'), true);
    });

    test('2.0.0 is not lower than 1.0.0', () {
      expect(isVersionLower('2.0.0', '1.0.0'), false);
    });

    test('equal versions return false', () {
      expect(isVersionLower('1.2.3', '1.2.3'), false);
    });

    test('1.2.0 is lower than 1.3.0', () {
      expect(isVersionLower('1.2.0', '1.3.0'), true);
    });

    test('1.2.3 is lower than 1.2.4', () {
      expect(isVersionLower('1.2.3', '1.2.4'), true);
    });

    test('1.2.4 is not lower than 1.2.3', () {
      expect(isVersionLower('1.2.4', '1.2.3'), false);
    });

    test('shorter version padded with zeros', () {
      expect(isVersionLower('1.0', '1.0.1'), true);
    });

    test('shorter version equal prefix', () {
      expect(isVersionLower('1.2', '1.2.0'), false);
    });

    test('build number ignored (+5)', () {
      expect(isVersionLower('1.0.0+5', '1.0.1'), true);
    });

    test('pre-release ignored (-beta)', () {
      expect(isVersionLower('1.0.0-beta', '1.0.1'), true);
    });

    test('current higher than minimum', () {
      expect(isVersionLower('2.5.0', '1.0.0'), false);
    });

    test('0.0.1 is lower than 0.0.2', () {
      expect(isVersionLower('0.0.1', '0.0.2'), true);
    });

    test('single segment comparison', () {
      expect(isVersionLower('1', '2'), true);
    });

    test('non-numeric segments treated as 0', () {
      expect(isVersionLower('a.b.c', '0.0.1'), true);
    });

    test('complex version with build and pre-release', () {
      expect(isVersionLower('2.3.4-beta+10', '2.3.5'), true);
    });

    test('same major different minor', () {
      expect(isVersionLower('2.1.0', '2.2.0'), true);
      expect(isVersionLower('2.2.0', '2.1.0'), false);
    });
  });
}
