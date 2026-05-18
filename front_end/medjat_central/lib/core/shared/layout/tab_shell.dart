import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/theme/app_colors.dart';

class TabShell extends StatelessWidget {
  final List<Widget> screens;

  const TabShell({super.key, required this.screens});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<TabNavController>();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Obx(() => Scaffold(
          body: IndexedStack(
            index: controller.currentIndex.value,
            children: screens,
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
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'الرئيسية',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.groups_outlined),
                  activeIcon: Icon(Icons.groups),
                  label: 'الموظفين',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_time_outlined),
                  activeIcon: Icon(Icons.access_time),
                  label: 'الحضور',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.payments_outlined),
                  activeIcon: Icon(Icons.payments),
                  label: 'الرواتب',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_outlined),
                  activeIcon: Icon(Icons.menu),
                  label: 'المزيد',
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
