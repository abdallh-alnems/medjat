import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/biometric_enrollment_model.dart';

void main() {
  group('BiometricEnrollmentModel.fromJson', () {
    test('بيانات كاملة - both', () {
      final json = {
        'employee_id': 1,
        'biometric_enrollment_status': 'both',
        'face_enrolled_at': '2025-01-01T10:00:00Z',
        'fingerprint_enrolled_at': '2025-02-01T10:00:00Z',
        'face_quality_score': 0.95,
        'has_linked_account': 1,
      };

      final model = BiometricEnrollmentModel.fromJson(json);

      expect(model.employeeId, 1);
      expect(model.status, 'both');
      expect(model.faceEnrolledAt, isNotNull);
      expect(model.fingerprintEnrolledAt, isNotNull);
      expect(model.faceQualityScore, 0.95);
      expect(model.hasLinkedAccount, isTrue);
      expect(model.hasFace, isTrue);
      expect(model.hasFingerprint, isTrue);
      expect(model.isEnrolled, isTrue);
    });

    test('بيانات ناقصة - not_enrolled', () {
      final model = BiometricEnrollmentModel.fromJson({});

      expect(model.employeeId, 0);
      expect(model.status, 'not_enrolled');
      expect(model.faceEnrolledAt, isNull);
      expect(model.fingerprintEnrolledAt, isNull);
      expect(model.faceQualityScore, isNull);
      expect(model.hasLinkedAccount, isFalse);
      expect(model.hasFace, isFalse);
      expect(model.hasFingerprint, isFalse);
      expect(model.isEnrolled, isFalse);
    });

    test('status = face_only', () {
      final model = BiometricEnrollmentModel.fromJson({
        'biometric_enrollment_status': 'face_only',
      });
      expect(model.hasFace, isTrue);
      expect(model.hasFingerprint, isFalse);
      expect(model.isEnrolled, isTrue);
    });

    test('status = fingerprint_only', () {
      final model = BiometricEnrollmentModel.fromJson({
        'biometric_enrollment_status': 'fingerprint_only',
      });
      expect(model.hasFace, isFalse);
      expect(model.hasFingerprint, isTrue);
      expect(model.isEnrolled, isTrue);
    });
  });
}
