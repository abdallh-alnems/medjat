import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/model/payroll_model.dart';

class PayrollController extends GetxController {
  final PayrollData _payrollData = Get.find<PayrollData>();

  StatusRequest status = StatusRequest.none;
  List<PayrollModel> payrolls = [];
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int? branchFilter;

  @override
  void onInit() {
    super.onInit();
    loadPayrolls();
  }

  Future<void> loadPayrolls() async {
    status = StatusRequest.loading;
    update();

    final response = await _payrollData.getPayrollMonth(
      selectedMonth,
      selectedYear,
      branchId: branchFilter,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        payrolls =
            data.map((e) => PayrollModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void changeMonth(int month, int year) {
    selectedMonth = month;
    selectedYear = year;
    loadPayrolls();
  }

  Future<void> approvePayroll(int id) async {
    final response = await _payrollData.approvePayroll(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم اعتماد كشف الراتب',
          snackPosition: SnackPosition.BOTTOM);
      loadPayrolls();
    } else {
      Get.snackbar('خطأ', 'حدث خطأ في الاعتماد',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
