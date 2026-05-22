import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/deduction_rule_model.dart';

void main() {
  group('DeductionRuleModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'type': 'late_proportional',
        'name': 'خصم تأخير نسبي',
        'value': 1.5,
        'unit': 'percentage',
        'is_active': true,
      };

      final rule = DeductionRuleModel.fromJson(json);

      expect(rule.id, 1);
      expect(rule.type, 'late_proportional');
      expect(rule.name, 'خصم تأخير نسبي');
      expect(rule.value, 1.5);
      expect(rule.unit, 'percentage');
      expect(rule.isActive, isTrue);
    });

    test('بيانات ناقصة/null', () {
      final rule = DeductionRuleModel.fromJson({});

      expect(rule.id, 0);
      expect(rule.type, 'late_proportional');
      expect(rule.name, '');
      expect(rule.value, 0);
      expect(rule.unit, 'fixed');
      expect(rule.isActive, isTrue);
    });

    test('toJson', () {
      final rule = DeductionRuleModel.fromJson({
        'id': 1,
        'type': 'custom',
        'name': 'خصم مخصص',
        'value': 100,
        'unit': 'fixed',
        'is_active': false,
      });

      final json = rule.toJson();

      expect(json['type'], 'custom');
      expect(json['name'], 'خصم مخصص');
      expect(json['value'], 100);
      expect(json['unit'], 'fixed');
      expect(json['is_active'], isFalse);
    });

    test('رحلة ذهاب وعودة', () {
      final original = DeductionRuleModel.fromJson({
        'id': 1,
        'type': 'absence',
        'name': 'خصم غياب',
        'value': 200,
        'unit': 'fixed',
        'is_active': true,
      });

      final json = original.toJson();
      final restored = DeductionRuleModel.fromJson(json);

      expect(restored.type, original.type);
      expect(restored.name, original.name);
      expect(restored.value, original.value);
      expect(restored.unit, original.unit);
      expect(restored.isActive, original.isActive);
    });
  });
}
