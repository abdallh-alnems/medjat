import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class PayrollData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getSlip(String month) async {
    return await _crud.getData(AppLinks.payrollSlipMonth(month));
  }

  Future<Map<String, dynamic>> getSlipPdf(String month) async {
    return await _crud.getBytes(AppLinks.payrollPdf(month));
  }
}
