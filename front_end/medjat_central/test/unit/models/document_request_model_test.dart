import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/document_request_model.dart';

void main() {
  group('DocumentRequestModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'employee_id': 10,
        'employee_name': 'أحمد',
        'template_id': 3,
        'template_name_ar': 'خطاب تعريف',
        'template_name_en': 'Introduction Letter',
        'doc_type': 'letter',
        'status': 'approved',
        'extra_fields': {'bank_name': 'الراجحي'},
        'rejection_reason': null,
        'pdf_path': '/files/doc.pdf',
        'requested_by_employee': 1,
        'created_at': '2025-05-01T10:00:00Z',
      };

      final req = DocumentRequestModel.fromJson(json);

      expect(req.id, 1);
      expect(req.employeeId, 10);
      expect(req.employeeName, 'أحمد');
      expect(req.templateId, 3);
      expect(req.templateNameAr, 'خطاب تعريف');
      expect(req.templateNameEn, 'Introduction Letter');
      expect(req.docType, 'letter');
      expect(req.status, 'approved');
      expect(req.extraFields, {'bank_name': 'الراجحي'});
      expect(req.rejectionReason, isNull);
      expect(req.hasPdf, isTrue);
      expect(req.requestedByEmployee, isTrue);
      expect(req.createdAt, isNotNull);
    });

    test('بيانات ناقصة', () {
      final req = DocumentRequestModel.fromJson({});

      expect(req.id, 0);
      expect(req.employeeId, 0);
      expect(req.employeeName, isNull);
      expect(req.templateId, isNull);
      expect(req.status, 'pending');
      expect(req.extraFields, {});
      expect(req.hasPdf, isFalse);
      expect(req.requestedByEmployee, isFalse);
      expect(req.createdAt, isNull);
    });

    test('pdf_path فارغ يعطي hasPdf = false', () {
      final req = DocumentRequestModel.fromJson({'pdf_path': '  '});
      expect(req.hasPdf, isFalse);
    });

    test('requested_by_employee كـ bool', () {
      final req = DocumentRequestModel.fromJson({
        'requested_by_employee': true,
      });
      expect(req.requestedByEmployee, isTrue);
    });

    test('requested_by_employee كـ نص "1"', () {
      final req = DocumentRequestModel.fromJson({
        'requested_by_employee': '1',
      });
      expect(req.requestedByEmployee, isTrue);
    });

    test('id كنص يتحول لعدد', () {
      final req = DocumentRequestModel.fromJson({'id': '42'});
      expect(req.id, 42);
    });
  });
}
