import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/warning_model.dart';

void main() {
  group('WarningModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'type': 'written',
        'reason': 'تأخير متكرر',
        'issued_by_name': 'المدير',
        'created_at': '2024-06-01T10:00:00',
      };

      final w = WarningModel.fromJson(json);

      expect(w.id, 1);
      expect(w.type, 'written');
      expect(w.reason, 'تأخير متكرر');
      expect(w.issuedByName, 'المدير');
      expect(w.createdAt, DateTime(2024, 6, 1, 10));
    });

    test('بيانات ناقصة/null', () {
      final w = WarningModel.fromJson({});

      expect(w.id, 0);
      expect(w.type, '');
      expect(w.reason, '');
      expect(w.issuedByName, isNull);
      expect(w.createdAt, isNull);
    });

    test('أنواع مختلفة', () {
      for (final t in ['verbal', 'written', 'final', 'device_change', 'system']) {
        final w = WarningModel.fromJson({'type': t});
        expect(w.type, t);
      }
    });
  });
}
