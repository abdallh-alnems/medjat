import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/report_data/report_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late ReportData reportData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    reportData = ReportData();
  });

  tearDown(() => teardownGetX());

  group('ReportData', () {
    test('getAttendanceReport ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await reportData.getAttendanceReport(
        startDate: '2025-01-01',
        endDate: '2025-01-31',
      );

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getAttendanceReport مع branchId', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await reportData.getAttendanceReport(
        startDate: '2025-01-01',
        endDate: '2025-01-31',
        branchId: 5,
      );

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getPayrollReport ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await reportData.getPayrollReport(month: '2025-01');

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getEmployeesReport ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await reportData.getEmployeesReport();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getLeavesReport ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await reportData.getLeavesReport(
        startDate: '2025-01-01',
        endDate: '2025-12-31',
        status: 'approved',
      );

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getOvertimeLateReport يرسل الفترة والترتيب', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await reportData.getOvertimeLateReport(
        startDate: '2025-01-01',
        endDate: '2025-01-31',
        sort: 'late',
      );

      final captured = verify(() => mockCrud.getData(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['start_date'], '2025-01-01');
      expect(captured['end_date'], '2025-01-31');
      expect(captured['sort'], 'late');
      // No filters selected — neither key should be sent at all.
      expect(captured.containsKey('branch_id'), isFalse);
      expect(captured.containsKey('employee_id'), isFalse);
    });

    test('getOvertimeLateReport يمرر الفرع والموظف', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await reportData.getOvertimeLateReport(
        startDate: '2025-01-01',
        endDate: '2025-01-31',
        branchId: 3,
        employeeId: 7,
      );

      final captured = verify(() => mockCrud.getData(any(),
              queryParameters: captureAny(named: 'queryParameters')))
          .captured
          .single as Map<String, dynamic>;
      expect(captured['branch_id'], 3);
      expect(captured['employee_id'], 7);
      expect(captured['sort'], 'overtime');
    });
  });
}
