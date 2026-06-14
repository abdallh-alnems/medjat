import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/biometric_data/biometric_data.dart';
import 'package:medjat_central/logic/controller/biometric/face_enrollment_controller.dart';
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

  group('FaceEnrollmentController', () {
    test('loadStatus — نجاح', () async {
      when(() => mockData.getStatus(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'employee_id': 1,
              'biometric_enrollment_status': 'face_only',
              'face_quality_score': 0.9,
            },
          });

      final controller = FaceEnrollmentController();
      await controller.loadStatus(1);

      expect(controller.status, StatusRequest.success);
      expect(controller.enrollment, isNotNull);
      expect(controller.enrollment!.hasFace, isTrue);
    });

    test('loadStatus — فشل', () async {
      when(() => mockData.getStatus(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = FaceEnrollmentController();
      await controller.loadStatus(1);

      expect(controller.status, StatusRequest.failure);
    });

    test('enrollFace — نجاح يعيد true', () async {
      when(() => mockData.enrollFace(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getStatus(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'biometric_enrollment_status': 'face_only'},
          });

      final controller = FaceEnrollmentController();
      final result = await controller.enrollFace(1, [0.1, 0.2], 'base64', 0.95);

      expect(result, isTrue);
    });

    test('enrollFace — فشل يعيد false', () async {
      when(() => mockData.enrollFace(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = FaceEnrollmentController();
      final result = await controller.enrollFace(1, [], 'base64', 0.5);

      expect(result, isFalse);
      expect(controller.status, StatusRequest.failure);
    });

    test('deleteBiometric — نجاح يعيد true', () async {
      when(() => mockData.delete(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getStatus(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'biometric_enrollment_status': 'not_enrolled'},
          });

      final controller = FaceEnrollmentController();
      final result = await controller.deleteBiometric(1, 'face');

      expect(result, isTrue);
    });

    test('deleteBiometric — فشل يعيد false', () async {
      when(() => mockData.delete(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = FaceEnrollmentController();
      final result = await controller.deleteBiometric(1, 'face');

      expect(result, isFalse);
    });
  });
}
