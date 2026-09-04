import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/loan_model.dart';

void main() {
  group('LoanModel.fromJson', () {
    test('بيانات كاملة مع أقساط', () {
      final json = {
        'id': 1,
        'employee_id': 5,
        'employee_name': 'أحمد',
        'type': 'loan',
        'total_amount': 12000,
        'installment_amount': 1000,
        'installments_count': 12,
        'installments_paid': 3,
        'start_month': '2024-01',
        'reason': 'حاجة شخصية',
        'status': 'active',
        'installments': [
          {'id': 1, 'month': '2024-01', 'seq': 1, 'amount': 1000, 'status': 'paid'},
          {'id': 2, 'month': '2024-02', 'seq': 2, 'amount': 1000, 'status': 'pending'},
        ],
      };

      final loan = LoanModel.fromJson(json);

      expect(loan.id, 1);
      expect(loan.employeeId, 5);
      expect(loan.employeeName, 'أحمد');
      expect(loan.type, 'loan');
      expect(loan.totalAmount, 12000.0);
      expect(loan.installmentAmount, 1000.0);
      expect(loan.installmentsCount, 12);
      expect(loan.installmentsPaid, 3);
      expect(loan.startMonth, '2024-01');
      expect(loan.reason, 'حاجة شخصية');
      expect(loan.status, 'active');
      expect(loan.installments.length, 2);
      expect(loan.installments[0].isPaid, isTrue);
      expect(loan.installments[1].isPaid, isFalse);
    });

    test('بيانات ناقصة/null', () {
      final loan = LoanModel.fromJson({});

      expect(loan.id, 0);
      expect(loan.employeeId, 0);
      expect(loan.type, 'loan');
      expect(loan.totalAmount, 0);
      expect(loan.installmentsCount, 1);
      expect(loan.installmentsPaid, 0);
      expect(loan.status, 'pending');
      expect(loan.installments, isEmpty);
    });

    test('remainingAmount يحسب المبلغ المتبقي', () {
      final loan = LoanModel.fromJson({
        'total_amount': 12000,
        'installment_amount': 1000,
        'installments_count': 12,
        'installments_paid': 3,
      });

      expect(loan.remainingAmount, 9000.0);
    });

    test('remainingAmount لا يرجع سالب', () {
      final loan = LoanModel.fromJson({
        'total_amount': 5000,
        'installment_amount': 1000,
        'installments_count': 5,
        'installments_paid': 10,
      });

      expect(loan.remainingAmount, 0);
    });

    test('progress يحسب نسبة التقدم', () {
      final loan = LoanModel.fromJson({
        'installments_count': 12,
        'installments_paid': 3,
      });

      expect(loan.progress, closeTo(0.25, 0.001));
    });

    test('progress مع installmentsCount = 0', () {
      final loan = LoanModel.fromJson({
        'installments_count': 0,
      });

      expect(loan.progress, 0);
    });

    test('installments غير List تعطي قائمة فارغة', () {
      final loan = LoanModel.fromJson({
        'installments': 'not a list',
      });

      expect(loan.installments, isEmpty);
    });
  });

  group('LoanInstallmentModel', () {
    test('isPaid يرجع true فقط عند status = paid', () {
      final paid = LoanInstallmentModel.fromJson({'status': 'paid'});
      final pending = LoanInstallmentModel.fromJson({'status': 'pending'});

      expect(paid.isPaid, isTrue);
      expect(pending.isPaid, isFalse);
    });
  });
}
