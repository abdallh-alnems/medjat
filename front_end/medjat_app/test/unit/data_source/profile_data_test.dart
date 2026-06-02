import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/core/constant/id/app_links.dart';
import 'package:medjat_app/data/data_source/remote/profile_data/profile_data.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockCRUD mockCrud;
  late ProfileData profileData;

  setUp(() {
    setupGetTestBindings();
    setupDotenvForTest();
    registerFallbacks();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    profileData = ProfileData();
  });

  tearDown(() {
    Get.reset();
  });

  group('ProfileData', () {
    test('getProfile fetches profile data', () async {
      when(() => mockCrud.getData(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'employee': {'id': 1, 'name': 'أحمد'},
            },
          });

      final result = await profileData.getProfile();

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(AppLinks.myProfile)).called(1);
    });
  });
}
