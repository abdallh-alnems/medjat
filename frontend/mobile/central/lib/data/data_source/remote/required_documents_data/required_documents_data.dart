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

  /// As with categories, the model's payload carries `id` and the id now
  /// belongs in the path.
  Future<Map<String, dynamic>> updateRequired(Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data)..remove('id');
    return await _crud.patchData(
        AppLinks.documentUpdateRequired(data['id'] as int), body);
  }

  Future<Map<String, dynamic>> deleteRequired(int id) async {
    return await _crud.deleteData(AppLinks.documentDeleteRequired(id));
  }

  Future<Map<String, dynamic>> toggleRequired(int id) async {
    return await _crud.postData(AppLinks.documentToggleRequired, {'id': id});
  }

  Future<Map<String, dynamic>> getSubmissions(int requiredDocumentId) async {
    return await _crud
        .getData(AppLinks.documentRequiredSubmissions(requiredDocumentId));
  }
}
