import 'package:get/get.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/attendance_data/crew_data.dart';
import '../controller/attendance/attendance_controller.dart';
import '../controller/attendance/crew_controller.dart';
import '../controller/attendance/face_controller.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceData>(() => AttendanceData());
    Get.lazyPut<CrewData>(() => CrewData());
    Get.lazyPut<AttendanceController>(() => AttendanceController());
    Get.lazyPut<FaceController>(() => FaceController());
    // lazyPut, so a supervisor's crew is only fetched when they open the
    // screen — most employees are not supervisors and should never pay for it.
    Get.lazyPut<CrewController>(() => CrewController());
  }
}
