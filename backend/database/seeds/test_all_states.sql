-- =====================================================================
-- COMPREHENSIVE TEST SEED — every state of every major entity.
-- Target: tenant 1 (ميدجات التجريبية), employee 1 (Ibrahim) & 2 (Reviewer),
--         admin 1 (GM, approver), branches 1 (Shibin) & 2 (Main).
--
-- Everything is tagged so you can wipe it in one go (see CLEANUP at the end):
--   - text rows contain "TEST"
--   - payroll uses months 2020-01/02/03
--   - attendance uses dates in 2025-12
--   - test employees are named "TEST ..."
-- Run the whole file in phpMyAdmin (database u869543217_medjat) → SQL tab.
-- =====================================================================
USE `u869543217_medjat`;

-- ── EMPLOYEES: every status (active already exists as emp 1 & 2) ───────
INSERT INTO `employees` (`tenant_id`,`branch_id`,`name`,`job_title`,`base_salary`,`hire_date`,`status`) VALUES
(1,1,'TEST موظف في اجازة','Sales',8000.00,'2025-01-10','on_leave'),
(1,1,'TEST موظف موقوف','Sales',8000.00,'2025-02-15','suspended'),
(1,2,'TEST موظف منتهي خدمته','Driver',6000.00,'2024-03-01','terminated'),
(1,2,'TEST موظف بانتظار التفعيل','Trainee',5000.00,'2026-06-01','pending_activation');

-- Suspension record (active + ended) for the suspended test employee
INSERT INTO `employee_suspensions` (`tenant_id`,`employee_id`,`reason`,`pay_mode`,`pay_percentage`,`start_date`,`end_date`,`status`,`created_by`)
SELECT 1, id, 'TEST ايقاف نشط (بدون راتب)', 'unpaid', NULL, '2026-06-01', NULL, 'active', 1 FROM `employees` WHERE name='TEST موظف موقوف' LIMIT 1;
INSERT INTO `employee_suspensions` (`tenant_id`,`employee_id`,`reason`,`pay_mode`,`pay_percentage`,`start_date`,`end_date`,`status`,`ended_at`,`ended_by`,`created_by`)
VALUES (1,1,'TEST ايقاف منتهي (جزئي 50%)','partial',50.00,'2026-05-01','2026-05-10','ended',NOW(),1,1);

-- ── LEAVES: 6 types × 3 statuses = 18 ─────────────────────────────────
INSERT INTO `leaves`
 (`tenant_id`,`employee_id`,`date`,`start_date`,`end_date`,`type`,`reason`,`status`,`approved_by`,`approved_at`,`rejected_by`,`rejection_reason`,`created_at`)
VALUES
(1,1,'2026-07-01','2026-07-01','2026-07-03','annual','TEST اجازة سنوية - قيد الانتظار','pending',NULL,NULL,NULL,NULL,NOW()),
(1,1,'2026-07-05','2026-07-05','2026-07-07','annual','TEST اجازة سنوية - مقبولة','approved',1,NOW(),NULL,NULL,NOW()),
(1,1,'2026-07-09','2026-07-09','2026-07-10','annual','TEST اجازة سنوية - مرفوضة','rejected',NULL,NULL,1,'TEST سبب الرفض',NOW()),
(1,1,'2026-07-12','2026-07-12','2026-07-12','sick','TEST اجازة مرضية - قيد الانتظار','pending',NULL,NULL,NULL,NULL,NOW()),
(1,1,'2026-07-14','2026-07-14','2026-07-16','sick','TEST اجازة مرضية - مقبولة','approved',1,NOW(),NULL,NULL,NOW()),
(1,1,'2026-07-18','2026-07-18','2026-07-18','sick','TEST اجازة مرضية - مرفوضة','rejected',NULL,NULL,1,'TEST سبب الرفض',NOW()),
(1,1,'2026-07-20','2026-07-20','2026-07-20','personal','TEST اجازة شخصية - قيد الانتظار','pending',NULL,NULL,NULL,NULL,NOW()),
(1,1,'2026-07-22','2026-07-22','2026-07-23','personal','TEST اجازة شخصية - مقبولة','approved',1,NOW(),NULL,NULL,NOW()),
(1,1,'2026-07-25','2026-07-25','2026-07-25','personal','TEST اجازة شخصية - مرفوضة','rejected',NULL,NULL,1,'TEST سبب الرفض',NOW()),
(1,1,'2026-07-27','2026-07-27','2026-07-29','unpaid','TEST اجازة بدون راتب - قيد الانتظار','pending',NULL,NULL,NULL,NULL,NOW()),
(1,1,'2026-08-01','2026-08-01','2026-08-05','unpaid','TEST اجازة بدون راتب - مقبولة','approved',1,NOW(),NULL,NULL,NOW()),
(1,1,'2026-08-07','2026-08-07','2026-08-07','unpaid','TEST اجازة بدون راتب - مرفوضة','rejected',NULL,NULL,1,'TEST سبب الرفض',NOW()),
(1,1,'2026-08-09','2026-08-09','2026-08-09','weekly_off','TEST راحة اسبوعية - قيد الانتظار','pending',NULL,NULL,NULL,NULL,NOW()),
(1,1,'2026-08-10','2026-08-10','2026-08-10','weekly_off','TEST راحة اسبوعية - مقبولة','approved',1,NOW(),NULL,NULL,NOW()),
(1,1,'2026-08-11','2026-08-11','2026-08-11','weekly_off','TEST راحة اسبوعية - مرفوضة','rejected',NULL,NULL,1,'TEST سبب الرفض',NOW()),
(1,1,'2026-08-13','2026-08-13','2026-08-13','converted_from_absence','TEST تحويل من غياب - قيد الانتظار','pending',NULL,NULL,NULL,NULL,NOW()),
(1,1,'2026-08-14','2026-08-14','2026-08-14','converted_from_absence','TEST تحويل من غياب - مقبول','approved',1,NOW(),NULL,NULL,NOW()),
(1,1,'2026-08-15','2026-08-15','2026-08-15','converted_from_absence','TEST تحويل من غياب - مرفوض','rejected',NULL,NULL,1,'TEST سبب الرفض',NOW());

-- ── LOANS / ADVANCES: every status ────────────────────────────────────
INSERT INTO `employee_loans`
 (`tenant_id`,`employee_id`,`type`,`total_amount`,`installment_amount`,`installments_count`,`installments_paid`,`start_month`,`reason`,`status`,`created_by`,`approved_by`,`approved_at`)
VALUES
(1,1,'loan',   12000.00,1000.00,12,0,'2026-07','TEST سلفة - قيد الانتظار','pending',  1,NULL,NULL),
(1,1,'loan',   12000.00,1000.00,12,3,'2026-04','TEST سلفة - نشطة','active',           1,1,NOW()),
(1,1,'loan',    6000.00,1000.00, 6,6,'2025-10','TEST سلفة - مكتملة','completed',       1,1,NOW()),
(1,1,'loan',    9000.00,1500.00, 6,0,'2026-07','TEST سلفة - ملغاة','cancelled',        1,NULL,NULL),
(1,1,'loan',   15000.00,1500.00,10,0,'2026-07','TEST سلفة - مرفوضة','rejected',        1,NULL,NULL),
(1,1,'advance', 3000.00,3000.00, 1,0,'2026-07','TEST سلفة مالية (advance) - نشطة','active',1,1,NOW());

-- Installments for the active loan: some paid, some pending
INSERT INTO `loan_installments` (`tenant_id`,`loan_id`,`employee_id`,`month`,`seq`,`amount`,`status`,`paid_at`)
SELECT 1, l.id, 1, '2026-04', 1, 1000.00, 'paid', NOW() FROM `employee_loans` l WHERE l.reason='TEST سلفة - نشطة' LIMIT 1;
INSERT INTO `loan_installments` (`tenant_id`,`loan_id`,`employee_id`,`month`,`seq`,`amount`,`status`,`paid_at`)
SELECT 1, l.id, 1, '2026-05', 2, 1000.00, 'paid', NOW() FROM `employee_loans` l WHERE l.reason='TEST سلفة - نشطة' LIMIT 1;
INSERT INTO `loan_installments` (`tenant_id`,`loan_id`,`employee_id`,`month`,`seq`,`amount`,`status`)
SELECT 1, l.id, 1, '2026-06', 3, 1000.00, 'pending' FROM `employee_loans` l WHERE l.reason='TEST سلفة - نشطة' LIMIT 1;

-- ── BREAK / PERMISSION REQUESTS: every status ─────────────────────────
INSERT INTO `break_requests`
 (`tenant_id`,`employee_id`,`date`,`start_time`,`end_time`,`duration_minutes`,`type`,`deduct_from_salary`,`reason`,`status`,`decided_by`,`decided_at`,`decision_note`,`suggested_date`,`suggested_start_time`,`suggested_end_time`)
VALUES
(1,1,'2026-07-02','10:00:00','11:00:00',60,'TEST إذن خروج','0','TEST سبب','pending',  NULL,NULL,NULL,NULL,NULL,NULL),
(1,1,'2026-07-03','12:00:00','13:00:00',60,'TEST مشوار','0','TEST سبب','approved',     1,NOW(),'TEST موافقة',NULL,NULL,NULL),
(1,1,'2026-07-04','09:00:00','09:30:00',30,'TEST تأخير','1','TEST سبب','rejected',     1,NOW(),'TEST سبب الرفض',NULL,NULL,NULL),
(1,1,'2026-07-05','14:00:00','15:00:00',60,'TEST بريك','0','TEST سبب','postponed',     1,NOW(),'TEST تم اقتراح وقت بديل','2026-07-06','14:00:00','15:00:00'),
(1,1,'2026-07-07','16:00:00','17:00:00',60,'TEST إذن','0','TEST سبب','cancelled',      NULL,NULL,NULL,NULL,NULL,NULL);

-- ── WARNINGS: every type ──────────────────────────────────────────────
INSERT INTO `warnings` (`tenant_id`,`employee_id`,`type`,`reason`,`issued_by`) VALUES
(1,1,'verbal',       'TEST إنذار شفهي',1),
(1,1,'written',      'TEST إنذار كتابي',1),
(1,1,'final',        'TEST إنذار نهائي',1),
(1,1,'device_change','TEST تغيير جهاز',1),
(1,1,'system',       'TEST إنذار نظام',1);

-- ── EMPLOYEE DOCUMENTS: every status ──────────────────────────────────
INSERT INTO `employee_documents`
 (`tenant_id`,`employee_id`,`file_path`,`original_name`,`status`,`expires_at`,`uploaded_by`,`notes`,`rejected_reason`)
VALUES
(1,1,'test/doc_uploaded.pdf','TEST مرفوع.pdf','uploaded',  '2027-01-01',1,'TEST مستند مرفوع',NULL),
(1,1,'test/doc_expired.pdf', 'TEST منتهي.pdf','expired',    '2025-01-01',1,'TEST مستند منتهي',NULL),
(1,1,'',                     'TEST مطلوب','required',        NULL,        1,'TEST مستند مطلوب',NULL),
(1,1,'test/doc_rejected.pdf','TEST مرفوض.pdf','rejected',   '2027-01-01',1,'TEST مستند مرفوض','TEST صورة غير واضحة');

-- ── ASSET CUSTODY (عُهد): every type & status ─────────────────────────
INSERT INTO `asset_custody`
 (`tenant_id`,`employee_id`,`type`,`name`,`description`,`value`,`currency`,`quantity`,`status`,`notes`,`assigned_at`,`assigned_by`,`return_requested_at`,`returned_at`,`return_approved_by`)
VALUES
(1,1,'device',   'TEST لابتوب','Dell',25000.00,'EGP',1,'assigned',         'TEST عهدة مسلّمة','2026-06-01',1,NULL,NULL,NULL),
(1,1,'equipment','TEST معدة','Tools',5000.00,'EGP',1,'return_requested','TEST طلب إرجاع','2026-06-01',1,NOW(),NULL,NULL),
(1,1,'vehicle',  'TEST سيارة','Toyota',300000.00,'EGP',1,'returned',     'TEST تم الإرجاع','2026-05-01',1,NOW(),NOW(),1);

-- ── ATTENDANCE: every status (dates in 2025-12 to avoid clashes) ──────
INSERT INTO `attendance`
 (`tenant_id`,`branch_id`,`employee_id`,`date`,`check_in_time`,`check_out_time`,`worked_minutes`,`late_minutes`,`check_in_method`,`status`,`recorded_by`,`notes`)
VALUES
(1,1,1,'2025-12-01','09:00:00','17:00:00',480,0,'qr_gps','present', 1,'TEST حاضر'),
(1,1,1,'2025-12-02','09:35:00','17:00:00',445,35,'qr_gps','present',1,'TEST حاضر متأخر'),
(1,1,1,'2025-12-03',NULL,NULL,0,0,'manual','absent',                1,'TEST غائب'),
(1,1,1,'2025-12-04',NULL,NULL,0,0,'manual','leave',                 1,'TEST في اجازة'),
(1,1,1,'2025-12-05',NULL,NULL,0,0,'manual','holiday',               1,'TEST اجازة رسمية'),
(1,1,1,'2025-12-06',NULL,NULL,0,0,'manual','weekly_off',            1,'TEST راحة اسبوعية');

-- ── PAYROLL: every status (months 2020-01/02/03) ──────────────────────
INSERT INTO `payroll`
 (`tenant_id`,`employee_id`,`branch_id`,`month`,`base_salary`,`total_deductions`,`total_bonuses`,`net_salary`,`working_days`,`present_days`,`absent_days`,`status`,`approved_by`,`approved_at`,`paid_at`)
VALUES
(1,1,1,'2020-01',50000.00,2000.00,1000.00,49000.00,26,25,1,'draft',   NULL,NULL,NULL),
(1,1,1,'2020-02',50000.00,1500.00, 500.00,49000.00,26,26,0,'approved',1,NOW(),NULL),
(1,1,1,'2020-03',50000.00,   0.00,3000.00,53000.00,26,26,0,'paid',    1,NOW(),NOW());

-- ── MANUAL DEDUCTIONS / BONUSES / ALLOWANCES ──────────────────────────
INSERT INTO `manual_deductions` (`tenant_id`,`employee_id`,`amount`,`reason`,`month`,`created_by`) VALUES
(1,1,500.00,'TEST خصم يدوي','2026-07',1);
INSERT INTO `manual_bonuses` (`tenant_id`,`employee_id`,`amount`,`reason`,`month`,`created_by`) VALUES
(1,1,750.00,'TEST مكافأة يدوية','2026-07',1);
INSERT INTO `employee_allowances` (`tenant_id`,`employee_id`,`type`,`label`,`amount`,`start_month`,`end_month`,`created_by`) VALUES
(1,1,'housing','TEST بدل سكن',1500.00,'2026-07',NULL,1),
(1,1,'transport','TEST بدل انتقال',800.00,'2026-07','2026-12',1);

-- ── SUPPORT TICKETS: every status ─────────────────────────────────────
INSERT INTO `support_tickets`
 (`tenant_id`,`opened_by_admin_id`,`subject`,`category`,`priority`,`status`,`last_message_at`,`last_message_preview`)
VALUES
(1,1,'TEST تذكرة - مفتوحة','technical','low','open',NOW(),'TEST'),
(1,1,'TEST تذكرة - بانتظار الدعم','billing','normal','pending_support',NOW(),'TEST'),
(1,1,'TEST تذكرة - بانتظار المستخدم','account','high','pending_user',NOW(),'TEST'),
(1,1,'TEST تذكرة - تم حلها','feature_request','normal','resolved',NOW(),'TEST'),
(1,1,'TEST تذكرة - مغلقة','other','urgent','closed',NOW(),'TEST');

-- ── MANAGER INVITATIONS: pending / accepted / cancelled ───────────────
INSERT INTO `manager_invitations`
 (`tenant_id`,`email`,`name`,`role`,`branch_id`,`token_hash`,`expires_at`,`accepted_at`,`accepted_admin_id`,`cancelled_at`,`invited_by`)
VALUES
(1,'test.pending@example.com','TEST دعوة معلقة','hr',NULL,SHA2('test-inv-1',256),DATE_ADD(NOW(),INTERVAL 3 DAY),NULL,NULL,NULL,1),
(1,'test.accepted@example.com','TEST دعوة مقبولة','branch_manager',2,SHA2('test-inv-2',256),DATE_ADD(NOW(),INTERVAL 3 DAY),NOW(),1,NULL,1),
(1,'test.cancelled@example.com','TEST دعوة ملغاة','viewer',NULL,SHA2('test-inv-3',256),DATE_ADD(NOW(),INTERVAL 3 DAY),NULL,NULL,NOW(),1);

-- ── EMPLOYEE SETTLEMENTS (مستحقات نهاية الخدمة): every status ──────────
-- NOTE: employee_settlements has a UNIQUE (tenant_id, employee_id) — one row per
-- employee — so each status goes on a different (test) employee.
INSERT INTO `employee_settlements`
 (`tenant_id`,`employee_id`,`reason`,`notes`,`last_working_day`,`base_salary`,`daily_rate`,`years_of_service`,`pending_salary`,`gratuity_amount`,`net_amount`,`status`,`created_by`,`approved_by`,`approved_at`,`paid_at`)
SELECT 1, id, 'resignation','TEST تسوية - مسودة','2026-06-30',8000.00,266.67,2.00,4000.00,5000.00,9000.00,'draft',1,NULL,NULL,NULL
FROM `employees` WHERE name='TEST موظف موقوف' LIMIT 1;
INSERT INTO `employee_settlements`
 (`tenant_id`,`employee_id`,`reason`,`notes`,`last_working_day`,`base_salary`,`daily_rate`,`years_of_service`,`pending_salary`,`gratuity_amount`,`net_amount`,`status`,`created_by`,`approved_by`,`approved_at`,`paid_at`)
SELECT 1, id, 'termination','TEST تسوية - معتمدة','2026-06-30',6000.00,200.00,3.00,3000.00,4500.00,7500.00,'approved',1,1,NOW(),NULL
FROM `employees` WHERE name='TEST موظف منتهي خدمته' LIMIT 1;
INSERT INTO `employee_settlements`
 (`tenant_id`,`employee_id`,`reason`,`notes`,`last_working_day`,`base_salary`,`daily_rate`,`years_of_service`,`pending_salary`,`gratuity_amount`,`net_amount`,`status`,`created_by`,`approved_by`,`approved_at`,`paid_at`)
SELECT 1, id, 'end_of_contract','TEST تسوية - مدفوعة','2026-06-30',8000.00,266.67,5.00,4000.00,7000.00,11000.00,'paid',1,1,NOW(),NOW()
FROM `employees` WHERE name='TEST موظف في اجازة' LIMIT 1;

-- ── Verify ────────────────────────────────────────────────────────────
SELECT 'leaves' tbl, COUNT(*) n FROM leaves WHERE reason LIKE 'TEST%'
UNION ALL SELECT 'loans', COUNT(*) FROM employee_loans WHERE reason LIKE 'TEST%'
UNION ALL SELECT 'breaks', COUNT(*) FROM break_requests WHERE reason LIKE 'TEST%'
UNION ALL SELECT 'warnings', COUNT(*) FROM warnings WHERE reason LIKE 'TEST%'
UNION ALL SELECT 'documents', COUNT(*) FROM employee_documents WHERE notes LIKE 'TEST%'
UNION ALL SELECT 'assets', COUNT(*) FROM asset_custody WHERE name LIKE 'TEST%'
UNION ALL SELECT 'attendance', COUNT(*) FROM attendance WHERE notes LIKE 'TEST%'
UNION ALL SELECT 'payroll', COUNT(*) FROM payroll WHERE month IN ('2020-01','2020-02','2020-03')
UNION ALL SELECT 'settlements', COUNT(*) FROM employee_settlements WHERE notes LIKE 'TEST%'
UNION ALL SELECT 'support', COUNT(*) FROM support_tickets WHERE subject LIKE 'TEST%'
UNION ALL SELECT 'invitations', COUNT(*) FROM manager_invitations WHERE name LIKE 'TEST%'
UNION ALL SELECT 'test_employees', COUNT(*) FROM employees WHERE name LIKE 'TEST%';
