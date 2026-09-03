import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/category_data/category_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late CategoryData categoryData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    categoryData = CategoryData();
  });

  tearDown(() => teardownGetX());

  group('CategoryData', () {
    test('getCategories ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await categoryData.getCategories();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('createCategory ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await categoryData.createCategory({'name': 'تقنية'});

      verify(() => mockCrud.postData(any(), {'name': 'تقنية'})).called(1);
    });

    test('updateCategory ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await categoryData.updateCategory({'id': 1, 'name': 'محدث'});

      verify(() => mockCrud.postData(any(), {'id': 1, 'name': 'محدث'})).called(1);
    });

    test('deleteCategory ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await categoryData.deleteCategory(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });

    test('assignCategories ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await categoryData.assignCategories(employeeId: 10, categoryIds: [1, 2]);

      verify(() => mockCrud.postData(any(), {
        'employee_id': 10,
        'category_ids': [1, 2],
      })).called(1);
    });
  });
}
