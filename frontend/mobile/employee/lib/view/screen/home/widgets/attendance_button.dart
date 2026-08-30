import 'package:flutter/material.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/constant/theme/app_text_styles.dart';

class AttendanceButton extends StatelessWidget {
  final AppColorScheme colors;
  final bool isDayDone;
  final bool canCheckOut;
  final String buttonText;
  final IconData icon;
  final VoidCallback onTap;

  const AttendanceButton({
    super.key,
    required this.colors,
    required this.isDayDone,
    required this.canCheckOut,
    required this.buttonText,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (isDayDone) {
      bgColor = colors.sunken;
    } else if (canCheckOut) {
      bgColor = colors.accentWarm;
    } else {
      bgColor = colors.brand;
    }

    return Center(
      child: GestureDetector(
        onTap: isDayDone ? null : onTap,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            boxShadow: isDayDone
                ? null
                : [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: isDayDone ? colors.textTertiary : Colors.white,
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                buttonText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.arabicFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDayDone ? colors.textTertiary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
