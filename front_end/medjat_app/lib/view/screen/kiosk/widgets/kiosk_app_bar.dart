import 'package:flutter/material.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import 'package:get/get.dart';

class KioskAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const KioskAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black54,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.h3(context).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
