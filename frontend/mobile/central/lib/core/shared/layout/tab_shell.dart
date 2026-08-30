import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/theme/app_colors.dart';
import '../../services/push_notification_service.dart';
import 'tap_to_exit.dart';

/// One entry in the home bottom navigation: its screen plus the nav-bar icon
/// and label. The visible set is decided per-user (by permission) before the
/// shell is built, so a viewer never lands on a tab the backend would reject.
class TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String labelKey;
  final Widget screen;

  const TabItem({
    required this.icon,
    required this.activeIcon,
    required this.labelKey,
    required this.screen,
  });
}

class TabShell extends StatefulWidget {
  final List<TabItem> tabs;

  const TabShell({super.key, required this.tabs});

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
    final tabs = widget.tabs;

    return Obx(() {
      // Guard against a stale index after the visible tab set shrinks
      // (e.g. permissions changed between sessions).
      final index = controller.currentIndex.value.clamp(0, tabs.length - 1);
      return Scaffold(
        body: TapToExit(
          child: IndexedStack(
            index: index,
            children: tabs.map((t) => t.screen).toList(),
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
            type: BottomNavigationBarType.fixed,
            currentIndex: index,
            onTap: controller.changeTab,
            items: [
              for (final t in tabs)
                BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.labelKey.tr,
                ),
            ],
          ),
        ),
      );
    });
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
