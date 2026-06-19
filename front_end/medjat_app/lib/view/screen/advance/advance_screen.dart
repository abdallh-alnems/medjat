import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../logic/controller/advance/advance_controller.dart';
import '../../widget/ad/top_native_ad.dart';
import 'widgets/advance_apply_form.dart';
import 'widgets/advance_request_card.dart';

class AdvanceScreen extends StatelessWidget {
  const AdvanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => AdvanceController());
    return Scaffold(
      appBar: AppBar(title: Text('advances'.tr)),
      body: GetBuilder<AdvanceController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: controller.loadMyAdvances,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TopNativeAd(horizontalMargin: 0),
                  AdvanceApplyForm(controller: controller),
                  const SizedBox(height: 28),
                  _myRequestsSection(context, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _myRequestsSection(
      BuildContext context, AdvanceController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('my_advance_requests'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: 12),
        if (controller.myAdvancesStatus == StatusRequest.loading &&
            controller.myAdvances.isEmpty)
          Text('loading'.tr, style: AppTextStyles.bodySecondary(context))
        else if (controller.myAdvances.isEmpty)
          Text('no_advance_requests'.tr,
              style: AppTextStyles.bodySecondary(context))
        else
          ...controller.myAdvances.map(
              (a) => AdvanceRequestCard(controller: controller, item: a)),
      ],
    );
  }
}
