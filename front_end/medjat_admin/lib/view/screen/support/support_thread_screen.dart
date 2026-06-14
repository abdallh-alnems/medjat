import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/support_message_model.dart';
import '../../../logic/controller/support/support_controller.dart';

class SupportThreadScreen extends StatefulWidget {
  const SupportThreadScreen({super.key});

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen>
    with WidgetsBindingObserver {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replyController.dispose();
    _scrollController.dispose();
    Get.find<SupportController>().closeThread();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = Get.find<SupportController>();
    if (state == AppLifecycleState.paused) {
      controller.stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      final ticket = controller.currentTicket.value;
      if (ticket != null) {
        controller.openThread(ticket.id);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: GetBuilder<SupportController>(
          builder: (controller) {
            final ticket = controller.currentTicket.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket?.subject ?? 'تذكرة',
                  style: const TextStyle(fontSize: 16),
                ),
                if (ticket != null)
                  Text(
                    '${ticket.tenantName} · ${ticket.statusLabel}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            );
          },
        ),
        actions: [
          GetBuilder<SupportController>(
            builder: (controller) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  final ticket = controller.currentTicket.value;
                  if (ticket != null) {
                    controller.changeStatus(ticket.id, value);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'resolved', child: Text('تم الحل')),
                  const PopupMenuItem(value: 'closed', child: Text('إغلاق')),
                  const PopupMenuItem(value: 'reopen', child: Text('إعادة فتح')),
                ],
              );
            },
          ),
        ],
      ),
      body: GetBuilder<SupportController>(
        builder: (controller) {
          if (controller.threadStatus.value == StatusRequest.loading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          _scrollToBottom();

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.s4),
                  itemCount: controller.messages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
                  itemBuilder: (context, index) {
                    final msg = controller.messages[index];
                    return _MessageBubble(message: msg);
                  },
                ),
              ),
              _buildReplyInput(context, colors, controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReplyInput(
    BuildContext context,
    AppColorScheme colors,
    SupportController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                maxLength: 5000,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'اكتب ردك...',
                  hintStyle: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    color: colors.textTertiary,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: colors.canvas,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.borderHairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.borderHairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: colors.brand),
                  ),
                ),
                onChanged: (v) => controller.replyText.value = v,
              ),
            ),
            const SizedBox(width: AppSpacing.s2),
            Obx(() => IconButton.filled(
                  onPressed: controller.replyStatus.value == StatusRequest.loading
                      ? null
                      : () {
                          final ticket = controller.currentTicket.value;
                          if (ticket != null) {
                            controller.sendReply(ticket.id);
                            _replyController.clear();
                          }
                        },
                  icon: controller.replyStatus.value == StatusRequest.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                )),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;
    final isSupport = message.isFromSupport;

    return Align(
      alignment: isSupport ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: isSupport ? colors.brandSubtle : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: Radius.circular(isSupport ? 2 : AppRadius.md),
            bottomRight: Radius.circular(isSupport ? AppRadius.md : 2),
          ),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSupport ? 'فريق الدعم' : 'مستخدم',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSupport ? colors.brand : colors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.body,
              style: AppTextStyles.body(context),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: AppTextStyles.xs(context),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
