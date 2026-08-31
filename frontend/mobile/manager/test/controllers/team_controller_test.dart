import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/manager_data/manager_data.dart';
import 'package:medjat_central/data/data_source/remote/branch_data/branch_data.dart';
import 'package:medjat_central/logic/controller/team/team_controller.dart';
import '../helpers/test_helpers.dart';

class MockManagerData extends Mock implements ManagerData {}

class MockBranchData extends Mock implements BranchData {}

void main() {
  late MockManagerData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockManagerData();
    Get.put<ManagerData>(mockData);
    final mockBranch = MockBranchData();
    when(() => mockBranch.getBranches()).thenAnswer(
        (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
    Get.put<BranchData>(mockBranch);
  });

  tearDown(() => teardownGetX());

  group('TeamController', () {
    test('loadAll — نجاح', () async {
      when(() => mockData.getAdmins()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': [
              {'id': 1, 'name': 'أحمد', 'email': 'a@t.com', 'role': 'hr', 'is_active': 1},
            ],
          });
      when(() => mockData.getInvitations(status: any(named: 'status')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': [
                  {
                    'id': 1,
                    'name': 'خالد',
                    'email': 'k@t.com',
                    'role': 'viewer',
                    'expires_at': '2099-12-31T00:00:00Z',
                    'created_at': '2025-01-01T00:00:00Z',
                  },
                ],
              });

      final controller = TeamController();
      await controller.loadAll();

      expect(controller.status, StatusRequest.success);
      expect(controller.admins.length, 1);
      expect(controller.invitations.length, 1);
    });

    test('createInvitation — نجاح يعيد كود', () async {
      when(() => mockData.getAdmins()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockData.getInvitations(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockData.createInvitation(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'invitation_code': 'ABC123'},
          });

      final controller = TeamController();
      await controller.loadAll();

      final code = await controller.createInvitation(
        email: 'test@test.com',
        role: 'viewer',
      );

      expect(code, 'ABC123');
    });

    testWidgets('createInvitation — فشل يعيد null', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getAdmins()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockData.getInvitations(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockData.createInvitation(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = TeamController();
      await controller.loadAll();

      final code = await controller.createInvitation(
        email: 'test@test.com',
        role: 'viewer',
      );

      expect(code, isNull);
      await settleSnackbars(tester);
    });

    testWidgets('cancelInvitation — نجاح يعيد true', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getAdmins()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockData.getInvitations(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockData.cancelInvitation(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = TeamController();
      await controller.loadAll();

      final result = await controller.cancelInvitation(5);

      expect(result, isTrue);
      await settleSnackbars(tester);
    });

    test('togglePermission يضيف ويزيل صلاحية', () async {
      when(() => mockData.getAdmins()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockData.getInvitations(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});

      final controller = TeamController();
      await controller.loadAll();

      controller.selectedPermissions = ['view'];
      controller.togglePermission('edit');
      expect(controller.selectedPermissions, contains('edit'));

      controller.togglePermission('view');
      expect(controller.selectedPermissions, isNot(contains('view')));
    });
  });
}
