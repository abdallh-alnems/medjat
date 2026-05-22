import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/profile_data/profile_data.dart';

class ProfileController extends GetxController {
  final ProfileData _profileData = Get.find<ProfileData>();

  StatusRequest status = StatusRequest.none;
  StatusRequest updateStatus = StatusRequest.none;
  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> warnings = [];
  Map<String, dynamic>? leaveBalance;
  List<Map<String, dynamic>> categories = [];

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    status = StatusRequest.loading;
    update();

    final response = await _profileData.getProfile();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        profileData = data['employee'] as Map<String, dynamic>?;
        documents = (data['documents'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        warnings = (data['warnings'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        leaveBalance = data['leave_balance'] as Map<String, dynamic>?;
        categories = (data['categories'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
      }
      status = StatusRequest.success;
    } else if (responseStatus == StatusRequest.offline) {
      status = StatusRequest.offline;
    } else {
      status = StatusRequest.failure;
    }

    update();
  }

  Future<bool> updateProfile({required String name}) async {
    updateStatus = StatusRequest.loading;
    update();

    final response = await _profileData.updateProfile(name: name);

    if (response['status'] == StatusRequest.success) {
      updateStatus = StatusRequest.success;
      await loadProfile();
      Get.snackbar('تم', 'تم تحديث البيانات بنجاح',
          snackPosition: SnackPosition.BOTTOM);
      return true;
    } else {
      updateStatus = StatusRequest.failure;
      final msg = (response['message'] as String?) ?? 'فشل تحديث البيانات';
      Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
      update();
      return false;
    }
  }
}
