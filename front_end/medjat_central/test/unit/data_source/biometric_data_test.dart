import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/biometric_data/biometric_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late BiometricData biometricData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    biometricData = BiometricData();
  });

  tearDown(() => teardownGetX());

  group('BiometricData', () {
    test('enrollFace ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await biometricData.enrollFace({'employee_id': 1, 'image': 'base64'});

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('enrollFingerprint ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await biometricData.enrollFingerprint({'employee_id': 1, 'template': 'abc'});

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('delete ينادي postData مع type و employeeId', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await biometricData.delete('face', 5);

      verify(() => mockCrud.postData(any(), {'employee_id': 5, 'type': 'face'})).called(1);
    });

    test('getStatus ينادي getData مع employeeId', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await biometricData.getStatus(10);

      verify(() => mockCrud.getData(any())).called(1);
    });
  });
}
