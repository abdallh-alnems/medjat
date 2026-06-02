import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/data/data_source/remote/profile_data/profile_data.dart';
import 'package:medjat_app/logic/controller/profile/profile_controller.dart';

import '../../helpers/test_helpers.dart';

class MockProfileData extends Mock implements ProfileData {}

void main() {
  late MockProfileData mockProfileData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockProfileData = MockProfileData();
    Get.put<ProfileData>(mockProfileData);
    Get.put<CRUD>(MockCRUD());
  });

  tearDown(() {
    Get.reset();
  });

  group('ProfileController', () {
    test('loadProfile populates profileData, documents, warnings', () async {
      when(() => mockProfileData.getProfile()).thenAnswer((_) async =>
          <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{
              'employee': <String, dynamic>{
                'id': 1,
                'name': 'أحمد',
                'job_title': 'مهندس',
              },
              'documents': <Map<String, dynamic>>[
                {'id': 1, 'name': 'هوية'},
              ],
              'warnings': <Map<String, dynamic>>[
                {'id': 1, 'message': 'تحذير'},
              ],
              'leave_balance': <String, dynamic>{'annual': 10},
              'categories': <Map<String, dynamic>>[
                {'id': 1, 'name': 'تقني'},
              ],
            },
          });

      final controller = Get.put<ProfileController>(ProfileController());

      await untilCalled(() => mockProfileData.getProfile());

      expect(controller.status, StatusRequest.success);
      expect(controller.profileData, isNotNull);
      expect(controller.profileData!['name'], 'أحمد');
      expect(controller.documents.length, 1);
      expect(controller.warnings.length, 1);
      expect(controller.leaveBalance, isNotNull);
      expect(controller.leaveBalance!['annual'], 10);
      expect(controller.categories.length, 1);
    });

    test('loadProfile handles null data gracefully', () async {
      when(() => mockProfileData.getProfile()).thenAnswer((_) async =>
          <String, dynamic>{
            'status': StatusRequest.success,
            'data': null,
          });

      final controller = Get.put<ProfileController>(ProfileController());

      await untilCalled(() => mockProfileData.getProfile());

      expect(controller.status, StatusRequest.success);
      expect(controller.profileData, isNull);
      expect(controller.documents, isEmpty);
      expect(controller.warnings, isEmpty);
    });

    test('loadProfile sets offline', () async {
      when(() => mockProfileData.getProfile()).thenAnswer((_) async =>
          <String, dynamic>{'status': StatusRequest.offline});

      final controller = Get.put<ProfileController>(ProfileController());

      await untilCalled(() => mockProfileData.getProfile());

      expect(controller.status, StatusRequest.offline);
    });

    test('loadProfile sets failure on error', () async {
      when(() => mockProfileData.getProfile()).thenAnswer((_) async =>
          <String, dynamic>{'status': StatusRequest.failure});

      final controller = Get.put<ProfileController>(ProfileController());

      await untilCalled(() => mockProfileData.getProfile());

      expect(controller.status, StatusRequest.failure);
    });
  });
}
