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
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.fingerprint_outlined),
                  activeIcon: const Icon(Icons.fingerprint),
                  label: 'tab_attendance'.tr,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline),
                  activeIcon: const Icon(Icons.person),
                  label: 'tab_profile'.tr,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.payments_outlined),
                  activeIcon: const Icon(Icons.payments),
                  label: 'tab_payroll'.tr,
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings_outlined),
                  activeIcon: const Icon(Icons.settings),
                  label: 'tab_account'.tr,
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
