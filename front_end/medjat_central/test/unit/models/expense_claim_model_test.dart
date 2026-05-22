import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/expense_claim_model.dart';

void main() {
  group('ExpenseClaimModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'employee_id': 5,
        'employee_name': 'أحمد',
        'category': 'travel',
        'amount': 1500.50,
        'currency': 'SAR',
        'description': 'رحلة عمل',
        'expense_date': '2024-06-15',
        'receipt_url': 'https://example.com/receipt.pdf',
        'status': 'approved',
        'rejection_reason': null,
      };

      final claim = ExpenseClaimModel.fromJson(json);

      expect(claim.id, 1);
      expect(claim.employeeId, 5);
      expect(claim.employeeName, 'أحمد');
      expect(claim.category, 'travel');
      expect(claim.amount, 1500.50);
      expect(claim.currency, 'SAR');
      expect(claim.description, 'رحلة عمل');
      expect(claim.expenseDate, DateTime(2024, 6, 15));
      expect(claim.receiptUrl, 'https://example.com/receipt.pdf');
      expect(claim.status, 'approved');
      expect(claim.rejectionReason, isNull);
    });

    test('بيانات ناقصة/null', () {
      final claim = ExpenseClaimModel.fromJson({});

      expect(claim.id, 0);
      expect(claim.employeeId, 0);
      expect(claim.category, 'other');
      expect(claim.amount, 0);
      expect(claim.currency, 'SAR');
      expect(claim.status, 'pending');
      expect(claim.rejectionReason, isNull);
    });

    test('amount كنص يتم تحليله', () {
      final claim = ExpenseClaimModel.fromJson({
        'amount': '1500.75',
      });
      expect(claim.amount, 1500.75);
    });

    test('expense_date غير صالحة تستخدم DateTime.now', () {
      final claim = ExpenseClaimModel.fromJson({
        'expense_date': 'invalid',
      });
      expect(claim.expenseDate, isNotNull);
    });

    test('حالات مختلفة', () {
      for (final s in ['pending', 'approved', 'rejected', 'reimbursed']) {
        final claim = ExpenseClaimModel.fromJson({
          'expense_date': '2024-01-01',
          'status': s,
        });
        expect(claim.status, s);
      }
    });
  });
}
