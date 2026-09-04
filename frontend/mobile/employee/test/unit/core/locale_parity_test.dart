import 'package:flutter_test/flutter_test.dart';

import 'package:permedjat_app/core/constant/locale/ar.dart';
import 'package:permedjat_app/core/constant/locale/en.dart';

void main() {
  group('locale files', () {
    test('Arabic and English define exactly the same keys', () {
      // A key present in only one file renders as the raw key (e.g.
      // "mock_location_detected") for users on the other language.
      expect(ar.keys.toSet().difference(en.keys.toSet()), isEmpty,
          reason: 'keys missing from en.dart');
      expect(en.keys.toSet().difference(ar.keys.toSet()), isEmpty,
          reason: 'keys missing from ar.dart');
    });

    test('no translation is left empty', () {
      for (final entry in {...ar, ...en}.entries) {
        expect(ar[entry.key]?.trim(), isNotEmpty, reason: 'ar: ${entry.key}');
        expect(en[entry.key]?.trim(), isNotEmpty, reason: 'en: ${entry.key}');
      }
    });

    test('every payslip line label the backend sends is translated', () {
      // Must stay in sync with the `label_key` values emitted by
      // backend/core/PayrollCalculator.php.
      const backendLabelKeys = [
        'payline_absence_day',
        'payline_absence_days',
        'payline_absence_custom',
        'payline_late_minutes',
        'payline_late_day',
        'payline_permission_minutes',
        'payline_advance_installment',
        'payline_loan_installment',
        'payline_suspension_partial',
        'payline_suspension_unpaid',
        'payline_overtime_minutes',
        'payline_leave_encashment',
        'payline_social_insurance',
        'payline_income_tax',
        'payline_allowance_housing',
        'payline_allowance_transport',
        'payline_allowance_food',
        'payline_allowance_communication',
        'payline_allowance_other',
      ];

      for (final key in backendLabelKeys) {
        expect(ar.containsKey(key), isTrue, reason: 'ar missing $key');
        expect(en.containsKey(key), isTrue, reason: 'en missing $key');
      }
    });

    test('English payslip labels carry no Arabic characters', () {
      final arabic = RegExp(r'[؀-ۿ]');
      final offenders = en.entries
          .where((e) => e.key.startsWith('payline_'))
          .where((e) => arabic.hasMatch(e.value))
          .map((e) => e.key);

      expect(offenders, isEmpty);
    });
  });
}
