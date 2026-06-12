import 'package:get/get.dart';

class LoanInstallmentModel {
  final int id;
  final String month;
  final int seq;
  final double amount;
  final String status;

  LoanInstallmentModel({
    required this.id,
    required this.month,
    required this.seq,
    required this.amount,
    required this.status,
  });

  factory LoanInstallmentModel.fromJson(Map<String, dynamic> json) {
    return LoanInstallmentModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      month: (json['month'] as String?) ?? '',
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      amount: double.tryParse('${json['amount']}') ?? 0,
      status: (json['status'] as String?) ?? 'pending',
    );
  }

  bool get isPaid => status == 'paid';
}

class LoanModel {
  final int id;
  final int employeeId;
  final String? employeeName;
  final String type;
  final double totalAmount;
  final double installmentAmount;
  final int installmentsCount;
  final int installmentsPaid;
  final String startMonth;
  final String? reason;
  final String status;
  final List<LoanInstallmentModel> installments;

  LoanModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.type = 'loan',
    this.totalAmount = 0,
    this.installmentAmount = 0,
    this.installmentsCount = 1,
    this.installmentsPaid = 0,
    this.startMonth = '',
    this.reason,
    this.status = 'pending',
    this.installments = const [],
  });

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    final rawInstallments = json['installments'];
    return LoanModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeId: (json['employee_id'] as num?)?.toInt() ?? 0,
      employeeName: json['employee_name'] as String?,
      type: (json['type'] as String?) ?? 'loan',
      totalAmount: double.tryParse('${json['total_amount']}') ?? 0,
      installmentAmount: double.tryParse('${json['installment_amount']}') ?? 0,
      installmentsCount: (json['installments_count'] as num?)?.toInt() ?? 1,
      installmentsPaid: (json['installments_paid'] as num?)?.toInt() ?? 0,
      startMonth: (json['start_month'] as String?) ?? '',
      reason: json['reason'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      installments: rawInstallments is List
          ? rawInstallments
              .whereType<Map<String, dynamic>>()
              .map(LoanInstallmentModel.fromJson)
              .toList()
          : const [],
    );
  }

  double get remainingAmount {
    final paid = installmentsPaid.clamp(0, installmentsCount);
    return (totalAmount - installmentAmount * paid).clamp(0, totalAmount);
  }

  double get progress =>
      installmentsCount == 0 ? 0 : installmentsPaid / installmentsCount;

  String get typeLabel => type == 'advance' ? 'loan_type_advance'.tr : 'loan_type_loan'.tr;

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'status_pending'.tr;
      case 'active':
        return 'loan_active'.tr;
      case 'completed':
        return 'loan_completed'.tr;
      case 'cancelled':
        return 'loan_cancelled'.tr;
      case 'rejected':
        return 'loan_rejected'.tr;
      default:
        return status;
    }
  }
}
