import 'package:get/get.dart';
import 'package:upgrader/upgrader.dart';

/// رسائل نافذة التحديث على iOS (حزمة upgrader). تتبع لغة التطبيق الحالية
/// عبر مفاتيح الترجمة، فتظهر بالكامل عربية أو إنجليزية حسب إعداد المستخدم.
class UpgradeMessages extends UpgraderMessages {
  @override
  String? message(UpgraderMessage messageKey) {
    switch (messageKey) {
      case UpgraderMessage.body:
        return 'upgrade_body'.tr;
      case UpgraderMessage.buttonTitleLater:
        return 'later'.tr;
      case UpgraderMessage.buttonTitleUpdate:
        return 'update_now'.tr;
      case UpgraderMessage.prompt:
        return 'optional_update_message'.tr;
      case UpgraderMessage.title:
        return 'update_available'.tr;
      default:
    }

    return super.message(messageKey);
  }
}
