import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/theme/app_colors.dart';
import '../../services/push_notification_service.dart';
import 'tap_to_exit.dart';

class TabShell extends StatefulWidget {
  final List<Widget> screens;

  const TabShell({super.key, required this.screens});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  @override
  void initState() {
    super.initState();
    // Request notification permission only once the user reaches the home page
    // (i.e. after login and creating/joining a company).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TabNavController>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Obx(() => Scaffold(
          body: TapToExit(
            child: IndexedStack(
              index: controller.currentIndex.value,
              children: widget.screens,
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: colors.borderHairline,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: controller.currentIndex.value,
              onTap: controller.changeTab,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  activeIcon: const Icon(Icons.dashboard),
                  label: 'home'.tr,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.groups_outlined),
                  activeIcon: const Icon(Icons.groups),
                  label: 'employees'.tr,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.access_time_outlined),
                  activeIcon: const Icon(Icons.access_time),
                  label: 'attendance'.tr,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.payments_outlined),
                  activeIcon: const Icon(Icons.payments),
                  label: 'payroll'.tr,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.menu_outlined),
                  activeIcon: const Icon(Icons.menu),
                  label: 'more'.tr,
                ),
              ],
            ),
          ),
        ));
  }
}

class TabNavController extends GetxController {
  final currentIndex = 0.obs;
  void changeTab(int index) => currentIndex.value = index;
}

class TabBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TabNavController>(() => TabNavController());
  }
}
