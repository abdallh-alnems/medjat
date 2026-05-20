import 'package:get/get.dart';

class PerformanceReviewModel {
  final int id;
  final int employeeId;
  final String? reviewerName;
  final int rating;
  final String period;
  final String? notes;
  final DateTime? createdAt;

  PerformanceReviewModel({
    required this.id,
    required this.employeeId,
    this.reviewerName,
    required this.rating,
    required this.period,
    this.notes,
    this.createdAt,
  });

  factory PerformanceReviewModel.fromJson(Map<String, dynamic> json) {
    return PerformanceReviewModel(
      id: (json['id'] as int?) ?? 0,
      employeeId: (json['employee_id'] as int?) ?? 0,
      reviewerName: json['reviewer_name'] as String?,
      rating: (json['rating'] as int?) ?? 1,
      period: (json['period'] as String?) ?? '',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get ratingLabel {
    switch (rating) {
      case 1:
        return 'rating_1'.tr;
      case 2:
        return 'rating_2'.tr;
      case 3:
        return 'rating_3'.tr;
      case 4:
        return 'rating_4'.tr;
      case 5:
        return 'rating_5'.tr;
      default:
        return '$rating';
    }
  }
}
