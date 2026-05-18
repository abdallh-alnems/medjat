import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/model/employee_model.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/document_model.dart';

class EmployeeDetailController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();
  final AttendanceData _attendanceData = Get.find<AttendanceData>();
  final DocumentData _documentData = Get.find<DocumentData>();

  StatusRequest status = StatusRequest.none;
  StatusRequest attendanceStatus = StatusRequest.none;
  StatusRequest documentsStatus = StatusRequest.none;

  EmployeeModel? employee;
  List<AttendanceRecordModel> attendanceRecords = [];
  List<DocumentModel> documents = [];
  String? activationCode;

  final int employeeId;

  EmployeeDetailController({required this.employeeId});

  @override
  void onInit() {
    super.onInit();
    loadEmployee();
    loadAttendance();
    loadDocuments();
  }

  Future<void> loadEmployee() async {
    status = StatusRequest.loading;
    update();

    final response = await _employeeData.getEmployee(employeeId);

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        employee = EmployeeModel.fromJson(data);
        activationCode = data['activation_code'] as String?;
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadAttendance() async {
    attendanceStatus = StatusRequest.loading;
    update();

    final response = await _attendanceData.getAttendance(
      employeeId: employeeId,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        attendanceRecords = data
            .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      attendanceStatus = StatusRequest.success;
    } else {
      attendanceStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadDocuments() async {
    documentsStatus = StatusRequest.loading;
    update();

    final response = await _documentData.getDocuments(employeeId);

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        documents = data
            .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      documentsStatus = StatusRequest.success;
    } else {
      documentsStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> generateActivationCode() async {
    final response =
        await _employeeData.createEmployee({'regenerate_code': true});

    if (response['status'] == StatusRequest.success) {
      final respData = response['data'];
      if (respData is Map<String, dynamic>) {
        activationCode = respData['activation_code'] as String?;
      }
      Get.snackbar('تم', 'تم توليد كود تفعيل جديد',
          snackPosition: SnackPosition.BOTTOM);
      update();
    } else {
      Get.snackbar('خطأ', 'حدث خطأ في توليد الكود',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> deleteDocument(int docId) async {
    final response = await _documentData.deleteDocument(employeeId, docId);
    if (response['status'] == StatusRequest.success) {
      documents.removeWhere((d) => d.id == docId);
      Get.snackbar('تم', 'تم حذف الورقة', snackPosition: SnackPosition.BOTTOM);
      update();
    }
  }
}
