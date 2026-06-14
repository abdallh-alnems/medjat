import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/category_data/category_data.dart';
import 'package:medjat_central/logic/controller/category/category_controller.dart';
import '../helpers/test_helpers.dart';

class MockCategoryData extends Mock implements CategoryData {}

void main() {
  late MockCategoryData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockCategoryData();
    Get.put<CategoryData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('CategoryController', () {
    test('loadCategories — نجاح', () async {
      when(() => mockData.getCategories()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'categories': [
                {'id': 1, 'name': 'تقنية'},
              ],
            },
          });

      final controller = CategoryController();
      await controller.loadCategories();

      expect(controller.status, StatusRequest.success);
      expect(controller.categories.length, 1);
      expect(controller.categories.first.name, 'تقنية');
    });

    test('loadCategories — نجاح مع قائمة مباشرة', () async {
      when(() => mockData.getCategories()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': [
              {'id': 2, 'name': 'إداري'},
            ],
          });

      final controller = CategoryController();
      await controller.loadCategories();

      expect(controller.categories.length, 1);
    });

    test('loadCategories — فشل', () async {
      when(() => mockData.getCategories())
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = CategoryController();
      await controller.loadCategories();

      expect(controller.status, StatusRequest.failure);
    });

    testWidgets('deleteCategory — نجاح يحذف من القائمة', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getCategories()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': [
              {'id': 1, 'name': 'تقنية'},
              {'id': 2, 'name': 'إداري'},
            ],
          });
      when(() => mockData.deleteCategory(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = CategoryController();
      await controller.loadCategories();
      expect(controller.categories.length, 2);

      final result = await controller.deleteCategory(1);

      expect(result, isTrue);
      expect(controller.categories.length, 1);
      await settleSnackbars(tester);
    });

    testWidgets('deleteCategory — فشل يعيد false', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getCategories()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': [
              {'id': 1, 'name': 'تقنية'},
            ],
          });
      when(() => mockData.deleteCategory(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = CategoryController();
      await controller.loadCategories();

      final result = await controller.deleteCategory(1);

      expect(result, isFalse);
      expect(controller.categories.length, 1);
      await settleSnackbars(tester);
    });
  });
}
