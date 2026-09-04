import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/document_stats_model.dart';

void main() {
  group('DocumentStatsModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'total_required': 100,
        'total_uploaded': 80,
        'total_missing': 15,
        'total_expired': 3,
        'total_expiring_soon': 2,
      };

      final stats = DocumentStatsModel.fromJson(json);

      expect(stats.totalRequired, 100);
      expect(stats.totalUploaded, 80);
      expect(stats.totalMissing, 15);
      expect(stats.totalExpired, 3);
      expect(stats.totalExpiringSoon, 2);
    });

    test('بيانات ناقصة تعطي أصفار', () {
      final stats = DocumentStatsModel.fromJson({});

      expect(stats.totalRequired, 0);
      expect(stats.totalUploaded, 0);
      expect(stats.totalMissing, 0);
      expect(stats.totalExpired, 0);
      expect(stats.totalExpiringSoon, 0);
    });
  });
}
