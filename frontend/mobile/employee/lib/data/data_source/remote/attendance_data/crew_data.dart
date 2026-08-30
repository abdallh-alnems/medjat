import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

/// Crew attendance calls.
///
/// Kept out of AttendanceData because this is the one path where the employee
/// credential acts for other people. The backend keeps it in its own endpoint
/// for the same reason; mirroring that here means a reader of the ordinary
/// attendance code never has to notice it.
class CrewData {
  final CRUD _crud = Get.find<CRUD>();

  /// The supervisor's crew plus today's state for each person.
  Future<Map<String, dynamic>> list() async {
    return await _crud.postData(AppLinks.crewList, {});
  }

  /// Records arrival — or departure — for the selected people.
  ///
  /// One location is sent, taken from the supervisor's phone, and the server
  /// writes it onto every row. That is the honest shape of the evidence: it
  /// says the person recording was on site, not that each of thirty people was
  /// individually located.
  Future<Map<String, dynamic>> record({
    required List<int> employeeIds,
    required double latitude,
    required double longitude,
    required bool isCheckOut,
    bool isMockLocation = false,
    String? photoBase64,
  }) async {
    final data = <String, dynamic>{
      'employee_ids': employeeIds,
      'latitude': latitude,
      'longitude': longitude,
      'is_check_out': isCheckOut ? 1 : 0,
      'is_mock_location': isMockLocation ? 1 : 0,
    };
    if (photoBase64 != null) {
      data['photo_base64'] = photoBase64;
    }
    return await _crud.postData(AppLinks.crewCheckIn, data);
  }
}
