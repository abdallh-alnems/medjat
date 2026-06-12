import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/app_control_data/app_control_data.dart';
import '../../../data/model/app_control_model.dart';

class AppControlController extends GetxController {
  final AppControlData _appControlData = Get.find<AppControlData>();

  final status = StatusRequest.none.obs;
  final apps = <AppControlModel>[].obs;
  final editingApp = RxnString();
  final versionInput = ''.obs;
  final versionErrors = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadApps();
  }

  Future<void> loadApps() async {
    status.value = StatusRequest.loading;
    update();

    final response = await _appControlData.get();

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      final list = (data?['apps'] as List? ?? [])
          .map((a) => AppControlModel.fromJson(a as Map<String, dynamic>))
          .toList();
      apps.value = list;
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  bool isValidVersion(String v) {
    if (v.isEmpty) return true;
    return RegExp(r'^\d+(\.\d+){0,3}$').hasMatch(v);
  }

  void startEditing(String appKey, String currentVersion) {
    editingApp.value = appKey;
    versionInput.value = currentVersion;
    versionErrors.clear();
    update();
  }

  void cancelEditing() {
    editingApp.value = null;
    versionInput.value = '';
    versionErrors.clear();
    update();
  }

  Future<void> saveVersion(String appKey) async {
    final version = versionInput.value.trim();
    if (version.isEmpty || !isValidVersion(version)) {
      versionErrors.value = ['صيغة الإصدار غير صحيحة'];
      return;
    }

    versionErrors.clear();
    update();

    final response = await _appControlData.set(
      app: appKey,
      minVersion: version,
    );

    if (response['status'] == StatusRequest.success) {
      editingApp.value = null;
      versionInput.value = '';
      Get.snackbar('تم', 'تم تحديث الإصدار الأدنى', snackPosition: SnackPosition.BOTTOM);
      loadApps();
    } else {
      final message = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> toggleMaintenance(String appKey, bool enabled) async {
    final response = await _appControlData.set(
      app: appKey,
      maintenance: enabled,
    );

    if (response['status'] == StatusRequest.success) {
      final label = enabled ? 'تفعيل' : 'إيقاف';
      Get.snackbar('تم', 'تم $label وضع الصيانة', snackPosition: SnackPosition.BOTTOM);
      loadApps();
    } else {
      final message = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
