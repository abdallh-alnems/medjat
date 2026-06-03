import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/support_data/support_data.dart';
import '../../../data/model/support_model.dart';

class SupportController extends GetxController {
  final SupportData _data = SupportData();

  final tickets = <SupportTicketModel>[].obs;
  final messages = <SupportMessageModel>[].obs;
  final currentTicket = Rxn<SupportTicketModel>();
  final isLoading = false.obs;
  final isSending = false.obs;
  final unreadTotal = 0.obs;
  final lastId = 0.obs;

  Timer? _pollTimer;

  @override
  void onInit() {
    super.onInit();
    loadTickets();
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadTickets({String? status}) async {
    isLoading.value = true;
    try {
      final response = await _data.listTickets(status: status);
      if (response['status'] == StatusRequest.success) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data;
          if (payload is Map<String, dynamic>) {
            final rawList = payload['tickets'];
            if (rawList is List) {
              tickets.value = rawList
                  .map<SupportTicketModel>(
                      (e) => SupportTicketModel.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
            }
            final rawCount = payload['unread_total'];
            if (rawCount is int) {
              unreadTotal.value = rawCount;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('SupportController loadTickets error: $e');
    }
    isLoading.value = false;
  }

  Future<void> openTicket(int ticketId) async {
    isLoading.value = true;
    messages.clear();
    lastId.value = 0;
    try {
      final response = await _data.getMessages(ticketId);
      if (response['status'] == StatusRequest.success) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data;
          if (payload is Map<String, dynamic>) {
            final rawTicket = payload['ticket'];
            if (rawTicket is Map<String, dynamic>) {
              currentTicket.value =
                  SupportTicketModel.fromJson(Map<String, dynamic>.from(rawTicket));
            }
            final rawMessages = payload['messages'];
            if (rawMessages is List) {
              messages.value = rawMessages
                  .map<SupportMessageModel>(
                      (e) => SupportMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
            }
            final rawLastId = payload['last_id'];
            if (rawLastId is int) {
              lastId.value = rawLastId;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('SupportController openTicket error: $e');
    }
    isLoading.value = false;
    _startPolling(ticketId);
  }

  void _startPolling(int ticketId) {
    _stopPolling();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollNewMessages(ticketId);
    });
  }

  Future<void> _pollNewMessages(int ticketId) async {
    if (lastId.value == 0) return;
    try {
      final response = await _data.getMessages(ticketId, afterId: lastId.value);
      if (response['status'] == StatusRequest.success) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data;
          if (payload is Map<String, dynamic>) {
            final rawMessages = payload['messages'];
            if (rawMessages is List && rawMessages.isNotEmpty) {
              final newMessages = rawMessages
                  .map<SupportMessageModel>(
                      (e) => SupportMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
              messages.addAll(newMessages);
              final rawLastId = payload['last_id'];
              if (rawLastId is int) {
                lastId.value = rawLastId;
              }
              await _data.getMessages(ticketId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('SupportController poll error: $e');
    }
  }

  Future<bool> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String body,
  }) async {
    try {
      final response = await _data.createTicket(
        subject: subject,
        category: category,
        priority: priority,
        body: body,
      );
      if (response['status'] == StatusRequest.success) {
        await loadTickets();
        return true;
      }
    } catch (e) {
      debugPrint('SupportController createTicket error: $e');
    }
    return false;
  }

  Future<bool> sendReply(String body) async {
    if (currentTicket.value == null) return false;
    isSending.value = true;
    try {
      final response = await _data.reply(currentTicket.value!.id, body);
      if (response['status'] == StatusRequest.success) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data;
          final newStatus = payload['status'] as String?;
          if (newStatus != null) {
            currentTicket.value = SupportTicketModel(
              id: currentTicket.value!.id,
              tenantId: currentTicket.value!.tenantId,
              openedByAdminId: currentTicket.value!.openedByAdminId,
              subject: currentTicket.value!.subject,
              category: currentTicket.value!.category,
              priority: currentTicket.value!.priority,
              status: newStatus,
              assignedSuperAdminId: currentTicket.value!.assignedSuperAdminId,
              lastMessageAt: DateTime.now(),
              lastMessagePreview: body,
              unreadForUser: false,
              unreadForSupport: true,
              createdAt: currentTicket.value!.createdAt,
            );
          }
        }
        await openTicket(currentTicket.value!.id);
        isSending.value = false;
        return true;
      }
    } catch (e) {
      debugPrint('SupportController sendReply error: $e');
    }
    isSending.value = false;
    return false;
  }

  Future<void> closeTicket(int ticketId) async {
    try {
      await _data.closeTicket(ticketId, 'close');
      await loadTickets();
    } catch (e) {
      debugPrint('SupportController closeTicket error: $e');
    }
  }

  Future<void> reopenTicket(int ticketId) async {
    try {
      await _data.closeTicket(ticketId, 'reopen');
      await loadTickets();
    } catch (e) {
      debugPrint('SupportController reopenTicket error: $e');
    }
  }

  void stopPolling() {
    _stopPolling();
  }
}
