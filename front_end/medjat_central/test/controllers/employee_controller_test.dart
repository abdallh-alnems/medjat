import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/employee_data/employee_data.dart';
import 'package:medjat_central/data/data_source/remote/branch_data/branch_data.dart';
import 'package:medjat_central/data/data_source/remote/shift_data/shift_data.dart';
import 'package:medjat_central/data/data_source/remote/category_data/category_data.dart';
import 'package:medjat_central/logic/controller/employee/employee_controller.dart';
import '../helpers/test_helpers.dart';

class MockEmployeeData extends Mock implements EmployeeData {}

class MockBranchData extends Mock implements BranchData {}

class MockShiftData extends Mock implements ShiftData {}

class MockCategoryData extends Mock implements CategoryData {}

void main() {
  late MockEmployeeData mockData;
  late EmployeeController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockEmployeeData();
    Get.put<EmployeeData>(mockData);
    // The controller constructor resolves these filter-option data sources.
    Get.put<BranchData>(MockBranchData());
    Get.put<ShiftData>(MockShiftData());
    Get.put<CategoryData>(MockCategoryData());
  });

  tearDown(() => teardownGetX());

  group('EmployeeController — تحميل البيانات', () {
    test('نجاح الجلب يملأ القائمة ويضبط الحالة', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            shiftId: any(named: 'shiftId'),
            categoryId: any(named: 'categoryId'),
            search: any(named: 'search'),
            status: any(named: 'status'),
            sort: any(named: 'sort'),
            expiringWithin: any(named: 'expiringWithin'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{
                  'data': <String, dynamic>{
                    'items': [
                      {'id': 1, 'branch_id': 1, 'name': 'أحمد', 'status': 'active'},
                      {'id': 2, 'branch_id': 1, 'name': 'محمد', 'status': 'active'},
                    ],
                  },
                },
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      expect(controller.status, StatusRequest.success);
      expect(controller.employees.length, 2);
      expect(controller.employees.first.name, 'أحمد');
    });

    test('فشل الجلب يضبط الحالة ولا يملأ القائمة', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            shiftId: any(named: 'shiftId'),
            categoryId: any(named: 'categoryId'),
            search: any(named: 'search'),
            status: any(named: 'status'),
            sort: any(named: 'sort'),
            expiringWithin: any(named: 'expiringWithin'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.failure,
                'message': 'خطأ',
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      expect(controller.status, StatusRequest.failure);
      expect(controller.employees, isEmpty);
    });

    test('حالة offline', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            shiftId: any(named: 'shiftId'),
            categoryId: any(named: 'categoryId'),
            search: any(named: 'search'),
            status: any(named: 'status'),
            sort: any(named: 'sort'),
            expiringWithin: any(named: 'expiringWithin'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.offline,
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      expect(controller.status, StatusRequest.offline);
      expect(controller.employees, isEmpty);
    });

    test('data كـ List مباشر', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            shiftId: any(named: 'shiftId'),
            categoryId: any(named: 'categoryId'),
            search: any(named: 'search'),
            status: any(named: 'status'),
            sort: any(named: 'sort'),
            expiringWithin: any(named: 'expiringWithin'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': [
                  {'id': 1, 'branch_id': 1, 'name': 'أحمد'},
                ],
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      expect(controller.employees.length, 1);
    });

    test('data فارغة null', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            shiftId: any(named: 'shiftId'),
            categoryId: any(named: 'categoryId'),
            search: any(named: 'search'),
            status: any(named: 'status'),
            sort: any(named: 'sort'),
            expiringWithin: any(named: 'expiringWithin'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': null,
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      expect(controller.status, StatusRequest.success);
      expect(controller.employees, isEmpty);
    });

    test('onSearch يضبط searchQuery', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            shiftId: any(named: 'shiftId'),
            categoryId: any(named: 'categoryId'),
            search: any(named: 'search'),
            status: any(named: 'status'),
            sort: any(named: 'sort'),
            expiringWithin: any(named: 'expiringWithin'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      controller.onSearch('أحمد');

      expect(controller.searchQuery, 'أحمد');
    });

    test('applyFilters يضبط branchFilter', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            shiftId: any(named: 'shiftId'),
            categoryId: any(named: 'categoryId'),
            search: any(named: 'search'),
            status: any(named: 'status'),
            sort: any(named: 'sort'),
            expiringWithin: any(named: 'expiringWithin'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      controller.applyFilters(branchId: 5);

      expect(controller.branchFilter, 5);
    });
  });
}
