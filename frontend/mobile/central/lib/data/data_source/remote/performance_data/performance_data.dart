import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class PerformanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getReviews(int employeeId) async {
    return await _crud.getData(AppLinks.employeeReviews(employeeId));
  }

  Future<Map<String, dynamic>> createReview(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.performanceReviews, data);
  }

  Future<Map<String, dynamic>> deleteReview(int id) async {
    return await _crud.postData(AppLinks.performanceReviewDelete, {'id': id});
  }
}
