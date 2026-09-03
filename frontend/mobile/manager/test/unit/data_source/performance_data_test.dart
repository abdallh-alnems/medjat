import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/performance_data/performance_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late PerformanceData data;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = PerformanceData();
  });

  tearDown(() => teardownGetX());

  group('PerformanceData', () {
    test('getReviews ينادي getData مع employeeId', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getReviews(5);

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('createReview ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.createReview({'employee_id': 5, 'rating': 4});

      verify(() => mockCrud.postData(any(), {'employee_id': 5, 'rating': 4})).called(1);
    });

    test('deleteReview ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.deleteReview(10);

      verify(() => mockCrud.postData(any(), {'id': 10})).called(1);
    });
  });
}
