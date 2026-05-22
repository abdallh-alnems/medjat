import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/document_template_model.dart';

void main() {
  group('DocumentTemplateModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'template_key': 'bank_letter',
        'name_ar': 'خطاب بنكي',
        'name_en': 'Bank Letter',
        'body_ar': 'مرحبا {{bank_name}}',
        'body_en': 'Hello {{bank_name}}',
        'is_system': 1,
        'is_active': 1,
        'sort_order': 2,
      };

      final tmpl = DocumentTemplateModel.fromJson(json);

      expect(tmpl.id, 1);
      expect(tmpl.templateKey, 'bank_letter');
      expect(tmpl.nameAr, 'خطاب بنكي');
      expect(tmpl.nameEn, 'Bank Letter');
      expect(tmpl.bodyAr, 'مرحبا {{bank_name}}');
      expect(tmpl.bodyEn, 'Hello {{bank_name}}');
      expect(tmpl.isSystem, isTrue);
      expect(tmpl.isActive, isTrue);
      expect(tmpl.sortOrder, 2);
    });

    test('بيانات ناقصة', () {
      final tmpl = DocumentTemplateModel.fromJson({});

      expect(tmpl.id, 0);
      expect(tmpl.templateKey, isNull);
      expect(tmpl.nameAr, '');
      expect(tmpl.nameEn, isNull);
      expect(tmpl.bodyAr, '');
      expect(tmpl.bodyEn, isNull);
      expect(tmpl.isSystem, isFalse);
      expect(tmpl.isActive, isFalse);
      expect(tmpl.sortOrder, 0);
    });

    test('is_system كـ bool true', () {
      final tmpl = DocumentTemplateModel.fromJson({'is_system': true});
      expect(tmpl.isSystem, isTrue);
    });

    test('is_active كنص "true"', () {
      final tmpl = DocumentTemplateModel.fromJson({'is_active': 'true'});
      expect(tmpl.isActive, isTrue);
    });

    test('needsBankName يعتمد على template_key', () {
      final tmpl = DocumentTemplateModel.fromJson({'template_key': 'bank_letter'});
      expect(tmpl.needsBankName, isTrue);
    });

    test('needsBankName يعتمد على body_ar يحتوي {{bank_name}}', () {
      final tmpl = DocumentTemplateModel.fromJson({
        'template_key': 'custom',
        'body_ar': 'نص {{bank_name}} عادي',
      });
      expect(tmpl.needsBankName, isTrue);
    });

    test('needsBankName = false لنوع آخر', () {
      final tmpl = DocumentTemplateModel.fromJson({
        'template_key': 'salary_cert',
        'body_ar': 'شهادة راتب',
      });
      expect(tmpl.needsBankName, isFalse);
    });

    test('id كنص يتحول لعدد', () {
      final tmpl = DocumentTemplateModel.fromJson({'id': '5'});
      expect(tmpl.id, 5);
    });
  });
}
