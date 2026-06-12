import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../logic/controller/break/break_controller.dart';
import 'widgets/break_apply_form.dart';
import 'widgets/break_request_card.dart';

class BreakScreen extends StatelessWidget {
  const BreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => BreakController());
    return Scaffold(
      appBar: AppBar(title: Text('break_requests'.tr)),
      body: GetBuilder<BreakController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: controller.loadMyBreaks,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BreakApplyForm(controller: controller),
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

  Widget _myRequestsSection(BuildContext context, BreakController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('my_break_requests'.tr, style: AppTextStyles.h3(context)),
        const SizedBox(height: 12),
        if (controller.myBreaksStatus == StatusRequest.loading &&
            controller.myBreaks.isEmpty)
          Text('loading'.tr, style: AppTextStyles.bodySecondary(context))
        else if (controller.myBreaks.isEmpty)
          Text('no_break_requests'.tr,
              style: AppTextStyles.bodySecondary(context))
        else
          ...controller.myBreaks
              .map((b) => BreakRequestCard(controller: controller, item: b)),
      ],
    );
  }
}
