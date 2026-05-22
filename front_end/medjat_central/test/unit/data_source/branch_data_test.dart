import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/branch_data/branch_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late BranchData branchData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    branchData = BranchData();
  });

  tearDown(() => teardownGetX());

  group('BranchData', () {
    test('getBranches ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await branchData.getBranches();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('getBranch ينادي getData مع id', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await branchData.getBranch(5);

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('createBranch ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await branchData.createBranch({'name': 'فرع جديد'});

      verify(() => mockCrud.postData(any(), {'name': 'فرع جديد'})).called(1);
    });

    test('updateBranch ينادي putData مع branch_id', () async {
      when(() => mockCrud.putData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await branchData.updateBranch(3, {'name': 'محدث'});

      verify(() => mockCrud.putData(any(), any())).called(1);
    });

    test('updateBranchAttendanceMethods ينادي putData', () async {
      when(() => mockCrud.putData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await branchData.updateBranchAttendanceMethods(
        branchId: 1,
        methods: ['gps', 'qr'],
        gpsRadiusMeters: 200,
      );

      verify(() => mockCrud.putData(any(), any())).called(1);
    });
  });
}
