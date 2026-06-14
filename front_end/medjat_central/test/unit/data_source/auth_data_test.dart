import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/auth_data/auth_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late AuthData authData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    authData = AuthData();
  });

  tearDown(() => teardownGetX());

  group('AuthData', () {
    test('login ينادي postData مع endpoint الصحيح', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await authData.login('firebase_token_123');

      verify(() => mockCrud.postData(
            any(that: contains('login.php')),
            {'token': 'firebase_token_123'},
          )).called(1);
    });

    test('getProfile ينادي getData مع endpoint الصحيح', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await authData.getProfile();

      verify(() => mockCrud.getData(any(that: contains('login.php')))).called(1);
    });

    test('logout ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await authData.logout();

      verify(() => mockCrud.postData(any(that: contains('logout.php')), {})).called(1);
    });

    test('sendVerification ينادي postData مع endpoint الصحيح', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await authData.sendVerification('ar');

      verify(() => mockCrud.postData(
            any(that: contains('send_verification.php')),
            {'lang': 'ar'},
          )).called(1);
    });

    test('sendPasswordReset ينادي postData مع auth: false', () async {
      when(() => mockCrud.postData(any(), any(), auth: any(named: 'auth')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await authData.sendPasswordReset('test@example.com', 'ar');

      verify(() => mockCrud.postData(
            any(that: contains('send_password_reset.php')),
            {'email': 'test@example.com', 'lang': 'ar'},
            auth: false,
          )).called(1);
    });
  });
}
