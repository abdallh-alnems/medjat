import 'package:get/get.dart';
import '../../../data/data_source/remote/home_data/home_data.dart';
import '../controller/home/home_controller.dart';
import '../../../core/shared/layout/tab_shell.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeData>(() => HomeData());
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<TabNavController>(() => TabNavController());
  }
}
