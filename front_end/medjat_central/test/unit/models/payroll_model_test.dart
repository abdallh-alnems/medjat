import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/payroll_model.dart';

void main() {
  group('PayrollModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'employee_id': 5,
        'employee_name': 'أحمد',
        'month': 6,
        'year': 2024,
        'base_salary': 10000.0,
        'total_deductions': 500.0,
        'total_overtime': 200.0,
        'net_salary': 9700.0,
        'status': 'approved',
        'generated_at': '2024-06-30T23:59:59',
      };

      final p = PayrollModel.fromJson(json);

      expect(p.id, 1);
      expect(p.employeeId, 5);
      expect(p.employeeName, 'أحمد');
      expect(p.month, 6);
      expect(p.year, 2024);
      expect(p.baseSalary, 10000.0);
      expect(p.totalDeductions, 500.0);
      expect(p.totalOvertime, 200.0);
      expect(p.netSalary, 9700.0);
      expect(p.status, 'approved');
      expect(p.generatedAt, DateTime(2024, 6, 30, 23, 59, 59));
    });

    test('بيانات ناقصة/null', () {
      final p = PayrollModel.fromJson({});

      expect(p.id, 0);
      expect(p.employeeId, 0);
      expect(p.employeeName, isNull);
      expect(p.month, 1);
      expect(p.year, 2026);
      expect(p.baseSalary, 0);
      expect(p.totalDeductions, 0);
      expect(p.totalOvertime, 0);
      expect(p.netSalary, 0);
      expect(p.status, 'draft');
      expect(p.generatedAt, isNull);
    });

    test('تحويل num', () {
      final p = PayrollModel.fromJson({
        'base_salary': 10000,
        'total_deductions': 500,
        'total_overtime': 200,
        'net_salary': 9700,
      });

      expect(p.baseSalary, 10000.0);
      expect(p.totalDeductions, 500.0);
      expect(p.totalOvertime, 200.0);
      expect(p.netSalary, 9700.0);
    });
  });
}
