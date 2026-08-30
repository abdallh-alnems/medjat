import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/performance_review_model.dart';

void main() {
  group('PerformanceReviewModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'employee_id': 5,
        'reviewer_name': 'المدير',
        'rating': 4,
        'period': '2024-Q1',
        'notes': 'أداء جيد',
        'created_at': '2024-03-31T10:00:00',
      };

      final r = PerformanceReviewModel.fromJson(json);

      expect(r.id, 1);
      expect(r.employeeId, 5);
      expect(r.reviewerName, 'المدير');
      expect(r.rating, 4);
      expect(r.period, '2024-Q1');
      expect(r.notes, 'أداء جيد');
      expect(r.createdAt, DateTime(2024, 3, 31, 10));
    });

    test('بيانات ناقصة/null', () {
      final r = PerformanceReviewModel.fromJson({});

      expect(r.id, 0);
      expect(r.employeeId, 0);
      expect(r.reviewerName, isNull);
      expect(r.rating, 1);
      expect(r.period, '');
      expect(r.notes, isNull);
      expect(r.createdAt, isNull);
    });

    test('تقييمات من 1 إلى 5', () {
      for (var i = 1; i <= 5; i++) {
        final r = PerformanceReviewModel.fromJson({'rating': i});
        expect(r.rating, i);
      }
    });
  });
}
