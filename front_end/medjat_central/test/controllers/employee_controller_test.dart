import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/employee_data/employee_data.dart';
import 'package:medjat_central/logic/controller/employee/employee_controller.dart';
import '../helpers/test_helpers.dart';

class MockEmployeeData extends Mock implements EmployeeData {}

void main() {
  late MockEmployeeData mockData;
  late EmployeeController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockEmployeeData();
    Get.put<EmployeeData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('EmployeeController — تحميل البيانات', () {
    test('نجاح الجلب يملأ القائمة ويضبط الحالة', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            search: any(named: 'search'),
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
            search: any(named: 'search'),
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
            search: any(named: 'search'),
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
            search: any(named: 'search'),
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
            search: any(named: 'search'),
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
            search: any(named: 'search'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      controller.onSearch('أحمد');

      expect(controller.searchQuery, 'أحمد');
    });

    test('filterByBranch يضبط branchFilter', () async {
      when(() => mockData.getEmployees(
            branchId: any(named: 'branchId'),
            search: any(named: 'search'),
          )).thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });

      controller = EmployeeController();
      await controller.loadEmployees();

      controller.filterByBranch(5);

      expect(controller.branchFilter, 5);
    });
  });
}
