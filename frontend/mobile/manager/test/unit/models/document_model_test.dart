import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/document_model.dart';

void main() {
  group('DocumentModel.fromJson', () {
    test('بيانات كاملة مع expires_at', () {
      final json = {
        'id': 1,
        'employee_id': 5,
        'required_document_id': 10,
        'document_name': 'جواز السفر',
        'file_url': 'https://example.com/doc.pdf',
        'original_name': 'passport.pdf',
        'file_path': '/uploads/doc.pdf',
        'file_size': 1024,
        'mime_type': 'application/pdf',
        'status': 'uploaded',
        'expires_at': '2025-06-30',
        'created_at': '2024-01-15T10:00:00',
        'notes': 'ملاحظات',
        'rejected_reason': null,
        'verified_at': '2024-02-01T12:00:00',
        'category': 'identity',
      };

      final doc = DocumentModel.fromJson(json);

      expect(doc.id, 1);
      expect(doc.employeeId, 5);
      expect(doc.requiredDocumentId, 10);
      expect(doc.name, 'جواز السفر');
      expect(doc.fileUrl, 'https://example.com/doc.pdf');
      expect(doc.originalName, 'passport.pdf');
      expect(doc.filePath, '/uploads/doc.pdf');
      expect(doc.fileSize, 1024);
      expect(doc.mimeType, 'application/pdf');
      expect(doc.status, 'uploaded');
      expect(doc.expiryDate, DateTime(2025, 6, 30));
      expect(doc.uploadedAt, DateTime(2024, 1, 15, 10));
      expect(doc.notes, 'ملاحظات');
      expect(doc.rejectedReason, isNull);
      expect(doc.verifiedAt, DateTime(2024, 2, 1, 12));
      expect(doc.category, 'identity');
    });

    test('name يقرأ من document_name أو name', () {
      expect(
        DocumentModel.fromJson({'document_name': 'A'}).name,
        'A',
      );
      expect(
        DocumentModel.fromJson({'name': 'B'}).name,
        'B',
      );
      expect(
        DocumentModel.fromJson({'document_name': 'A', 'name': 'B'}).name,
        'A',
      );
    });

    test('expiry_date كحقل بديل', () {
      final doc = DocumentModel.fromJson({
        'expiry_date': '2025-12-31',
      });

      expect(doc.expiryDate, DateTime(2025, 12, 31));
    });

    test('uploaded_at كحقل بديل', () {
      final doc = DocumentModel.fromJson({
        'uploaded_at': '2024-03-01T08:00:00',
      });

      expect(doc.uploadedAt, DateTime(2024, 3, 1, 8));
    });

    test('بيانات ناقصة/null', () {
      final doc = DocumentModel.fromJson({});

      expect(doc.id, 0);
      expect(doc.employeeId, 0);
      expect(doc.requiredDocumentId, isNull);
      expect(doc.name, '');
      expect(doc.status, 'required');
      expect(doc.expiryDate, isNull);
      expect(doc.uploadedAt, isNull);
    });

    test('حالات مختلفة', () {
      for (final s in ['uploaded', 'required', 'expired', 'rejected']) {
        final doc = DocumentModel.fromJson({'status': s});
        expect(doc.status, s);
      }
    });
  });
}
