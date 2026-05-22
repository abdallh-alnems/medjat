import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/asset_data/asset_data.dart';
import 'package:medjat_central/data/model/asset_custody_model.dart';
import 'package:medjat_central/logic/controller/asset/asset_controller.dart';
import '../helpers/test_helpers.dart';

class MockAssetData extends Mock implements AssetData {}

void main() {
  late MockAssetData mockData;
  late AssetController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockAssetData();
    Get.put<AssetData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('AssetController', () {
    test('loadAssets — نجاح', () async {
      when(() => mockData.getAssets(status: any(named: 'status')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': [
                  {'id': 1, 'name': 'لابتوب', 'employee_id': 5, 'assigned_at': '2025-01-01'},
                ],
              });

      controller = AssetController();
      await controller.loadAssets();

      expect(controller.status, StatusRequest.success);
      expect(controller.assets.length, 1);
      expect(controller.assets.first.name, 'لابتوب');
    });

    test('loadAssets — فشل', () async {
      when(() => mockData.getAssets(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      controller = AssetController();
      await controller.loadAssets();

      expect(controller.status, StatusRequest.serverFailure);
      expect(controller.assets, isEmpty);
    });

    test('filterByStatus يحدث statusFilter ويُعيد التحميل', () async {
      when(() => mockData.getAssets(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      controller = AssetController();
      await controller.loadAssets();

      controller.filterByStatus('returned');

      expect(controller.statusFilter, 'returned');
      verify(() => mockData.getAssets(status: any(named: 'status'))).called(greaterThanOrEqualTo(2));
    });

    test('createAsset — نجاح يعيد true', () async {
      when(() => mockData.createAsset(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getAssets(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      controller = AssetController();
      await controller.loadAssets();

      final result = await controller.createAsset(
        employeeId: 1,
        type: 'equipment',
        name: 'شاشة',
        assignedAt: DateTime(2025, 1, 1),
      );

      expect(result, isTrue);
    });

    test('createAsset — فشل يعيد false', () async {
      when(() => mockData.createAsset(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      controller = AssetController();
      await controller.loadAssets();

      final result = await controller.createAsset(
        employeeId: 1,
        type: 'equipment',
        name: 'شاشة',
        assignedAt: DateTime(2025, 1, 1),
      );

      expect(result, isFalse);
    });

    test('approveReturn — نجاح يعيد تحميل البيانات', () async {
      when(() => mockData.approveReturn(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getAssets(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      controller = AssetController();
      await controller.loadAssets();

      await controller.approveReturn(5);

      verify(() => mockData.getAssets(status: any(named: 'status'))).called(greaterThanOrEqualTo(2));
    });

    test('rejectReturn — نجاح', () async {
      when(() => mockData.rejectReturn(any(), reason: any(named: 'reason')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getAssets(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      controller = AssetController();
      await controller.loadAssets();

      await controller.rejectReturn(5, reason: 'غير صالح');

      verify(() => mockData.getAssets(status: any(named: 'status'))).called(greaterThanOrEqualTo(2));
    });

    test('data كـ Map مع data.data.items', () async {
      when(() => mockData.getAssets(status: any(named: 'status')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'data': {
                    'items': [
                      {'id': 2, 'name': 'هاتف', 'employee_id': 3, 'assigned_at': '2025-02-01'},
                    ],
                  },
                },
              });

      controller = AssetController();
      await controller.loadAssets();

      expect(controller.assets.length, 1);
      expect(controller.assets.first.name, 'هاتف');
    });
  });
}
