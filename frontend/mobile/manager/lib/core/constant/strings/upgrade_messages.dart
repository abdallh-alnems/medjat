import 'package:get/get.dart';
import 'package:upgrader/upgrader.dart';

class UpgradeMessages extends UpgraderMessages {
  @override
  String? message(UpgraderMessage messageKey) {
    switch (messageKey) {
      case UpgraderMessage.body:
        return 'upgrade_body'.tr;
      case UpgraderMessage.buttonTitleLater:
        return 'later'.tr;
      case UpgraderMessage.buttonTitleUpdate:
        return 'update_now_btn'.tr;
      case UpgraderMessage.prompt:
        return 'upgrade_prompt'.tr;
      case UpgraderMessage.title:
        return 'upgrade_title'.tr;
      default:
    }

    return super.message(messageKey);
  }
}
