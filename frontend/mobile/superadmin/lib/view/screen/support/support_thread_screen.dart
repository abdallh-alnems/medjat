import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/id/app_links.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/services/token_storage_service.dart';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A staged screenshot, shown before it is sent so it can be removed.
            Obx(() {
              if (controller.pendingAttachmentName.value == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                child: Row(
                  children: [
                    Icon(Icons.image_outlined, size: 16, color: colors.brand),
                    const SizedBox(width: AppSpacing.s2),
                    Expanded(
                      child: Text(
                        controller.pendingAttachmentName.value!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: controller.clearAttachment,
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'إزالة المرفق',
                    ),
                  ],
                ),
              );
            }),
            Row(
              children: [
                IconButton(
                  onPressed: () => controller.pickAttachment(),
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'إرفاق صورة',
                ),
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
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: AppTextStyles.body(context),
              ),
            if (message.hasAttachment) ...[
              const SizedBox(height: AppSpacing.s2),
              _Attachment(message: message),
            ],
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

/// An attachment on a message.
///
/// Attachments are never served publicly — the file is fetched from
/// v1/admin/support/attachment with the admin bearer token, because a
/// client's screenshot can contain payroll figures or staff faces. Images
/// render inline; anything else (a PDF) gets a row that opens in the browser.
class _Attachment extends StatelessWidget {
  final SupportMessageModel message;

  const _Attachment({required this.message});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;
    final url = AppLinks.supportAttachment(message.id);

    return FutureBuilder<String?>(
      future: TokenStorageService.getToken(),
      builder: (context, snapshot) {
        final token = snapshot.data;
        if (token == null) {
          return const SizedBox.shrink();
        }
        final headers = {'Authorization': 'Bearer $token'};

        if (!message.attachmentIsImage) {
          return InkWell(
            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description_outlined, size: 18, color: colors.brand),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.attachmentName ?? 'مرفق',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.brand,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GestureDetector(
          onTap: () => _openFullScreen(context, url, headers),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.network(
              url,
              headers: headers,
              fit: BoxFit.cover,
              height: 160,
              errorBuilder: (context, error, stack) => Container(
                height: 60,
                alignment: Alignment.center,
                color: colors.sunken,
                child: Text(
                  'تعذّر تحميل المرفق',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullScreen(BuildContext context, String url, Map<String, String> headers) {
    Get.dialog<void>(
      Dialog(
        insetPadding: const EdgeInsets.all(AppSpacing.s3),
        child: InteractiveViewer(
          child: Image.network(url, headers: headers),
        ),
      ),
    );
  }
}
