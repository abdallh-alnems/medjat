import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/document_report_model.dart';

void main() {
  group('DocumentReportModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 10,
        'employee_id': 5,
        'employee_name': 'محمد',
        'branch_id': 2,
        'branch_name': 'الفرع الشرقي',
        'required_document_id': 3,
        'document_name': 'إقامة',
        'category': 'identity',
        'file_path': '/docs/residence.pdf',
        'original_name': 'residence.pdf',
        'status': 'valid',
        'expires_at': '2025-12-31T23:59:59Z',
      };

      final doc = DocumentReportModel.fromJson(json);

      expect(doc.documentId, 10);
      expect(doc.employeeId, 5);
      expect(doc.employeeName, 'محمد');
      expect(doc.branchId, 2);
      expect(doc.branchName, 'الفرع الشرقي');
      expect(doc.requiredDocumentId, 3);
      expect(doc.documentName, 'إقامة');
      expect(doc.category, 'identity');
      expect(doc.filePath, '/docs/residence.pdf');
      expect(doc.originalName, 'residence.pdf');
      expect(doc.status, 'valid');
      expect(doc.expiresAt, isNotNull);
    });

    test('يستخدم document_id كـ id بديل', () {
      final json = {
        'document_id': 99,
        'employee_id': 1,
        'employee_name': 'أحمد',
        'document_name': 'جواز',
      };

      final doc = DocumentReportModel.fromJson(json);
      expect(doc.documentId, 99);
    });

    test('بيانات ناقصة/null', () {
      final doc = DocumentReportModel.fromJson({});

      expect(doc.documentId, 0);
      expect(doc.employeeId, 0);
      expect(doc.employeeName, '');
      expect(doc.branchId, isNull);
      expect(doc.branchName, isNull);
      expect(doc.requiredDocumentId, isNull);
      expect(doc.documentName, '');
      expect(doc.category, isNull);
      expect(doc.filePath, isNull);
      expect(doc.originalName, isNull);
      expect(doc.status, 'required');
      expect(doc.expiresAt, isNull);
    });
  });
}
