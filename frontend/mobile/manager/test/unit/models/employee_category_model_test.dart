import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/employee_category_model.dart';

void main() {
  group('EmployeeCategoryModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'name': 'إداري',
        'description': 'الفئة الإدارية',
        'color': '#FF5733',
        'is_active': 1,
        'employee_count': 15,
      };

      final cat = EmployeeCategoryModel.fromJson(json);

      expect(cat.id, 1);
      expect(cat.name, 'إداري');
      expect(cat.description, 'الفئة الإدارية');
      expect(cat.color, '#FF5733');
      expect(cat.isActive, isTrue);
      expect(cat.employeeCount, 15);
    });

    test('بيانات ناقصة/null', () {
      final cat = EmployeeCategoryModel.fromJson({});

      expect(cat.id, 0);
      expect(cat.name, '');
      expect(cat.description, isNull);
      expect(cat.color, isNull);
      expect(cat.isActive, isFalse);
      expect(cat.employeeCount, 0);
    });

    test('is_active = 0 يعطي false', () {
      final cat = EmployeeCategoryModel.fromJson({'is_active': 0});
      expect(cat.isActive, isFalse);
    });

    test('toCreateJson', () {
      final cat = EmployeeCategoryModel.fromJson({
        'id': 1,
        'name': 'إداري',
        'description': 'وصف',
        'color': '#FFF',
        'is_active': 1,
      });

      final json = cat.toCreateJson();

      expect(json['name'], 'إداري');
      expect(json['description'], 'وصف');
      expect(json['color'], '#FFF');
      expect(json.containsKey('id'), isFalse);
    });

    test('toCreateJson بدون description و color', () {
      final cat = EmployeeCategoryModel.fromJson({
        'id': 1,
        'name': 'إداري',
      });

      final json = cat.toCreateJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('color'), isFalse);
    });

    test('toUpdateJson', () {
      final cat = EmployeeCategoryModel.fromJson({
        'id': 1,
        'name': 'إداري',
        'description': 'وصف',
        'color': '#FFF',
        'is_active': 1,
      });

      final json = cat.toUpdateJson();

      expect(json['id'], 1);
      expect(json['name'], 'إداري');
      expect(json['description'], 'وصف');
      expect(json['is_active'], 1);
    });

    test('copyWith', () {
      final cat = EmployeeCategoryModel.fromJson({
        'id': 1,
        'name': 'إداري',
        'description': 'وصف',
      });

      final copy = cat.copyWith(name: 'فني');

      expect(copy.id, 1);
      expect(copy.name, 'فني');
      expect(copy.description, 'وصف');
    });
  });
}
