import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class TenantData {
  final CRUD _crud = Get.find<CRUD>();

  /// Locale settings are sent at creation so the company never runs on a
  /// guessed default. The backend treats them as optional and falls back to the
  /// column defaults, which is what older builds still in the stores rely on.
  Future<Map<String, dynamic>> createCompany({
    required String firebaseToken,
    required String companyName,
    String? timezone,
    String? currency,
    int? cycleStartDay,
    int? weekStartDay,
  }) async {
    return await _crud.postData(AppLinks.tenantCreate, {
      'token': firebaseToken,
      'company_name': companyName,
      'timezone': ?timezone,
      'currency': ?currency,
      'cycle_start_day': ?cycleStartDay,
      'week_start_day': ?weekStartDay,
    });
  }

  Future<Map<String, dynamic>> joinCompany({
    required String firebaseToken,
    required String inviteCode,
  }) async {
    return await _crud.postData(AppLinks.tenantJoin, {
      'token': firebaseToken,
      'invite_code': inviteCode,
    });
  }

  /// Accept a pending invitation addressed to the signed-in user's email —
  /// no code required (powers the one-tap "Join {company}" on onboarding).
  Future<Map<String, dynamic>> acceptInvitation({
    required String firebaseToken,
    int? invitationId,
  }) async {
    return await _crud.postData(AppLinks.tenantAcceptInvitation, {
      'token': firebaseToken,
      'invitation_id': ?invitationId,
    });
  }
}
