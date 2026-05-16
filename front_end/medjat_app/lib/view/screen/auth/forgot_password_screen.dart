import 'package:flutter/material.dart';
import '../../../core/constant/theme/app_colors.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.light
        ? AppColors.light
        : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: const Text('نسيت كلمة السر')),
      body: const Center(child: Text('نسيت كلمة السر')),
    );
  }
}
