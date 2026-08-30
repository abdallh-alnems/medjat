import 'package:get/get.dart';

class DateFormatter {
  DateFormatter._();

  // مفاتيح الترجمة لأيام الأسبوع (1 = الإثنين … 7 = الأحد) والأشهر (1 … 12).
  // النصوص نفسها تأتي من ملفات الترجمة فتتبع لغة التطبيق تلقائياً.
  static const _weekdayKeys = [
    '', 'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];
  static const _monthKeys = [
    '', 'january', 'february', 'march', 'april', 'may', 'june',
    'july', 'august', 'september', 'october', 'november', 'december',
  ];

  static ({String dayName, String monthName}) format(DateTime date) {
    return (
      dayName: _weekdayKeys[date.weekday].tr,
      monthName: _monthKeys[date.month].tr,
    );
  }

  static String formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'pm'.tr : 'am'.tr;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
