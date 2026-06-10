import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Wraps a root screen so the system back button does not exit the app
/// immediately. The first back press shows a hint snackbar; pressing back
/// again within [interval] exits the app.
class TapToExit extends StatelessWidget {
  const TapToExit({super.key, required this.child, this.interval});

  final Widget child;
  final Duration? interval;

  static DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final window = interval ?? const Duration(seconds: 2);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > window) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('press_again_to_exit'.tr),
                duration: window,
                behavior: SnackBarBehavior.floating,
              ),
            );
        } else {
          await SystemNavigator.pop();
        }
      },
      child: child,
    );
  }
}
