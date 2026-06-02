import 'package:get/get.dart';
import '../../../data/data_source/remote/station_data/station_data.dart';
import '../../../logic/controller/station/station_controller.dart';

class StationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StationData>(() => StationData());
    Get.lazyPut<StationController>(() => StationController());
  }
}
