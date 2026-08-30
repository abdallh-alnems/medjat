import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class RequiredDocumentsData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getRequired() async {
    return await _crud.getData(AppLinks.documentsRequired);
  }

  Future<Map<String, dynamic>> createRequired(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.documentCreateRequired, data);
  }

  Future<Map<String, dynamic>> updateRequired(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.documentUpdateRequired, data);
  }

  Future<Map<String, dynamic>> deleteRequired(int id) async {
    return await _crud.postData(AppLinks.documentDeleteRequired, {'id': id});
  }

  Future<Map<String, dynamic>> toggleRequired(int id) async {
    return await _crud.postData(AppLinks.documentToggleRequired, {'id': id});
  }

  Future<Map<String, dynamic>> getSubmissions(int requiredDocumentId) async {
    return await _crud
        .getData(AppLinks.documentRequiredSubmissions(requiredDocumentId));
  }
}
