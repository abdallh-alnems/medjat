import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/support_data/support_data.dart';
import '../../../data/model/support_ticket_model.dart';
import '../../../data/model/support_message_model.dart';

class SupportController extends GetxController {
  final SupportData _supportData = Get.find<SupportData>();

  final status = StatusRequest.none.obs;
  final tickets = <SupportTicketModel>[].obs;
  final filteredTickets = <SupportTicketModel>[].obs;
  final currentTicket = Rxn<SupportTicketModel>();
  final messages = <SupportMessageModel>[].obs;
  final totalTickets = 0.obs;
  final currentPage = 1.obs;

  final statusFilter = RxnString();
  final tenantFilter = RxnInt();

  final threadStatus = StatusRequest.none.obs;
  final replyStatus = StatusRequest.none.obs;
  final replyText = ''.obs;
  int _lastMessageId = 0;
  Timer? _pollTimer;

  @override
  void onInit() {
    super.onInit();
    loadInbox();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> loadInbox({int page = 1}) async {
    if (page == 1) {
      status.value = StatusRequest.loading;
    }
    update();

    final response = await _supportData.list(
      page: page,
      status: statusFilter.value,
      tenantId: tenantFilter.value,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      final list = (data?['tickets'] as List? ?? [])
          .map((t) => SupportTicketModel.fromJson(t as Map<String, dynamic>))
          .toList();
      if (page == 1) {
        tickets.value = list;
      } else {
        tickets.addAll(list);
      }
      totalTickets.value = data?['total'] as int? ?? 0;
      currentPage.value = page;
      _applyFilters();
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  void _applyFilters() {
    var result = tickets.toList();
    if (statusFilter.value != null) {
      result = result.where((t) => t.status == statusFilter.value).toList();
    }
    if (tenantFilter.value != null) {
      result = result.where((t) => t.tenantId == tenantFilter.value).toList();
    }
    filteredTickets.value = result;
  }

  void setStatusFilter(String? s) {
    statusFilter.value = s;
    loadInbox();
  }

  void setTenantFilter(int? id) {
    tenantFilter.value = id;
    loadInbox();
  }

  Future<void> openThread(int ticketId) async {
    threadStatus.value = StatusRequest.loading;
    messages.clear();
    _lastMessageId = 0;
    update();

    final response = await _supportData.messages(ticketId);

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data?['ticket'] != null) {
        currentTicket.value = SupportTicketModel.fromJson(
          data['ticket'] as Map<String, dynamic>,
        );
      }
      final msgList = (data?['messages'] as List? ?? [])
          .map((m) => SupportMessageModel.fromJson(m as Map<String, dynamic>))
          .toList();
      messages.value = msgList;
      if (msgList.isNotEmpty) {
        _lastMessageId = msgList.last.id;
      }
      threadStatus.value = StatusRequest.success;
      _startPolling(ticketId);
    } else {
      threadStatus.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  void _startPolling(int ticketId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollNewMessages(ticketId);
    });
  }

  Future<void> _pollNewMessages(int ticketId) async {
    if (_lastMessageId == 0) return;
    final response = await _supportData.messages(ticketId, afterId: _lastMessageId);
    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      final newMsgs = (data?['messages'] as List? ?? [])
          .map((m) => SupportMessageModel.fromJson(m as Map<String, dynamic>))
          .toList();
      if (newMsgs.isNotEmpty) {
        messages.addAll(newMsgs);
        _lastMessageId = newMsgs.last.id;
        final lastMsg = newMsgs.last;
        if (currentTicket.value != null && lastMsg.senderType == 'user') {
          currentTicket.value = currentTicket.value!.copyWith(
            lastMessagePreview: lastMsg.body.length > 255
                ? lastMsg.body.substring(0, 255)
                : lastMsg.body,
          );
        }
        update();
      }
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void closeThread() {
    stopPolling();
    currentTicket.value = null;
    messages.clear();
    _lastMessageId = 0;
  }

  /// A screenshot staged for the next reply, base64-encoded and ready to send.
  final pendingAttachment = Rxn<String>();
  final pendingAttachmentName = RxnString();

  /// Attach a screenshot. The image is downscaled and re-compressed by the
  /// picker before encoding — the backend caps attachments at 5 MB, and a
  /// full-resolution phone photo of a screen is well past that for no gain.
  Future<void> pickAttachment({bool fromCamera = false}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await File(picked.path).readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        Get.snackbar('كبير جدًا', 'الحد الأقصى للمرفق 5 ميجابايت',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      pendingAttachment.value = base64Encode(bytes);
      pendingAttachmentName.value = picked.name;
      update();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذّر اختيار الصورة', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void clearAttachment() {
    pendingAttachment.value = null;
    pendingAttachmentName.value = null;
    update();
  }

  Future<void> sendReply(int ticketId) async {
    final text = replyText.value.trim();
    final attachment = pendingAttachment.value;
    // An attachment on its own is a complete reply; text alone is too.
    if ((text.isEmpty && attachment == null) || text.length > 5000) return;

    replyStatus.value = StatusRequest.loading;
    update();

    final response = await _supportData.reply(
      ticketId,
      text,
      attachmentBase64: attachment,
      attachmentName: pendingAttachmentName.value,
    );

    if (response['status'] == StatusRequest.success) {
      replyText.value = '';
      clearAttachment();
      replyStatus.value = StatusRequest.success;
      await openThread(ticketId);
    } else {
      replyStatus.value = StatusRequest.failure;
      final message = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> changeStatus(int ticketId, String newStatus) async {
    final response = await _supportData.setStatus(ticketId, newStatus);

    if (response['status'] == StatusRequest.success) {
      if (currentTicket.value != null && currentTicket.value!.id == ticketId) {
        await openThread(ticketId);
      }
      unawaited(loadInbox());
      Get.snackbar('تم', 'تم تحديث حالة التذكرة', snackPosition: SnackPosition.BOTTOM);
    } else {
      final message = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
