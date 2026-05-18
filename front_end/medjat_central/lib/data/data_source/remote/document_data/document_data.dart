import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DocumentData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getDocuments(int employeeId) async {
    return await _crud.getData(AppLinks.employeeDocuments(employeeId));
  }

  Future<Map<String, dynamic>> uploadDocument(
      int employeeId, Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.employeeDocuments(employeeId), data);
  }

  Future<Map<String, dynamic>> deleteDocument(
      int employeeId, int docId) async {
    return await _crud
        .deleteData(AppLinks.employeeDocument(employeeId, docId));
  }
}
