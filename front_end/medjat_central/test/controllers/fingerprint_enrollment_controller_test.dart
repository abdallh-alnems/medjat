import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/biometric_data/biometric_data.dart';
import 'package:medjat_central/logic/controller/biometric/fingerprint_enrollment_controller.dart';
import '../helpers/test_helpers.dart';

class MockBiometricData extends Mock implements BiometricData {}

void main() {
  late MockBiometricData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockBiometricData();
    Get.put<BiometricData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('FingerprintEnrollmentController', () {
    test('loadStatus — نجاح', () async {
      when(() => mockData.getStatus(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'employee_id': 1,
              'biometric_enrollment_status': 'fingerprint_only',
            },
          });

      final controller = FingerprintEnrollmentController();
      await controller.loadStatus(1);

      expect(controller.enrollment, isNotNull);
      expect(controller.enrollment!.hasFingerprint, isTrue);
    });

    test('enrollFingerprint — نجاح يعيد true', () async {
      when(() => mockData.enrollFingerprint(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getStatus(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'biometric_enrollment_status': 'fingerprint_only'},
          });

      final controller = FingerprintEnrollmentController();
      final result = await controller.enrollFingerprint(1, 'template_base64');

      expect(result, isTrue);
      expect(controller.status, StatusRequest.success);
    });

    test('enrollFingerprint — فشل يعيد false', () async {
      when(() => mockData.enrollFingerprint(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = FingerprintEnrollmentController();
      final result = await controller.enrollFingerprint(1, 'template_base64');

      expect(result, isFalse);
      expect(controller.status, StatusRequest.failure);
    });
  });
}
