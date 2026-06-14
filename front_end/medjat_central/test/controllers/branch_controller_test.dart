import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/branch_data/branch_data.dart';
import 'package:medjat_central/logic/controller/branch/branch_controller.dart';
import '../helpers/test_helpers.dart';

class MockBranchData extends Mock implements BranchData {}

void main() {
  late MockBranchData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockBranchData();
    Get.put<BranchData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('BranchController', () {
    test('loadBranches — نجاح مع قائمة مباشرة', () async {
      when(() => mockData.getBranches()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': [
              {'id': 1, 'name': 'الفرع الرئيسي'},
              {'id': 2, 'name': 'الفرع الشرقي'},
            ],
          });

      final controller = BranchController();
      await controller.loadBranches();

      expect(controller.status, StatusRequest.success);
      expect(controller.branches.length, 2);
      expect(controller.branches.first.name, 'الفرع الرئيسي');
    });

    test('loadBranches — نجاح مع Map branches', () async {
      when(() => mockData.getBranches()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'branches': [
                {'id': 3, 'name': 'الفرع الغربي'},
              ],
            },
          });

      final controller = BranchController();
      await controller.loadBranches();

      expect(controller.status, StatusRequest.success);
      expect(controller.branches.length, 1);
      expect(controller.branches.first.name, 'الفرع الغربي');
    });

    test('loadBranches — فشل', () async {
      when(() => mockData.getBranches())
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = BranchController();
      await controller.loadBranches();

      expect(controller.status, StatusRequest.serverFailure);
      expect(controller.branches, isEmpty);
    });
  });
}
