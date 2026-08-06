import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/user_data/user_data.dart';
import '../../../data/model/user_model.dart';

/// The client contact book and the actions that go with it.
class UserController extends GetxController {
  final UserData _userData = Get.find<UserData>();

  final status = StatusRequest.none.obs;
  final users = <UserModel>[].obs;
  final currentPage = 1.obs;
  final totalPages = 1.obs;
  final total = 0.obs;
  final selectedTenantId = Rxn<int>();
  final searchQuery = ''.obs;
  final statusFilter = ''.obs;
  final busy = false.obs;

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadUsers({int? page, int? tenantId}) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _userData.list(
      page: page ?? currentPage.value,
      tenantId: tenantId ?? selectedTenantId.value,
      q: searchQuery.value,
      status: statusFilter.value,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        users.value = (data['items'] as List<dynamic>?)
                ?.map((e) => UserModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        currentPage.value = data['page'] as int? ?? 1;
        totalPages.value = data['total_pages'] as int? ?? 1;
        total.value = data['total'] as int? ?? users.length;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      currentPage.value = 1;
      loadUsers(page: 1);
    });
  }

  void setStatusFilter(String value) {
    statusFilter.value = value;
    currentPage.value = 1;
    loadUsers(page: 1);
  }

  bool get hasNextPage => currentPage.value < totalPages.value;
  bool get hasPreviousPage => currentPage.value > 1;

  void nextPage() {
    if (hasNextPage) loadUsers(page: currentPage.value + 1);
  }

  void previousPage() {
    if (hasPreviousPage) loadUsers(page: currentPage.value - 1);
  }

  Future<void> setActive(UserModel user, bool isActive) async {
    busy.value = true;
    update();
    final response = await _userData.setActive(user.id, isActive);
    busy.value = false;

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', isActive ? 'تم تفعيل الحساب' : 'تم إيقاف الحساب',
          snackPosition: SnackPosition.BOTTOM);
      await loadUsers();
    } else {
      _showError(response);
      update();
    }
  }

  Future<void> sendPasswordReset(UserModel user) async {
    busy.value = true;
    update();
    final response = await _userData.sendPasswordReset(user.id);
    busy.value = false;
    update();

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'أُرسل رابط إعادة التعيين إلى ${user.email}',
          snackPosition: SnackPosition.BOTTOM);
    } else {
      _showError(response);
    }
  }

  /// Opens the client's own dashboard in the browser as this administrator.
  /// The reason is mandatory and is written to the company's audit log.
  Future<void> impersonate(UserModel user, String reason) async {
    busy.value = true;
    update();
    final response = await _userData.impersonate(user.id, reason);
    busy.value = false;
    update();

    if (response['status'] != StatusRequest.success) {
      _showError(response);
      return;
    }

    final data = response['data']?['data'] ?? response['data'];
    final url = data?['url'] as String?;
    if (url == null) {
      Get.snackbar('خطأ', 'لم يصل رابط الدخول', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: url));
      Get.snackbar('تم النسخ', 'تعذّر فتح المتصفح — نُسخ الرابط',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showError(Map<String, dynamic> response) {
    final message = response['message'] as String? ?? 'حدث خطأ';
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
  }
}

/// Dialling, WhatsApp and email — shared by the contact book and the company
/// screen, since both list people we may need to reach.
class ContactActions {
  ContactActions._();

  static Future<void> call(String phone) async {
    await _open(Uri(scheme: 'tel', path: _clean(phone)));
  }

  static Future<void> whatsapp(String phone) async {
    // wa.me wants the number without '+' or separators.
    final digits = _clean(phone).replaceAll('+', '');
    await _open(Uri.parse('https://wa.me/$digits'));
  }

  static Future<void> email(String address) async {
    await _open(Uri(scheme: 'mailto', path: address));
  }

  static String _clean(String phone) => phone.replaceAll(RegExp(r'[\s\-()]'), '');

  static Future<void> _open(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        Get.snackbar('تعذّر الفتح', uri.toString(), snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      Get.snackbar('تعذّر الفتح', uri.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }
}
