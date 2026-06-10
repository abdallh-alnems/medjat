import 'dart:io';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ProfileData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getProfile() async {
    return await _crud.getData(AppLinks.myProfile);
  }

  Future<Map<String, dynamic>> submitDocument(
      int documentTypeId, File file) async {
    return await _crud.postFile(
      AppLinks.submitDocument,
      file,
      fields: {'document_type_id': documentTypeId.toString()},
    );
  }

  /// Downloads the raw bytes of one of the employee's own document files.
  Future<Map<String, dynamic>> downloadDocument(int docId) async {
    return await _crud.getBytes(
      AppLinks.myDocumentView,
      queryParameters: {'id': docId},
    );
  }
}
