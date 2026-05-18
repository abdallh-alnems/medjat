import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/model/attendance_model.dart';

class AttendanceController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();

  StatusRequest status = StatusRequest.none;
  List<AttendanceRecordModel> records = [];
  DateTime selectedDate = DateTime.now();
  int? branchFilter;

  @override
  void onInit() {
    super.onInit();
    loadAttendance();
  }

  Future<void> loadAttendance() async {
    status = StatusRequest.loading;
    update();

    final dateStr =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final response = await _attendanceData.getAttendance(
      date: dateStr,
      branchId: branchFilter,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        records = data
            .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void changeDate(DateTime date) {
    selectedDate = date;
    loadAttendance();
  }

  void filterByBranch(int? branchId) {
    branchFilter = branchId;
    loadAttendance();
  }

  Future<void> manualCheckIn({
    required int employeeId,
    required String type,
    required DateTime time,
    String? note,
  }) async {
    final response = await _attendanceData.manualCheckIn({
      'employee_id': employeeId,
      'type': type,
      'time': time.toIso8601String(),
      if (note != null) 'note': note,
    });

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم تسجيل الحضور بنجاح',
          snackPosition: SnackPosition.BOTTOM);
      loadAttendance();
    } else {
      Get.snackbar('خطأ', 'حدث خطأ في تسجيل الحضور',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
