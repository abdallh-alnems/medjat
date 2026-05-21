import 'package:get/get.dart';

class ExpenseClaimModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final String category;
  final double amount;
  final String currency;
  final String? description;
  final DateTime expenseDate;
  final String? receiptUrl;
  final String status;
  final String? rejectionReason;

  ExpenseClaimModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.category = 'other',
    this.amount = 0,
    this.currency = 'SAR',
    this.description,
    required this.expenseDate,
    this.receiptUrl,
    this.status = 'pending',
    this.rejectionReason,
  });

  factory ExpenseClaimModel.fromJson(Map<String, dynamic> json) {
    return ExpenseClaimModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: json['employee_name'] as String?,
      category: (json['category'] as String?) ?? 'other',
      amount: double.tryParse('${json['amount']}') ?? 0,
      currency: (json['currency'] as String?) ?? 'SAR',
      description: json['description'] as String?,
      expenseDate: json['expense_date'] != null
          ? (DateTime.tryParse(json['expense_date'] as String) ?? DateTime.now())
          : DateTime.now(),
      receiptUrl: json['receipt_url'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  String get categoryLabel => 'expense_cat_$category'.tr;

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'status_pending'.tr;
      case 'approved':
        return 'status_approved'.tr;
      case 'rejected':
        return 'status_rejected'.tr;
      case 'reimbursed':
        return 'expense_reimbursed'.tr;
      default:
        return status;
    }
  }
}
