import 'package:get/get.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../controller/attendance/attendance_controller.dart';
import '../controller/attendance/face_controller.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceData>(() => AttendanceData());
    Get.lazyPut<AttendanceController>(() => AttendanceController());
    Get.lazyPut<FaceController>(() => FaceController());
  }
}
