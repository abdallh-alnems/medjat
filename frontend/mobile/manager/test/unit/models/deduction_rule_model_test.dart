import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/deduction_rule_model.dart';

void main() {
  group('LateTier.fromJson', () {
    test('بيانات كاملة', () {
      final tier = LateTier.fromJson({
        'id': 1,
        'threshold_minutes': 30,
        'deduction_days': 0.5,
      });

      expect(tier.id, 1);
      expect(tier.thresholdMinutes, 30);
      expect(tier.deductionDays, 0.5);
    });

    test('بيانات ناقصة/null', () {
      final tier = LateTier.fromJson({});

      expect(tier.id, isNull);
      expect(tier.thresholdMinutes, 0);
      expect(tier.deductionDays, 0);
    });

    test('toJson يرجع threshold و deduction فقط', () {
      final tier = LateTier.fromJson({
        'id': 5,
        'threshold_minutes': 45,
        'deduction_days': 1.0,
      });

      final json = tier.toJson();

      expect(json['threshold_minutes'], 45);
      expect(json['deduction_days'], 1.0);
      expect(json.containsKey('id'), isFalse);
    });

    test('copyWith يبقي id ويحدّث القيم', () {
      const tier = LateTier(
        id: 2,
        thresholdMinutes: 20,
        deductionDays: 0.5,
      );

      final updated = tier.copyWith(deductionDays: 1.0);

      expect(updated.id, 2);
      expect(updated.thresholdMinutes, 20);
      expect(updated.deductionDays, 1.0);
    });
  });

  group('DeductionConfig.fromJson', () {
    test('يفرز الـ tiers تصاعدياً حسب threshold', () {
      final config = DeductionConfig.fromJson({
        'tiers': [
          {'threshold_minutes': 60, 'deduction_days': 1.0},
          {'threshold_minutes': 15, 'deduction_days': 0.25},
          {'threshold_minutes': 30, 'deduction_days': 0.5},
        ],
        'absence_days': 2.0,
      });

      expect(config.tiers.length, 3);
      expect(config.tiers[0].thresholdMinutes, 15);
      expect(config.tiers[1].thresholdMinutes, 30);
      expect(config.tiers[2].thresholdMinutes, 60);
      expect(config.absenceDays, 2.0);
    });

    test('بيانات فارغة تستخدم الإعدادات الافتراضية', () {
      final config = DeductionConfig.fromJson({});

      expect(config.tiers, isEmpty);
      expect(config.absenceDays, 1.5);
    });

    test('absence_days null يستخدم الافتراضي 1.5', () {
      final config = DeductionConfig.fromJson({'tiers': <Map<String, dynamic>>[]});

      expect(config.absenceDays, 1.5);
    });
  });
}
