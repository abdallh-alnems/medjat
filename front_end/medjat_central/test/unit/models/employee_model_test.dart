import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/employee_model.dart';

void main() {
  group('EmployeeModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'branch_id': 2,
        'name': 'أحمد محمد',
        'phone': '0501234567',
        'photo_url': 'https://example.com/photo.jpg',
        'employee_code': 'EMP001',
        'job_title': 'مدير',
        'base_salary': 5000,
        'status': 'active',
        'branch_name': 'الفرع الرئيسي',
        'hire_date': '2024-01-15',
        'work_start_time': '08:00:00',
        'work_end_time': '16:00:00',
        'annual_leave_days': 21,
        'shift_id': 3,
        'shift_name': 'الوردية الصباحية',
        'shift_start': '08:00:00',
        'shift_end': '16:00:00',
        'shift_color': '#FF0000',
        'activation_code': 'ABC123',
        'activation_expires_at': '2024-12-31',
        'biometric_enrollment_status': 'enrolled',
        'bank_name': 'الراجحي',
        'bank_account_number': '1234567890',
        'bank_iban': 'SA1234567890',
        'bank_swift': 'RJHISARI',
        'national_id': '1234567890',
        'nationality': 'سعودي',
        'iqama_number': 'IQ123',
        'iqama_expiry': '2025-06-15',
        'passport_number': 'PP123',
        'passport_expiry': '2026-01-01',
        'work_permit_number': 'WP123',
        'work_permit_expiry': '2025-12-31',
        'contract_type': 'full_time',
        'contract_start': '2024-01-15',
        'contract_end': '2025-01-15',
        'health_insurance_expiry': '2025-06-30',
      };

      final emp = EmployeeModel.fromJson(json);

      expect(emp.id, 1);
      expect(emp.branchId, 2);
      expect(emp.name, 'أحمد محمد');
      expect(emp.phone, '0501234567');
      expect(emp.photoUrl, 'https://example.com/photo.jpg');
      expect(emp.employeeCode, 'EMP001');
      expect(emp.jobTitle, 'مدير');
      expect(emp.baseSalary, 5000);
      expect(emp.status, 'active');
      expect(emp.branchName, 'الفرع الرئيسي');
      expect(emp.hireDate, DateTime(2024, 1, 15));
      expect(emp.workStartTime, '08:00:00');
      expect(emp.workEndTime, '16:00:00');
      expect(emp.annualLeaveDays, 21);
      expect(emp.shiftId, 3);
      expect(emp.shiftName, 'الوردية الصباحية');
      expect(emp.shiftStart, '08:00:00');
      expect(emp.shiftEnd, '16:00:00');
      expect(emp.shiftColor, '#FF0000');
      expect(emp.activationCode, 'ABC123');
      expect(emp.biometricEnrollmentStatus, 'enrolled');
      expect(emp.bankName, 'الراجحي');
      expect(emp.bankAccountNumber, '1234567890');
      expect(emp.bankIban, 'SA1234567890');
      expect(emp.nationalId, '1234567890');
      expect(emp.nationality, 'سعودي');
      expect(emp.iqamaNumber, 'IQ123');
      expect(emp.iqamaExpiry, DateTime(2025, 6, 15));
      expect(emp.passportNumber, 'PP123');
      expect(emp.passportExpiry, DateTime(2026, 1, 1));
      expect(emp.workPermitNumber, 'WP123');
      expect(emp.contractType, 'full_time');
      expect(emp.contractStart, DateTime(2024, 1, 15));
      expect(emp.contractEnd, DateTime(2025, 1, 15));
      expect(emp.healthInsuranceExpiry, DateTime(2025, 6, 30));
    });

    test('بيانات ناقصة/null', () {
      final emp = EmployeeModel.fromJson({});

      expect(emp.id, 0);
      expect(emp.branchId, 0);
      expect(emp.name, '');
      expect(emp.baseSalary, 0);
      expect(emp.status, 'active');
      expect(emp.workStartTime, '09:00:00');
      expect(emp.workEndTime, '17:00:00');
      expect(emp.biometricEnrollmentStatus, 'not_enrolled');
      expect(emp.phone, isNull);
      expect(emp.hireDate, isNull);
      expect(emp.annualLeaveDays, isNull);
      expect(emp.shiftId, isNull);
    });

    test('تحويل num إلى int عبر num?.toInt()', () {
      final emp = EmployeeModel.fromJson({
        'base_salary': 5000.5,
        'annual_leave_days': 21.0,
        'shift_id': 3.0,
      });

      expect(emp.baseSalary, 5000);
      expect(emp.annualLeaveDays, 21);
      expect(emp.shiftId, 3);
    });

    test('hasComplianceInfo يرجع true عند وجود بيانات', () {
      final emp = EmployeeModel.fromJson({
        'id': 1,
        'branch_id': 1,
        'name': 'Test',
        'national_id': '123',
      });
      expect(emp.hasComplianceInfo, isTrue);
    });

    test('hasComplianceInfo يرجع false بدون بيانات', () {
      final emp = EmployeeModel.fromJson({
        'id': 1,
        'branch_id': 1,
        'name': 'Test',
      });
      expect(emp.hasComplianceInfo, isFalse);
    });

    test('تاريخ غير صالح لا يرمي استثناء', () {
      final emp = EmployeeModel.fromJson({
        'id': 1,
        'branch_id': 1,
        'name': 'Test',
        'hire_date': 'not-a-date',
        'iqama_expiry': '',
      });

      expect(emp.hireDate, isNull);
      expect(emp.iqamaExpiry, isNull);
    });
  });
}
