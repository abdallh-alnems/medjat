import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/required_document_model.dart';

void main() {
  group('RequiredDocumentModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'name': 'إقامة',
        'description': 'نسخة من الإقامة',
        'expiry_days': 365,
        'notification_days_before': 30,
        'category': 'identity',
        'sort_order': 1,
        'is_required': 1,
        'is_active': 1,
        'scope_type': 'all',
        'scope_employee_ids': [1, 2, 3],
        'scope_category_ids': [10],
      };

      final doc = RequiredDocumentModel.fromJson(json);

      expect(doc.id, 1);
      expect(doc.name, 'إقامة');
      expect(doc.description, 'نسخة من الإقامة');
      expect(doc.expiryDays, 365);
      expect(doc.notificationDaysBefore, 30);
      expect(doc.category, 'identity');
      expect(doc.sortOrder, 1);
      expect(doc.isRequired, isTrue);
      expect(doc.isActive, isTrue);
      expect(doc.scopeType, 'all');
      expect(doc.scopeEmployeeIds, [1, 2, 3]);
      expect(doc.scopeCategoryIds, [10]);
    });

    test('بيانات ناقصة', () {
      final doc = RequiredDocumentModel.fromJson({});

      expect(doc.id, 0);
      expect(doc.name, '');
      expect(doc.description, isNull);
      expect(doc.expiryDays, isNull);
      expect(doc.notificationDaysBefore, 30);
      expect(doc.category, 'general');
      expect(doc.isRequired, isFalse);
      expect(doc.isActive, isFalse);
      expect(doc.scopeType, 'all');
      expect(doc.scopeEmployeeIds, <int>[]);
      expect(doc.scopeCategoryIds, <int>[]);
    });

    test('scope_employee_ids كنصوص تتحول لأرقام', () {
      final doc = RequiredDocumentModel.fromJson({
        'scope_employee_ids': ['5', '10'],
      });
      expect(doc.scopeEmployeeIds, [5, 10]);
    });

    test('scope_employee_ids يفلتر الأصفار', () {
      final doc = RequiredDocumentModel.fromJson({
        'scope_employee_ids': [0, 5, 0],
      });
      expect(doc.scopeEmployeeIds, [5]);
    });

    test('toCreateJson يحتوي الحقول المطلوبة', () {
      final doc = RequiredDocumentModel(
        id: 1,
        name: 'جواز',
        scopeType: 'branch',
        scopeBranchId: 5,
      );

      final json = doc.toCreateJson();
      expect(json['name'], 'جواز');
      expect(json['scope_type'], 'branch');
      expect(json['scope_branch_id'], 5);
      expect(json.containsKey('id'), isFalse);
    });

    test('toUpdateJson يحتوي id', () {
      final doc = RequiredDocumentModel(id: 10, name: 'إقامة');

      final json = doc.toUpdateJson();
      expect(json['id'], 10);
      expect(json['name'], 'إقامة');
    });

    test('copyWith يعدل القيم المحددة فقط', () {
      final original = RequiredDocumentModel(id: 1, name: 'إقامة');
      final copy = original.copyWith(name: 'جواز');

      expect(copy.id, 1);
      expect(copy.name, 'جواز');
    });
  });
}
