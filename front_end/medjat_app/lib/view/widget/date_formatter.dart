import '../../core/services/locale_service.dart';
import 'package:get/get.dart';

class DateFormatter {
  DateFormatter._();

  static ({String dayName, String monthName}) format(DateTime date) {
    final localeSvc = Get.find<LocaleService>();
    final isAr = localeSvc.isArabic;

    String dayName;
    String monthName;

    if (isAr) {
      final weekdays = [
        '', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
        'الجمعة', 'السبت', 'الأحد'
      ];
      final months = [
        '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو',
        'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر',
        'نوفمبر', 'ديسمبر'
      ];
      dayName = weekdays[date.weekday];
      monthName = months[date.month];
    } else {
      final weekdays = [
        '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday'
      ];
      final months = [
        '', 'January', 'February', 'March', 'April', 'May',
        'June', 'July', 'August', 'September', 'October',
        'November', 'December'
      ];
      dayName = weekdays[date.weekday];
      monthName = months[date.month];
    }

    return (dayName: dayName, monthName: monthName);
  }

  static String formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm'.tr : 'am'.tr;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
