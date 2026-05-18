import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/user_data/user_data.dart';
import '../../../data/model/user_model.dart';

class UserController extends GetxController {
  final UserData _userData = Get.find<UserData>();

  final status = StatusRequest.none.obs;
  final users = <UserModel>[].obs;
  final currentPage = 1.obs;
  final selectedTenantId = Rxn<int>();

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  Future<void> loadUsers({int? page, int? tenantId}) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _userData.list(
      page: page ?? currentPage.value,
      tenantId: tenantId ?? selectedTenantId.value,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        final items = (data['items'] as List<dynamic>?)
                ?.map((e) => UserModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        users.value = items;
        currentPage.value = data['page'] as int? ?? 1;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }
}
