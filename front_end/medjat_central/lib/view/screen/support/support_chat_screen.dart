import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/support_model.dart';
import '../../../logic/controller/support/support_controller.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with WidgetsBindingObserver {
  final _replyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final args = Get.arguments as Map<String, dynamic>?;
    final ticketId = args?['ticket_id'] as int? ?? 0;
    if (ticketId > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.find<SupportController>().openTicket(ticketId);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _replyCtrl.dispose();
    _scrollCtrl.dispose();
    Get.find<SupportController>().stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = Get.find<SupportController>();
    if (state == AppLifecycleState.paused) {
      ctrl.stopPolling();
    } else if (state == AppLifecycleState.resumed) {
      final ticket = ctrl.currentTicket.value;
      if (ticket != null) {
        ctrl.openTicket(ticket.id);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SupportController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final ticket = controller.currentTicket.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket?.subject ?? 'support_chat'.tr,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (ticket != null)
                Text(
                  ticket.statusLabel.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          );
        }),
        actions: [
          Obx(() {
            final ticket = controller.currentTicket.value;
            if (ticket == null) return const SizedBox.shrink();
            if (ticket.isOpen) {
              return IconButton(
                icon: Icon(Icons.close_outlined, color: colors.textSecondary),
                tooltip: 'close_ticket'.tr,
                onPressed: () => _confirmClose(controller, ticket.id),
              );
            }
            return IconButton(
              icon: Icon(Icons.refresh_outlined, color: colors.textSecondary),
              tooltip: 'reopen_ticket'.tr,
              onPressed: () async {
                await controller.reopenTicket(ticket.id);
                unawaited(controller.openTicket(ticket.id));
              },
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.messages.isEmpty) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (controller.messages.isNotEmpty) _scrollToBottom();
        });

        return Column(
          children: [
            Expanded(
              child: controller.messages.isEmpty
                  ? Center(
                      child: Text(
                        'no_messages_yet'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 14,
                          color: colors.textTertiary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      itemCount: controller.messages.length,
                      itemBuilder: (context, index) {
                        final msg = controller.messages[index];
                        return _ChatBubble(
                          message: msg,
                          colors: colors,
                        );
                      },
                    ),
            ),
            _buildInputBar(controller, colors),
          ],
        );
      }),
    );
  }

  Widget _buildInputBar(SupportController controller, AppColorScheme colors) {
    final ticket = controller.currentTicket.value;
    final isClosed = ticket?.isClosed ?? false;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s2,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A staged attachment, shown before sending so it can be removed.
          Obx(() {
            final name = controller.pendingAttachmentName.value;
            if (name == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: Row(
                children: [
                  Icon(Icons.attach_file, size: 16, color: colors.brand),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      name,
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
                  ),
                ],
              ),
            );
          }),
          Row(
        children: [
          IconButton(
            onPressed: isClosed ? null : controller.pickAttachment,
            icon: Icon(Icons.attach_file, color: colors.textSecondary),
            tooltip: 'إرفاق ملف',
          ),
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              enabled: !isClosed,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(controller),
              decoration: InputDecoration(
                hintText: isClosed
                    ? 'ticket_closed_hint'.tr
                    : 'type_message'.tr,
                hintStyle: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: colors.textTertiary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: colors.borderHairline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: colors.borderHairline),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s3,
                  vertical: AppSpacing.s2,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Obx(() => IconButton(
                onPressed: controller.isSending.value ? null : () => _send(controller),
                icon: controller.isSending.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                      )
                    : Icon(Icons.send_rounded, color: colors.brand),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _send(SupportController controller) async {
    final text = _replyCtrl.text.trim();
    // An attachment on its own is a complete report.
    if (text.isEmpty && controller.pendingAttachment.value == null) return;
    _replyCtrl.clear();
    await controller.sendReply(text);
    _scrollToBottom();
  }

  void _confirmClose(SupportController controller, int ticketId) {
    final colors = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('close_ticket'.tr),
        content: Text('close_ticket_confirm'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.closeTicket(ticketId);
            },
            style: TextButton.styleFrom(foregroundColor: colors.error),
            child: Text('close'.tr),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final SupportMessageModel message;
  final AppColorScheme colors;

  const _ChatBubble({required this.message, required this.colors});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    final isSystem = message.isSystem;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3, vertical: AppSpacing.s1),
          decoration: BoxDecoration(
            color: colors.sunken,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            message.body,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              color: colors.textTertiary,
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          color: isUser ? colors.brandSubtle : colors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadius.md),
            topRight: const Radius.circular(AppRadius.md),
            bottomLeft: isUser
                ? const Radius.circular(2)
                : const Radius.circular(AppRadius.md),
            bottomRight: isUser
                ? const Radius.circular(AppRadius.md)
                : const Radius.circular(2),
          ),
          border: Border.all(
            color: isUser
                ? colors.brand.withValues(alpha: 0.15)
                : colors.borderHairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  color: colors.textPrimary,
                  height: 1.4,
                ),
              ),
            if ((message.attachmentUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s2),
              _AttachmentView(message: message, colors: colors),
            ],
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 10,
                color: colors.textTertiary,
              ),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}


/// One attachment on a message.
///
/// Attachments are not public files — the bytes are fetched through
/// app/support/attachment.php with the session's own credentials, because a
/// screenshot in a ticket can contain payroll figures or staff faces.
class _AttachmentView extends StatelessWidget {
  final SupportMessageModel message;
  final AppColorScheme colors;

  const _AttachmentView({required this.message, required this.colors});

  bool get _isImage {
    final path = (message.attachmentUrl ?? '').toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SupportController>();

    if (!_isImage) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, size: 16, color: colors.brand),
          const SizedBox(width: 4),
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
      );
    }

    return FutureBuilder<Uint8List?>(
      future: controller.attachmentBytes(message.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 80,
            width: 120,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return Text(
            'تعذّر تحميل المرفق',
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              color: colors.textTertiary,
            ),
          );
        }
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(AppSpacing.s3),
              child: InteractiveViewer(child: Image.memory(bytes)),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.memory(bytes, height: 160, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
