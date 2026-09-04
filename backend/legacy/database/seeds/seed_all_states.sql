-- ============================================================================
-- Permedjat — Comprehensive seed covering ALL possible states (local MAMP only)
-- Wipes every operational table and rebuilds one full company (tenant 3)
-- with at least one row per enum/status across the whole schema.
--
-- PRESERVED (not wiped): `super_admins`
-- PRESERVED logins recreated with original firebase_uid:
--   admin 3 = farkha.nims (general_manager, tenant 3)  -> management app login
--   employee 12 (+201023809407)                        -> employee app login
--
-- Run: mysql -h127.0.0.1 -P8889 -uroot -proot permedjat < seed_all_states.sql
-- ============================================================================

SET NAMES utf8mb4;
SET @D := CURDATE();
SET @MON := DATE_FORMAT(@D, '%Y-%m');                       -- current month YYYY-MM
SET @PREV := DATE_FORMAT(@D - INTERVAL 1 MONTH, '%Y-%m');   -- previous month
SET @YR := YEAR(@D);

-- ---------------------------------------------------------------------------
-- 1) WIPE — every table except super_admins
-- ---------------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE admin_devices;
TRUNCATE TABLE admin_notification_prefs;
TRUNCATE TABLE admins;
TRUNCATE TABLE analytics_dashboards;
TRUNCATE TABLE announcement_reads;
TRUNCATE TABLE announcements;
TRUNCATE TABLE approval_chain_steps;
TRUNCATE TABLE approval_chains;
TRUNCATE TABLE approval_request_steps;
TRUNCATE TABLE approval_requests;
TRUNCATE TABLE asset_custody;
TRUNCATE TABLE attendance;
TRUNCATE TABLE audit_log;
TRUNCATE TABLE bonus_rules;
TRUNCATE TABLE branches;
TRUNCATE TABLE break_requests;
TRUNCATE TABLE candidates;
TRUNCATE TABLE custom_roles;
TRUNCATE TABLE deduction_rules;
TRUNCATE TABLE employee_activation_codes;
TRUNCATE TABLE employee_allowances;
TRUNCATE TABLE employee_auth_tokens;
TRUNCATE TABLE employee_availability;
TRUNCATE TABLE employee_categories;
TRUNCATE TABLE employee_category_assignments;
TRUNCATE TABLE employee_documents;
TRUNCATE TABLE employee_loans;
TRUNCATE TABLE employee_settlements;
TRUNCATE TABLE employee_shift_schedule;
TRUNCATE TABLE employee_suspensions;
TRUNCATE TABLE employees;
TRUNCATE TABLE holidays;
TRUNCATE TABLE job_openings;
TRUNCATE TABLE kudos;
TRUNCATE TABLE leave_year_balances;
TRUNCATE TABLE leaves;
TRUNCATE TABLE loan_installments;
TRUNCATE TABLE login_attempts;
TRUNCATE TABLE manager_invitations;
TRUNCATE TABLE manual_bonuses;
TRUNCATE TABLE manual_deductions;
TRUNCATE TABLE notifications;
TRUNCATE TABLE onboarding_tasks;
TRUNCATE TABLE onboarding_templates;
TRUNCATE TABLE open_shift_claims;
TRUNCATE TABLE open_shifts;
TRUNCATE TABLE payroll;
TRUNCATE TABLE payroll_line_overrides;
TRUNCATE TABLE payroll_statutory_settings;
TRUNCATE TABLE performance_cycles;
TRUNCATE TABLE performance_goals;
TRUNCATE TABLE performance_reviews;
TRUNCATE TABLE recurring_leaves;
TRUNCATE TABLE required_document_categories;
TRUNCATE TABLE required_document_employees;
TRUNCATE TABLE required_documents;
TRUNCATE TABLE shift_swap_requests;
TRUNCATE TABLE shifts;
TRUNCATE TABLE super_admin_audit_log;
TRUNCATE TABLE super_admin_sessions;
TRUNCATE TABLE survey_answers;
TRUNCATE TABLE survey_completions;
TRUNCATE TABLE survey_questions;
TRUNCATE TABLE survey_responses;
TRUNCATE TABLE surveys;
TRUNCATE TABLE support_messages;
TRUNCATE TABLE support_tickets;
TRUNCATE TABLE tenants;
TRUNCATE TABLE warnings;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------------
-- 2) TENANT
-- ---------------------------------------------------------------------------
INSERT INTO tenants (id, name, timezone, currency, country_code, is_active,
  email_verified_at, attendance_methods, allow_offline_attendance,
  default_annual_leave_days, leave_carryover_max_days, cycle_start_day,
  commercial_register, company_address, company_phone)
VALUES (3, 'شركة بيرمدجات التجريبية', 'Asia/Riyadh', 'SAR', 'SA', 1,
  NOW(), JSON_ARRAY('qr_gps','manual','offline'), 1,
  21, 10, 1, 'CR-1010101010', 'الرياض - حي العليا - طريق الملك فهد', '+966112345678');

-- payment_transactions seed removed — table dropped 2026-06-13 (unused)

-- ---------------------------------------------------------------------------
-- 3) BRANCHES (active x2, inactive x1)
-- ---------------------------------------------------------------------------
INSERT INTO branches (id, tenant_id, name, address, latitude, longitude, qr_code, is_active,
  gps_radius_meters, cycle_start_day, allow_offline_attendance)
VALUES
 (1, 3, 'فرع الرياض الرئيسي', 'الرياض - حي العليا', 24.7136000, 46.6753000, 'MED-RIYADH-0001', 1,
   150, NULL, 1),
 (2, 3, 'فرع جدة', 'جدة - حي الروضة', 21.5433000, 39.1728000, 'MED-JEDDAH-0002', 1,
   200, NULL, NULL),
 (3, 3, 'فرع الدمام (مغلق)', 'الدمام - حي الشاطئ', 26.4207000, 50.0888000, 'MED-DAMMAM-0003', 0,
   100, NULL, 0);

-- ---------------------------------------------------------------------------
-- 4) ADMINS — preserved Google logins (2,3,4) + one per role
-- ---------------------------------------------------------------------------
INSERT INTO admins (id, firebase_uid, tenant_id, branch_id, name, phone, email,
  auth_provider, role, is_active, active_device_id) VALUES
 (2,  'VefQrxBWg9VJgTRxB1yOUCjXUBX2', NULL, NULL, 'عبدالله مصطفي', NULL, 'abdallhmoustafa295@gmail.com', 'google', 'pending', 1, NULL),
 (3,  'GACuXzpg9RZJSdkJWARghUTbeBp2', 3,    NULL, 'farkha.nims',   NULL, 'farkha.nims@gmail.com',       'google', 'general_manager', 1, NULL),
 -- (admin 4 = nimss.dev@gmail.com removed: deleted from Firebase + DB on request)
 (10, NULL, 3, NULL, 'منى الإدارية (HR)',      '+966500000010', 'hr.test@permedjat.test',         'email', 'hr',             1, NULL),
 (11, NULL, 3, 1,    'طارق مدير الفرع',         '+966500000011', 'bm.test@permedjat.test',         'email', 'branch_manager', 1, NULL),
 (12, NULL, 3, 1,    'حسام مسؤول الحضور',       '+966500000012', 'att.test@permedjat.test',        'email', 'attendance',     1, NULL),
 (13, NULL, 3, NULL, 'سعد المراقب (Viewer)',    '+966500000013', 'viewer.test@permedjat.test',     'email', 'viewer',         1, NULL),
 (14, NULL, 3, NULL, 'حساب معطّل قديم',         '+966500000014', 'old.test@permedjat.test',        'email', 'viewer',         0, NULL),
 -- employee-linked admin accounts (employee app)
 (30, 'employee:1',  3, 1, 'عبدالله القحطاني', '+966500000001', NULL, 'employee_code', 'employee', 1, 'dev-emp-1'),
 (31, 'employee:12', 3, 1, 'عبدالله (تجريبي)', '+201023809407', NULL, 'employee_code', 'employee', 1, 'dev-emp-12'),
 (32, 'employee:3',  3, 1, 'سارة أحمد',        '+966500001003', NULL, 'employee_code', 'employee', 1, 'dev-emp-3');

INSERT INTO admin_notification_prefs (admin_id, tenant_id, prefs) VALUES
 (3,  3, JSON_OBJECT('attendance',true,'payroll',true,'leave',true,'support',true)),
 (10, 3, JSON_OBJECT('attendance',true,'payroll',false,'leave',true,'support',false));

INSERT INTO admin_devices (admin_id, fcm_token, platform, device_id, device_model, app_version, is_active) VALUES
 (3,  'fcm-token-gm-android-0001', 'android', 'dev-gm-and', 'Pixel 8',    '1.0.0', 1),
 (3,  'fcm-token-gm-web-0002',     'web',     'dev-gm-web', 'Chrome',     '1.0.0', 1),
 (10, 'fcm-token-hr-ios-0003',     'ios',     'dev-hr-ios', 'iPhone 15',  '1.0.0', 1),
 (14, 'fcm-token-old-0004',        'android', 'dev-old',    'Galaxy S20', '0.9.0', 0);

-- admin_sessions seed removed — table dropped 2026-06-13 (unused)

INSERT INTO custom_roles (tenant_id, admin_id, branch_id, name, permissions) VALUES
 (3, 13, 1, 'مراقب الفرع', JSON_OBJECT('view_attendance',true,'view_employees',true,'manage_payroll',false));

-- ---------------------------------------------------------------------------
-- 5) CATEGORIES + SHIFTS
-- ---------------------------------------------------------------------------
INSERT INTO employee_categories (id, tenant_id, name, description, color, is_active) VALUES
 (1, 3, 'دوام كامل', 'موظفو الدوام الكامل', '#2563EB', 1),
 (2, 3, 'دوام جزئي', 'موظفو الدوام الجزئي', '#F59E0B', 1);

INSERT INTO shifts (id, tenant_id, branch_id, name, start_time, end_time, color, is_active) VALUES
 (1, 3, NULL, 'صباحي', '08:00:00', '16:00:00', '#22C55E', 1),
 (2, 3, NULL, 'مسائي', '16:00:00', '00:00:00', '#6366F1', 1),
 (3, 3, NULL, 'ليلي',  '00:00:00', '08:00:00', '#0EA5E9', 1),
 (4, 3, 1,    'مرن',   '10:00:00', '18:00:00', '#EC4899', 1),
 (5, 3, NULL, 'حراسة مسائية', '22:00:00', '06:00:00', '#A855F7', 1);

-- ---------------------------------------------------------------------------
-- 6) EMPLOYEES — every status / contract_type / shift_type / biometric state
-- ---------------------------------------------------------------------------
INSERT INTO employees (id, tenant_id, branch_id, admin_id, employee_code, name, phone, job_title,
  department, national_id, nationality, iqama_number, iqama_expiry, passport_number, passport_expiry,
  contract_type, contract_start, contract_end, base_salary, hire_date, work_start_time, work_end_time,
  annual_leave_days, weekly_off_days, auto_terminate_at, terminated_at, shift_id, shift_type, status,
  biometric_enrollment_status, has_linked_account) VALUES
 (1,  3, 1, 30, 'EMP-001', 'عبدالله القحطاني', '+966500000001', 'محاسب',        'المالية',    '1010101010', 'سعودي',  NULL, NULL, NULL, NULL, 'permanent',  @D - INTERVAL 3 YEAR,  NULL,                 5000.00, @D - INTERVAL 3 YEAR,  '08:00:00','16:00:00', NULL, 'friday,saturday', NULL, NULL, 1, 'fixed',    'active',             'both',            1),
 (2,  3, 1, NULL,'EMP-002', 'فوزي العتيبي',     '+966500000002', 'مندوب مبيعات', 'المبيعات',   '1010101011', 'سعودي',  NULL, NULL, NULL, NULL, 'fixed_term', @D - INTERVAL 1 YEAR,  @D + INTERVAL 6 MONTH, 4500.00, @D - INTERVAL 1 YEAR,  '08:00:00','16:00:00', 25,   'friday',          NULL, NULL, 1, 'fixed',    'active',             'face_only',       0),
 (3,  3, 1, 32, 'EMP-003', 'سارة أحمد',        '+966500001003', 'مصممة',        'التسويق',    '2020202020', 'مصري',   '2345678901', @D + INTERVAL 20 DAY, 'A1234567', @D + INTERVAL 2 YEAR, 'part_time',  @D - INTERVAL 8 MONTH, NULL,                 3000.00, @D - INTERVAL 8 MONTH, '10:00:00','14:00:00', NULL, 'friday,saturday', NULL, NULL, 4, 'rotating', 'active',             'fingerprint_only',1),
 (4,  3, 2, NULL,'EMP-004', 'محمد علي',         '+966500000004', 'مدير عمليات',  'العمليات',   '1010101013', 'سعودي',  NULL, NULL, NULL, NULL, 'permanent',  @D - INTERVAL 5 YEAR,  NULL,                 8000.00, @D - INTERVAL 5 YEAR,  '09:00:00','17:00:00', NULL, 'friday,saturday', NULL, NULL, 1, 'fixed',    'active',             'both',            0),
 (5,  3, 1, NULL,'EMP-005', 'خالد محمود',       '+966500000005', 'فني دعم',      'تقنية',      '3030303030', 'يمني',   '3456789012', @D + INTERVAL 90 DAY, NULL, NULL, 'permanent',  @D - INTERVAL 2 YEAR,  NULL,                 5500.00, @D - INTERVAL 2 YEAR,  '08:00:00','16:00:00', NULL, 'friday,saturday', NULL, NULL, 1, 'fixed',    'on_leave',          'not_enrolled',    0),
 (6,  3, 2, NULL,'EMP-006', 'فاطمة حسن',        '+966500000006', 'أخصائية موارد','الموارد',    '1010101015', 'سعودي',  NULL, NULL, NULL, NULL, 'permanent',  @D - INTERVAL 4 YEAR,  NULL,                 7000.00, @D - INTERVAL 4 YEAR,  '09:00:00','17:00:00', NULL, 'friday,saturday', NULL, NULL, 1, 'fixed',    'active',             'face_only',       0),
 (7,  3, 1, NULL,'EMP-007', 'أحمد إبراهيم',     '+966500000007', 'متدرب',        'العمليات',   '1010101016', 'سعودي',  NULL, NULL, NULL, NULL, 'temporary',  @D - INTERVAL 10 DAY,  @D + INTERVAL 80 DAY,  4000.00, @D - INTERVAL 10 DAY,  '08:00:00','16:00:00', NULL, 'friday,saturday', NULL, NULL, NULL,'fixed',    'pending_activation','not_enrolled',    0),
 (8,  3, 2, NULL,'EMP-008', 'نورا سعيد',        '+966500000008', 'مديرة حسابات', 'المالية',    '4040404040', 'سوداني', '4567890123', @D + INTERVAL 1 YEAR, NULL, NULL, 'permanent',  @D - INTERVAL 3 YEAR,  NULL,                 6500.00, @D - INTERVAL 3 YEAR,  '09:00:00','17:00:00', NULL, 'friday,saturday', NULL, NULL, 1, 'fixed',    'suspended',         'both',            0),
 (9,  3, 1, NULL,'EMP-009', 'يوسف الزهراني',    '+966500000009', 'سائق',         'العمليات',   '1010101018', 'سعودي',  NULL, NULL, NULL, NULL, 'fixed_term', @D - INTERVAL 2 YEAR,  @D - INTERVAL 1 MONTH, 4200.00, @D - INTERVAL 2 YEAR,  '08:00:00','16:00:00', NULL, 'friday,saturday', NULL, @D - INTERVAL 1 MONTH, 1,'fixed','terminated',        'not_enrolled',    0),
 (10, 3, 3, NULL,'EMP-010', 'ليلى المهدي',      '+966500000010', 'كاشير',        'المبيعات',   '5050505050', 'مغربي',  '5678901234', @D + INTERVAL 200 DAY, NULL, NULL,'part_time',  @D - INTERVAL 6 MONTH, NULL,                 3200.00, @D - INTERVAL 6 MONTH, '12:00:00','18:00:00', NULL, 'friday',          NULL, NULL, 4, 'rotating', 'active',             'face_only',       0),
 (11, 3, 1, NULL,'EMP-011', 'عمر الشمري',       '+966500000011', 'حارس أمن',     'الأمن',      '1010101020', 'سعودي',  NULL, NULL, NULL, NULL, 'permanent',  @D - INTERVAL 18 MONTH,NULL,                 4800.00, @D - INTERVAL 18 MONTH,'00:00:00','08:00:00', NULL, 'saturday',        NULL, NULL, 3, 'rotating', 'active',             'both',            0),
 (12, 3, 1, 31, 'EMP-012', 'عبدالله (تجريبي)', '+201023809407', 'مدير منتج',    'الإدارة',    '6060606060', 'مصري',   NULL, NULL, 'E9876543', @D + INTERVAL 3 YEAR, 'permanent', @D - INTERVAL 1 YEAR, NULL,           12000.00, @D - INTERVAL 1 YEAR,  '09:00:00','17:00:00', 30,   'friday,saturday', NULL, NULL, 1, 'fixed',    'active',             'both',            1),
 (13, 3, 2, NULL,'EMP-013', 'هند الدوسري',      '+966500000013', 'سكرتيرة',      'الإدارة',    '7070707070', 'سعودي',  NULL, NULL, NULL, NULL, 'permanent',  @D - INTERVAL 7 MONTH, NULL,                 5300.00, @D - INTERVAL 7 MONTH, '09:00:00','17:00:00', NULL, 'friday,saturday', NULL, NULL, 1, 'fixed',    'active',             'not_enrolled',    0),
 (14, 3, 1, NULL,'EMP-014', 'ريم الحربي',       '+966500000014', 'موظفة موسمية', 'المبيعات',   '8080808080', 'سعودي',  NULL, NULL, NULL, NULL, 'temporary',  @D - INTERVAL 20 DAY,  @D + INTERVAL 10 DAY,  3500.00, @D - INTERVAL 20 DAY,  '00:01:00','23:59:00', NULL, 'friday,saturday', @D + INTERVAL 10 DAY, NULL, NULL,'fixed','active',          'not_enrolled',    0),
 -- emp 15: حارس أمن بوردية مسائية (22:00–06:00) => يظهر دائمًا "قبل الوردية" (pre_shift) نهارًا
 (15, 3, 1, NULL,'EMP-015', 'سالم الغامدي',     '+966500000115', 'حارس أمن مسائي','الأمن',      '9090909090', 'سعودي',  NULL, NULL, NULL, NULL, 'permanent',  @D - INTERVAL 1 YEAR,  NULL,                 4600.00, @D - INTERVAL 1 YEAR,  '22:00:00','06:00:00', NULL, 'friday',          NULL, NULL, 5, 'fixed',    'active',             'not_enrolled',    0),
 -- emp 16: وردية تغطي اليوم كله (00:01–23:59) وبدون سجل حضور اليوم =>
 --         يظهر دائمًا "لم يحضر" (not_in) في أي ساعة بالنهار. markAbsentSmart
 --         لا يعلّمه غائبًا لأن ورديته لا تنتهي إلا 23:59، واللوحة الحيّة تشتقّه
 --         not_in وليس pre_shift. هذا ممثّل حالة "لم يحضر" في لوحة اليوم.
 (16, 3, 1, NULL,'EMP-016', 'تركي السبيعي',     '+966500000016', 'موظف استقبال',  'الإدارة',    '1212121212', 'سعودي',  NULL, NULL, NULL, NULL, 'permanent',  @D - INTERVAL 1 YEAR,  NULL,                 4300.00, @D - INTERVAL 1 YEAR,  '00:01:00','23:59:00', NULL, 'friday',          NULL, NULL, NULL,'fixed',    'active',             'not_enrolled',    0);

INSERT INTO employee_category_assignments (tenant_id, employee_id, category_id) VALUES
 (3,1,1),(3,2,1),(3,4,1),(3,5,1),(3,6,1),(3,8,1),(3,11,1),(3,12,1),(3,13,1),
 (3,3,2),(3,10,2),(3,14,2),(3,15,1),(3,16,1);

INSERT INTO employee_allowances (tenant_id, employee_id, type, label, amount, start_month, end_month, created_by) VALUES
 (3, 1,  'housing',       'بدل سكن',     1000.00, @PREV, NULL,  3),
 (3, 1,  'transport',     'بدل نقل',      300.00, @PREV, NULL,  3),
 (3, 4,  'housing',       NULL,          1500.00, @PREV, NULL,  3),
 (3, 4,  'communication', 'بدل اتصالات',  150.00, @PREV, @MON,  3),
 (3, 12, 'food',          'بدل إعاشة',    500.00, @PREV, NULL,  10),
 (3, 12, 'other',         'بدل طبيعة عمل',800.00, @PREV, NULL,  10);

-- ---------------------------------------------------------------------------
-- 7) EMPLOYEE app auth: activation codes / tokens
-- ---------------------------------------------------------------------------
INSERT INTO employee_activation_codes (tenant_id, employee_id, code, token, expires_at, used_at, used_by_firebase_uid) VALUES
 (3, 7,  'ACT7AB', 'tok-act-7-aabbccddeeff0011', NOW() + INTERVAL 7 DAY, NULL, NULL),                 -- unused / pending
 (3, 12, 'ACT12C', 'tok-act-12-112233445566778', NOW() - INTERVAL 1 DAY, NOW() - INTERVAL 2 DAY, 'employee:12'), -- used
 (3, 14, 'ACT14X', 'tok-act-14-99aabbccddeeff0', NOW() - INTERVAL 1 DAY, NULL, NULL);                 -- expired unused

-- activation_codes seed removed — table dropped 2026-06-13 (superseded by employee_activation_codes)

INSERT INTO employee_auth_tokens (tenant_id, employee_id, token_hash, device_id, device_model, platform, app_version, revoked_at, revoke_reason) VALUES
 (3, 1,  SHA2('emp1-token',256),  'dev-emp-1',  'Pixel 6',   'android', '1.0.0', NULL, NULL),
 (3, 12, SHA2('emp12-token',256), 'dev-emp-12', 'iPhone 13', 'ios',     '1.0.0', NULL, NULL),
 (3, 3,  SHA2('emp3-old',256),    'dev-emp-3a', 'Galaxy A50','android', '0.9.0', NOW() - INTERVAL 5 DAY, 'device_change');

-- ---------------------------------------------------------------------------
-- 8) ATTENDANCE — every status / method / late / overtime / offline
-- ---------------------------------------------------------------------------
INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_out_time,
  check_in_latitude, check_in_longitude, worked_minutes, overtime_minutes, late_minutes, early_leave_minutes,
  check_in_method, check_out_method, recognition_method, recognition_confidence, status, is_offline,
  synced_at, recorded_by, deduction_mode, deduction_value, notes) VALUES
 -- present on time (qr_gps)
 (3,1,1,@D - INTERVAL 1 DAY,'08:00:00','16:05:00',24.7136,46.6753,485,5,0,0,'qr_gps','qr_gps','qr_gps',NULL,'present',0,NULL,NULL,'auto',NULL,'حضور منتظم'),
 -- present late
 (3,1,1,@D - INTERVAL 2 DAY,'08:35:00','16:00:00',24.7136,46.6753,445,0,35,0,'qr_gps','qr_gps','qr_gps',NULL,'present',0,NULL,NULL,'auto',NULL,'تأخير 35 دقيقة'),
 -- present early leave
 (3,1,2,@D - INTERVAL 1 DAY,'08:00:00','14:30:00',24.7136,46.6753,390,0,0,90,'qr_gps','manual','qr_gps',NULL,'present',0,NULL,3,'auto',NULL,'انصراف مبكر'),
 -- present with overtime + face station
 (3,1,4,@D - INTERVAL 1 DAY,'08:55:00','19:30:00',NULL,NULL,635,150,0,0,'qr_gps_face','qr_gps_face','station_face',0.972,'present',0,NULL,NULL,'auto',NULL,'عمل إضافي'),
 -- present kiosk
 (3,1,6,@D - INTERVAL 1 DAY,'09:02:00','17:00:00',NULL,NULL,478,0,2,0,'kiosk','kiosk','station_fingerprint',0.910,'present',0,NULL,NULL,'auto',NULL,NULL),
 -- present offline synced
 (3,1,11,@D - INTERVAL 1 DAY,'00:05:00','08:00:00',24.7136,46.6753,475,0,5,0,'offline','offline',NULL,NULL,'present',1,NOW(),NULL,'auto',NULL,'سُجّل دون اتصال'),
 -- present station both + qr station methods
 (3,1,1,@D - INTERVAL 3 DAY,'07:58:00','16:00:00',NULL,NULL,482,0,0,0,'qr_gps_face','auto','station_both',0.880,'present',0,NULL,NULL,'auto',NULL,NULL),
 (3,1,2,@D - INTERVAL 3 DAY,'08:00:00','16:00:00',NULL,NULL,480,0,0,0,'qr_gps','qr_gps','station_qr',NULL,'present',0,NULL,NULL,'auto',NULL,NULL),
 -- absent (auto)
 (3,1,2,@D - INTERVAL 2 DAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,NULL,'absent',0,NULL,NULL,'auto',NULL,'غياب بدون إذن'),
 -- absent with days deduction override
 (3,1,6,@D - INTERVAL 2 DAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,NULL,'absent',0,NULL,3,'days',1.00,'خصم يوم'),
 -- absent with fixed amount deduction
 (3,2,4,@D - INTERVAL 2 DAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,NULL,'absent',0,NULL,3,'amount',250.00,'خصم مبلغ ثابت'),
 -- leave
 (3,1,5,@D - INTERVAL 1 DAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,NULL,'leave',0,NULL,NULL,'auto',NULL,'إجازة معتمدة'),
 -- holiday
 (3,1,1,@D - INTERVAL 5 DAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,NULL,'holiday',0,NULL,NULL,'auto',NULL,'يوم وطني'),
 (3,1,2,@D - INTERVAL 5 DAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,NULL,'holiday',0,NULL,NULL,'auto',NULL,NULL),
 -- weekly_off
 (3,1,1,@D - INTERVAL 4 DAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,NULL,'weekly_off',0,NULL,NULL,'auto',NULL,NULL),
 -- manual recorded present
 (3,2,13,@D - INTERVAL 1 DAY,'09:00:00','17:00:00',21.5433,39.1728,480,0,0,0,'manual','manual','manual',NULL,'present',0,NULL,3,'auto',NULL,'إدخال يدوي');

-- 8b) TODAY's live board (Asia/Riyadh date) — so the dashboard counters are non-zero:
--     حاضرون (in) / انصراف (out) / متأخرون (late) / في إجازة (leave) / غائبون (absent) / لم يحضر
SET @TODAY := DATE(CONVERT_TZ(UTC_TIMESTAMP(), '+00:00', '+03:00'));
DELETE FROM attendance WHERE tenant_id = 3 AND date = @TODAY;
INSERT INTO attendance (tenant_id, branch_id, employee_id, date, check_in_time, check_out_time,
  check_in_latitude, check_in_longitude, worked_minutes, overtime_minutes, late_minutes, early_leave_minutes,
  check_in_method, check_out_method, recognition_method, status, is_offline, recorded_by, deduction_mode, notes) VALUES
 (3,1,1, @TODAY,'08:00:00',NULL,24.7136,46.6753,0,0,0,0,'qr_gps',NULL,'qr_gps','present',0,NULL,'auto','حاضر الآن'),
 (3,1,12,@TODAY,'08:58:00',NULL,24.7136,46.6753,0,0,0,0,'qr_gps_face',NULL,'station_face','present',0,NULL,'auto','حاضر الآن'),
 (3,1,2, @TODAY,'08:42:00',NULL,24.7136,46.6753,0,0,42,0,'qr_gps',NULL,'qr_gps','present',0,NULL,'auto','تأخير 42 دقيقة'),
 (3,2,4, @TODAY,'08:00:00','16:10:00',21.5433,39.1728,490,10,0,0,'qr_gps','qr_gps','qr_gps','present',0,NULL,'auto','انصرف'),
 (3,2,6, @TODAY,'09:20:00','17:05:00',21.5433,39.1728,465,0,80,0,'kiosk','kiosk','station_fingerprint','present',0,NULL,'auto','انصرف متأخر الحضور'),
 (3,2,13,@TODAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,'leave',0,NULL,'auto','إجازة سنوية'),
 (3,3,10,@TODAY,NULL,NULL,NULL,NULL,0,0,0,0,'qr_gps',NULL,NULL,'absent',0,NULL,'auto','غياب اليوم');
INSERT INTO leaves (tenant_id, employee_id, date, start_date, end_date, type, reason, status, approved_by, approved_at)
VALUES (3, 13, @TODAY, @TODAY, @TODAY, 'annual', 'إجازة اليوم', 'approved', 3, NOW());

-- ---------------------------------------------------------------------------
-- 9) LEAVES — every type + status + balances + recurring + holidays
-- ---------------------------------------------------------------------------
INSERT INTO leaves (tenant_id, employee_id, date, start_date, end_date, type, reason, status, approved_by, approved_at, rejected_by, rejection_reason) VALUES
 (3, 5,  @D - INTERVAL 1 DAY, @D - INTERVAL 1 DAY, @D + INTERVAL 3 DAY, 'annual',   'إجازة سنوية',        'approved', 3, NOW() - INTERVAL 2 DAY, NULL, NULL),
 (3, 6,  @D + INTERVAL 2 DAY, @D + INTERVAL 2 DAY, @D + INTERVAL 2 DAY, 'sick',     'إجازة مرضية',        'pending',  NULL, NULL, NULL, NULL),
 (3, 4,  @D - INTERVAL 10 DAY,@D - INTERVAL 10 DAY,@D - INTERVAL 9 DAY, 'personal', 'ظرف شخصي',           'approved', 3, NOW() - INTERVAL 11 DAY, NULL, NULL),
 (3, 2,  @D + INTERVAL 5 DAY, @D + INTERVAL 5 DAY, @D + INTERVAL 7 DAY, 'unpaid',   'إجازة بدون راتب',    'rejected', NULL, NULL, 3, 'ضغط العمل'),
 (3, 11, @D - INTERVAL 4 DAY, @D - INTERVAL 4 DAY, @D - INTERVAL 4 DAY, 'weekly_off','راحة أسبوعية',       'approved', 3, NOW() - INTERVAL 4 DAY, NULL, NULL),
 (3, 2,  @D - INTERVAL 2 DAY, @D - INTERVAL 2 DAY, @D - INTERVAL 2 DAY, 'converted_from_absence', 'تحويل غياب إلى إجازة', 'approved', 10, NOW() - INTERVAL 1 DAY, NULL, NULL),
 (3, 13, @D + INTERVAL 1 DAY, @D + INTERVAL 1 DAY, @D + INTERVAL 1 DAY, 'sick',     'موعد طبي',            'pending',  NULL, NULL, NULL, NULL);

INSERT INTO leave_year_balances (tenant_id, employee_id, year, entitlement_days, carried_over_days) VALUES
 (3, 1, @YR, 21, 5),
 (3, 2, @YR, 25, 0),
 (3, 4, @YR, 21, 3),
 (3, 12,@YR, 30, 8);

INSERT INTO recurring_leaves (tenant_id, branch_id, day_of_week, type, reason, is_active) VALUES
 (3, NULL, 'friday',   'weekly_off', 'عطلة نهاية الأسبوع', 1),
 (3, 1,    'saturday', 'weekly_off', 'راحة فرع الرياض',     1),
 (3, 3,    'sunday',   'weekly_off', 'فرع مغلق',            0);

INSERT INTO holidays (tenant_id, branch_id, name, date, notes, created_by) VALUES
 (3, NULL, 'اليوم الوطني',        @D - INTERVAL 5 DAY, 'إجازة رسمية مدفوعة', 3),
 (3, NULL, 'يوم التأسيس',         @D + INTERVAL 30 DAY, NULL, 3),
 (3, 1,    'مناسبة خاصة بالفرع',  @D + INTERVAL 15 DAY, 'غير مدفوعة', 3);

-- ---------------------------------------------------------------------------
-- 10) BREAK / PERMISSION REQUESTS — every type + status
-- ---------------------------------------------------------------------------
INSERT INTO break_requests (tenant_id, employee_id, date, start_time, end_time, duration_minutes, type,
  deduct_from_salary, reason, status, decided_by, decided_at, decision_note, suggested_date, suggested_start_time, suggested_end_time) VALUES
 (3, 1,  @D, '12:00:00','12:30:00', 30, 'break',      0, 'استراحة غداء',   'pending',   NULL, NULL, NULL, NULL, NULL, NULL),
 (3, 1,  @D - INTERVAL 1 DAY, '13:00:00','13:20:00', 20, 'prayer',     0, 'صلاة الظهر',  'approved',  11, NOW() - INTERVAL 1 DAY, 'موافق', NULL, NULL, NULL),
 (3, 2,  @D, '10:00:00','11:00:00', 60, 'permission', 0, 'مراجعة جهة حكومية', 'rejected', 11, NOW(), 'ضغط العمل', NULL, NULL, NULL),
 (3, 4,  @D, '15:00:00','17:00:00', 120,'early_leave',1, 'انصراف مبكر',  'approved',  3,  NOW(), 'يُخصم بالساعة', NULL, NULL, NULL),
 (3, 6,  @D, '11:30:00','12:30:00', 60, 'errand',     0, 'مهمة خارجية',   'postponed', 11, NOW(), 'أجّلها ليوم آخر', @D + INTERVAL 2 DAY, '11:30:00','12:30:00'),
 (3, 13, @D, '09:30:00','10:30:00', 60, 'medical',    0, 'مراجعة طبية',   'cancelled', NULL, NULL, 'ألغاه الموظف', NULL, NULL, NULL),
 (3, 11, @D, '02:00:00','02:15:00', 15, 'other',      0, 'استراحة قصيرة', 'pending',   NULL, NULL, NULL, NULL, NULL, NULL);

-- ---------------------------------------------------------------------------
-- 11) PAYROLL — draft / approved / paid + bonuses/deductions/rules/settings
-- ---------------------------------------------------------------------------
INSERT INTO payroll (tenant_id, employee_id, branch_id, month, base_salary, total_deductions, total_bonuses,
  net_salary, working_days, present_days, absent_days, overtime_total_minutes,
  breakdown, status, approved_by, approved_at, paid_at) VALUES
 (3, 1, 1, @PREV, 5000.00, 200.00, 1300.00, 6100.00, 26, 24, 1, 150, JSON_OBJECT('allowances',1300,'absence',200), 'paid',     3, NOW() - INTERVAL 20 DAY, NOW() - INTERVAL 18 DAY),
 (3, 2, 1, @PREV, 4500.00, 250.00, 0.00,    4250.00, 26, 23, 2, 0,   JSON_OBJECT('absence',250), 'paid',     3, NOW() - INTERVAL 20 DAY, NOW() - INTERVAL 18 DAY),
 (3, 4, 2, @PREV, 8000.00, 0.00,   1650.00, 9650.00, 26, 26, 0, 300, JSON_OBJECT('allowances',1650), 'approved', 3, NOW() - INTERVAL 2 DAY,  NULL),
 (3, 1, 1, @MON,  5000.00, 0.00,   1300.00, 6300.00, 26, 20, 0, 150, JSON_OBJECT('allowances',1300), 'draft',    NULL, NULL, NULL),
 (3, 6, 2, @MON,  7000.00, 230.00, 0.00,    6770.00, 26, 19, 1, 0,   JSON_OBJECT('absence',230), 'draft',    NULL, NULL, NULL),
 (3, 12,1, @MON, 12000.00, 0.00,   1300.00,13300.00, 26, 21, 0, 0,   JSON_OBJECT('allowances',1300), 'draft',    NULL, NULL, NULL);

INSERT INTO manual_bonuses (tenant_id, employee_id, amount, reason, month, created_by) VALUES
 (3, 1,  500.00, 'مكافأة أداء',   @MON, 3),
 (3, 4,  800.00, 'مكافأة مشروع',  @PREV, 3);

INSERT INTO manual_deductions (tenant_id, employee_id, amount, reason, month, created_by) VALUES
 (3, 2,  150.00, 'خصم تأخيرات',  @MON, 3),
 (3, 6,  100.00, 'خصم سلفة نقدية',@PREV, 10);

INSERT INTO bonus_rules (tenant_id, rule_key, rule_type, rule_value, description, is_active) VALUES
 (3, 'overtime_rate',      'numeric', '1.5',  'معامل ساعات العمل الإضافي', 1),
 (3, 'attendance_bonus',   'numeric', '200',  'مكافأة الحضور الكامل',      1),
 (3, 'ramadan_bonus',      'boolean', '1',    'تفعيل مكافأة رمضان',        0);

INSERT INTO deduction_rules (tenant_id, rule_key, rule_type, rule_value, description, is_active) VALUES
 (3, 'late_per_minute',    'numeric', '2',    'خصم لكل دقيقة تأخير', 1),
 (3, 'absence_per_day',    'numeric', '1',    'خصم أيام الغياب',     1),
 (3, 'grace_minutes',      'numeric', '10',   'سماح التأخير',         1);

INSERT INTO payroll_statutory_settings (tenant_id, social_insurance_enabled, si_employee_rate,
  si_min_wage, si_max_wage, income_tax_enabled, income_tax_brackets, tax_personal_exemption, eosb_enabled, eosb_days_per_year)
VALUES (3, 1, 9.75, 1500.00, 45000.00, 0, JSON_ARRAY(JSON_OBJECT('up_to',60000,'rate',0)), 0.00, 1, 21.00);

INSERT INTO payroll_line_overrides (tenant_id, employee_id, month, line_kind, line_type, line_date, line_desc, line_hash, waived, override_amount, reason, created_by) VALUES
 (3, 2, @MON, 'deduction', 'late', NULL, 'خصم تأخير', SHA1('late|null|late-desc'), 1, NULL, 'إعفاء استثنائي', 3),
 (3, 1, @MON, 'bonus', 'attendance', NULL, 'مكافأة حضور', SHA1('attendance|null|att-desc'), 0, 250.00, 'تعديل المبلغ', 3);

-- ---------------------------------------------------------------------------
-- 12) LOANS / ADVANCES + installments
-- ---------------------------------------------------------------------------
INSERT INTO employee_loans (id, tenant_id, employee_id, type, total_amount, installment_amount,
  installments_count, installments_paid, start_month, reason, status, created_by, approved_by, approved_at) VALUES
 (1, 3, 1,  'loan',    6000.00, 1000.00, 6, 2, @PREV, 'قرض شخصي',   'active',    3, 3, NOW() - INTERVAL 40 DAY),
 (2, 3, 4,  'advance', 2000.00, 2000.00, 1, 0, @MON,  'سلفة طارئة',  'pending',   3, NULL, NULL),
 (3, 3, 6,  'loan',    3000.00, 1000.00, 3, 3, DATE_FORMAT(@D - INTERVAL 4 MONTH,'%Y-%m'), 'قرض مكتمل', 'completed', 3, 3, NOW() - INTERVAL 120 DAY),
 (4, 3, 2,  'advance', 1500.00, 1500.00, 1, 0, @MON,  'سلفة مرفوضة',  'cancelled', 3, NULL, NULL);

INSERT INTO loan_installments (tenant_id, loan_id, employee_id, month, seq, amount, status, paid_at) VALUES
 (3, 1, 1, @PREV, 1, 1000.00, 'paid',    NOW() - INTERVAL 25 DAY),
 (3, 1, 1, DATE_FORMAT(@D - INTERVAL 2 MONTH,'%Y-%m'), 2, 1000.00, 'paid', NOW() - INTERVAL 55 DAY),
 (3, 1, 1, @MON, 3, 1000.00, 'pending', NULL),
 (3, 3, 6, DATE_FORMAT(@D - INTERVAL 4 MONTH,'%Y-%m'), 1, 1000.00, 'paid', NOW() - INTERVAL 110 DAY),
 (3, 3, 6, DATE_FORMAT(@D - INTERVAL 3 MONTH,'%Y-%m'), 2, 1000.00, 'paid', NOW() - INTERVAL 80 DAY),
 (3, 3, 6, DATE_FORMAT(@D - INTERVAL 2 MONTH,'%Y-%m'), 3, 1000.00, 'paid', NOW() - INTERVAL 50 DAY);

-- ---------------------------------------------------------------------------
-- 14) ASSET CUSTODY — every type + status
-- ---------------------------------------------------------------------------
INSERT INTO asset_custody (tenant_id, employee_id, type, name, description, value, currency, serial_no,
  quantity, status, notes, assigned_at, assigned_by, return_requested_at, returned_at, return_approved_by, return_note) VALUES
 (3, 1,  'device',    'لابتوب Dell',    'جهاز عمل', 4500.00, 'SAR', 'DLL-001', 1, 'assigned',         NULL, @D - INTERVAL 60 DAY, 3, NULL, NULL, NULL, NULL),
 (3, 4,  'vehicle',   'سيارة هايلكس',   'سيارة شركة', 90000.00, 'SAR', 'PLT-4521', 1, 'assigned',     'للاستخدام الميداني', @D - INTERVAL 200 DAY, 3, NULL, NULL, NULL, NULL),
 (3, 6,  'equipment', 'طابعة',          NULL, 1200.00, 'SAR', 'PRN-77', 1, 'return_requested', NULL, @D - INTERVAL 100 DAY, 3, NOW() - INTERVAL 1 DAY, NULL, NULL, NULL),
 (3, 9,  'money',     'عهدة نقدية',     'صندوق نثرية', 1000.00, 'SAR', NULL, 1, 'returned',         NULL, @D - INTERVAL 300 DAY, 3, NOW() - INTERVAL 40 DAY, NOW() - INTERVAL 38 DAY, 3, 'تم الإرجاع كاملاً'),
 (3, 12, 'document',  'بطاقة دخول',     'تصريح أمني', NULL, 'SAR', 'CARD-12', 1, 'assigned',        NULL, @D - INTERVAL 30 DAY, 3, NULL, NULL, NULL, NULL),
 (3, 11, 'other',     'زي رسمي',        'بدلتان', 300.00, 'SAR', NULL, 2, 'assigned',                NULL, @D - INTERVAL 90 DAY, 3, NULL, NULL, NULL, NULL);

-- ---------------------------------------------------------------------------
-- 15) WARNINGS / SUSPENSIONS / SETTLEMENTS
-- ---------------------------------------------------------------------------
INSERT INTO warnings (tenant_id, employee_id, type, reason, issued_by) VALUES
 (3, 2,  'verbal',        'تأخر متكرر',              3),
 (3, 2,  'written',       'غياب بدون إذن',           3),
 (3, 9,  'final',         'إنذار نهائي قبل الإنهاء', 3),
 (3, 12, 'device_change', 'تغيير جهاز الدخول',       NULL),
 (3, 5,  'system',        'إنذار تلقائي من النظام',  NULL);

INSERT INTO employee_suspensions (tenant_id, employee_id, reason, pay_mode, pay_percentage, start_date,
  end_date, status, previous_status, ended_at, ended_by, end_note, created_by) VALUES
 (3, 8,  'تحقيق إداري',        'partial', 50.00, @D - INTERVAL 5 DAY, @D + INTERVAL 10 DAY, 'active', 'active', NULL, NULL, NULL, 3),
 (3, 5,  'مخالفة سلامة',       'unpaid',  NULL,  @D - INTERVAL 60 DAY, @D - INTERVAL 50 DAY,'ended', 'active', NOW() - INTERVAL 50 DAY, 3, 'انتهى التوقيف', 3),
 (3, 11, 'إيقاف مؤقت مدفوع',   'full',    100.00,@D - INTERVAL 90 DAY, @D - INTERVAL 85 DAY,'ended', 'active', NOW() - INTERVAL 85 DAY, 3, NULL, 3);

INSERT INTO employee_settlements (tenant_id, employee_id, reason, notes, last_working_day, hire_date,
  base_salary, daily_rate, years_of_service, pending_salary, gratuity_days, gratuity_amount,
  leave_balance_days, leave_encashment, other_additions, outstanding_loans, other_deductions,
  total_earnings, total_deductions, net_amount, line_items, breakdown, status, created_by, approved_by, approved_at, paid_at) VALUES
 (3, 9, 'end_of_contract', 'انتهاء عقد محدد المدة', @D - INTERVAL 1 MONTH, @D - INTERVAL 2 YEAR,
   4200.00, 140.00, 2.00, 4200.00, 42.00, 5880.00, 5.00, 700.00, 0.00, 0.00, 0.00,
   10780.00, 0.00, 10780.00,
   JSON_ARRAY(JSON_OBJECT('label','مكافأة نهاية الخدمة','kind','addition','amount',5880)),
   JSON_OBJECT('gratuity',5880,'leave',700), 'approved', 3, 3, NOW() - INTERVAL 20 DAY, NULL);

-- ---------------------------------------------------------------------------
-- 16) DOCUMENTS — required (all scopes), employee docs (all statuses), templates, requests
-- ---------------------------------------------------------------------------
INSERT INTO required_documents (id, tenant_id, name, description, expiry_days, is_required, is_active,
  notification_days_before, category, sort_order, scope_type, scope_branch_id) VALUES
 (1, 3, 'الهوية الوطنية / الإقامة', 'صورة سارية', 365, 1, 1, 30, 'identity',    1, 'all',       NULL),
 (2, 3, 'عقد العمل',               'عقد موقّع',   NULL, 1, 1, 30, 'contract',    2, 'all',       NULL),
 (3, 3, 'شهادة صحية',              'لفرع جدة',    180,  1, 1, 15, 'insurance',   3, 'branch',    2),
 (4, 3, 'رخصة قيادة',              'للسائقين',    730,  0, 1, 30, 'certificate', 4, 'employees', NULL),
 (5, 3, 'شهادة خبرة',              'لدوام كامل',  NULL, 0, 1, 30, 'general',     5, 'category',  NULL);

INSERT INTO required_document_employees (required_document_id, employee_id, tenant_id) VALUES
 (4, 9, 3), (4, 11, 3);

INSERT INTO required_document_categories (tenant_id, required_document_id, category_id) VALUES
 (3, 5, 1);

INSERT INTO employee_documents (tenant_id, employee_id, required_document_id, file_path, original_name,
  file_size, mime_type, status, expires_at, uploaded_by, notes, rejected_reason, verified_at, verified_by) VALUES
 (3, 1,  1, '/uploads/docs/emp1_id.pdf',       'id.pdf',       102400, 'application/pdf', 'uploaded', @D + INTERVAL 200 DAY, 3, 'سارية', NULL, NOW() - INTERVAL 5 DAY, 3),
 (3, 1,  2, '/uploads/docs/emp1_contract.pdf', 'contract.pdf', 204800, 'application/pdf', 'uploaded', NULL, 3, NULL, NULL, NULL, NULL),
 (3, 3,  1, '/uploads/docs/emp3_id.pdf',       'iqama.pdf',    98000,  'application/pdf', 'expired',  @D - INTERVAL 10 DAY, 3, 'منتهية', NULL, NULL, NULL),
 (3, 9,  4, '/uploads/docs/emp9_license.pdf',  'license.pdf',  150000, 'application/pdf', 'rejected', @D + INTERVAL 365 DAY, 3, NULL, 'صورة غير واضحة', NULL, NULL),
 (3, 6,  3, '/uploads/docs/emp6_health.pdf',   'health.pdf',   120000, 'application/pdf', 'required', NULL, NULL, 'مطلوب رفعها', NULL, NULL, NULL);


-- ---------------------------------------------------------------------------
-- 17) SCHEDULING — schedule cells, open shifts/claims, swaps, availability
-- ---------------------------------------------------------------------------
INSERT INTO employee_shift_schedule (tenant_id, employee_id, shift_id, work_date, status, created_by) VALUES
 (3, 3,  4, @D,                  'published', 3),
 (3, 3,  1, @D + INTERVAL 1 DAY, 'published', 3),
 (3, 3,  NULL, @D + INTERVAL 2 DAY, 'published', 3),   -- rest day
 (3, 10, 4, @D,                  'published', 3),
 (3, 11, 3, @D,                  'published', 3),
 (3, 11, 3, @D + INTERVAL 1 DAY, 'draft',     3),       -- draft cell
 (3, 10, 2, @D + INTERVAL 1 DAY, 'draft',     3);

INSERT INTO open_shifts (id, tenant_id, branch_id, shift_id, work_date, slots, slots_filled, status, notes, created_by) VALUES
 (1, 3, 1,    2, @D + INTERVAL 3 DAY, 2, 0, 'open',      'مطلوب تغطية مسائية', 3),
 (2, 3, 1,    1, @D + INTERVAL 2 DAY, 1, 1, 'filled',    NULL, 3),
 (3, 3, NULL, 3, @D + INTERVAL 5 DAY, 1, 0, 'cancelled', 'أُلغيت', 3);

INSERT INTO open_shift_claims (tenant_id, open_shift_id, employee_id, status, decided_by, decided_at) VALUES
 (3, 1, 3,  'pending',   NULL, NULL),
 (3, 2, 11, 'approved',  3, NOW() - INTERVAL 1 DAY),
 (3, 1, 10, 'rejected',  3, NOW()),
 (3, 3, 11, 'withdrawn', NULL, NULL);

INSERT INTO shift_swap_requests (tenant_id, requester_employee_id, requester_date, target_employee_id,
  target_date, status, requester_note, target_responded_at, decided_by, decided_at, decision_note) VALUES
 (3, 3,  @D + INTERVAL 1 DAY, 10, @D + INTERVAL 2 DAY, 'pending_target',  'أحتاج تبديل', NULL, NULL, NULL, NULL),
 (3, 10, @D + INTERVAL 1 DAY, 11, @D + INTERVAL 1 DAY, 'pending_manager', 'وافق الزميل', NOW() - INTERVAL 2 HOUR, NULL, NULL, NULL),
 (3, 11, @D - INTERVAL 2 DAY, 3,  @D - INTERVAL 1 DAY, 'approved',        NULL, NOW() - INTERVAL 3 DAY, 3, NOW() - INTERVAL 2 DAY, 'تمت الموافقة'),
 (3, 3,  @D - INTERVAL 5 DAY, 11, @D - INTERVAL 4 DAY, 'rejected',        NULL, NOW() - INTERVAL 6 DAY, 3, NOW() - INTERVAL 5 DAY, 'غير ممكن'),
 (3, 10, @D - INTERVAL 7 DAY, 3,  @D - INTERVAL 6 DAY, 'cancelled',       'ألغيت', NULL, NULL, NULL, NULL);

INSERT INTO employee_availability (tenant_id, employee_id, kind, day_of_week, specific_date, availability, start_time, end_time, note) VALUES
 (3, 3,  'weekly', 1, NULL, 'available',   '09:00:00','17:00:00', NULL),
 (3, 3,  'weekly', 5, NULL, 'unavailable', NULL, NULL, 'دراسة'),
 (3, 10, 'weekly', 2, NULL, 'preferred',   '12:00:00','18:00:00', 'يفضّل المساء'),
 (3, 11, 'date',   NULL, @D + INTERVAL 3 DAY, 'unavailable', NULL, NULL, 'ظرف خاص');

-- ---------------------------------------------------------------------------
-- 19) RECRUITMENT — job openings + candidates (all stages) + onboarding
-- ---------------------------------------------------------------------------
INSERT INTO job_openings (id, tenant_id, branch_id, title, department, description, employment_type,
  openings_count, status, created_by, closed_at) VALUES
 (1, 3, 1,    'محاسب أول',      'المالية',  'خبرة 3 سنوات',  'full_time', 2, 'open',    3, NULL),
 (2, 3, 2,    'مندوب مبيعات',   'المبيعات', NULL,            'part_time', 1, 'on_hold', 3, NULL),
 (3, 3, NULL, 'سائق توصيل',     'العمليات', 'رخصة سارية',    'contract',  3, 'closed',  3, NOW() - INTERVAL 5 DAY),
 (4, 3, 1,    'مصمم جرافيك',    'التسويق',  NULL,            'temporary', 1, 'open',    3, NULL);

INSERT INTO candidates (tenant_id, job_opening_id, name, email, phone, cv_url, source, stage,
  expected_salary, notes, rejection_reason, converted_employee_id, created_by) VALUES
 (3, 1, 'ماجد الفهد',    'majed@example.com',  '+966551111111', '/uploads/cv/1.pdf', 'referral', 'applied',   6000.00, NULL, NULL, NULL, 3),
 (3, 1, 'سلمى ناصر',     'salma@example.com',  '+966551111112', '/uploads/cv/2.pdf', 'agency',   'screening', 6500.00, 'مرشحة قوية', NULL, NULL, 3),
 (3, 2, 'فهد العنزي',    'fahad@example.com',  '+966551111113', NULL,                'walk_in',  'interview', 4000.00, NULL, NULL, NULL, 10),
 (3, 1, 'دانة السبيعي',  'dana@example.com',   '+966551111114', '/uploads/cv/4.pdf', 'manual',   'offer',     7000.00, 'تم تقديم عرض', NULL, NULL, 3),
 (3, 3, 'تركي القرني',   'turki@example.com',  '+966551111115', NULL,                'referral', 'hired',     4200.00, NULL, NULL, 9, 3),
 (3, 2, 'بدر الشهري',    'badr@example.com',   '+966551111116', NULL,                'agency',   'rejected',  5000.00, NULL, 'خبرة غير كافية', NULL, 3);

INSERT INTO onboarding_templates (id, tenant_id, title, title_ar, task_type, description, sort_order, is_active) VALUES
 (1, 3, 'Sign contract',   'توقيع العقد',        'document', 'توقيع عقد العمل',     1, 1),
 (2, 3, 'Issue laptop',    'تسليم جهاز',         'asset',    'تجهيز جهاز العمل',    2, 1),
 (3, 3, 'Create email',    'إنشاء بريد',         'account',  'إنشاء حساب بريد',     3, 1),
 (4, 3, 'Orientation',     'جلسة تعريفية',       'generic',  'جولة تعريفية',        4, 1);

INSERT INTO onboarding_tasks (tenant_id, employee_id, template_id, title, task_type, status, sort_order, completed_by, completed_at) VALUES
 (3, 7,  1, 'توقيع العقد',   'document', 'completed', 1, 3, NOW() - INTERVAL 1 DAY),
 (3, 7,  2, 'تسليم جهاز',    'asset',    'pending',   2, NULL, NULL),
 (3, 7,  3, 'إنشاء بريد',    'account',  'pending',   3, NULL, NULL),
 (3, 7,  4, 'جلسة تعريفية',  'generic',  'skipped',   4, 3, NOW()),
 (3, 14, NULL, 'مهمة يدوية إضافية', 'generic', 'pending', 5, NULL, NULL);

-- ---------------------------------------------------------------------------
-- 20) PERFORMANCE — cycles / goals / reviews
-- ---------------------------------------------------------------------------
INSERT INTO performance_cycles (id, tenant_id, name, name_ar, period_type, start_date, end_date, status, created_by, closed_at) VALUES
 (1, 3, 'Q-current', 'الربع الحالي',  'quarterly', @D - INTERVAL 1 MONTH, @D + INTERVAL 2 MONTH, 'active', 3, NULL),
 (2, 3, 'Annual',    'التقييم السنوي','annual',    @D - INTERVAL 11 MONTH,@D + INTERVAL 1 MONTH, 'draft',  3, NULL),
 (3, 3, 'Q-prev',    'الربع السابق',  'quarterly', @D - INTERVAL 4 MONTH, @D - INTERVAL 1 MONTH, 'closed', 3, NOW() - INTERVAL 30 DAY);

INSERT INTO performance_goals (tenant_id, employee_id, cycle_id, title, description, metric, target_value,
  current_value, weight, progress, status, due_date, created_by) VALUES
 (3, 1,  1, 'إغلاق الحسابات الشهرية', 'في الموعد', 'أيام', 5.00, 5.00, 30, 100, 'completed',   @D - INTERVAL 5 DAY, 3),
 (3, 1,  1, 'تقليل الأخطاء المحاسبية', NULL, 'نسبة', 2.00, 1.50, 40, 60, 'in_progress', @D + INTERVAL 20 DAY, 3),
 (3, 4,  1, 'رفع رضا العملاء',        NULL, 'نقاط', 90.00, 0.00, 50, 0,  'not_started', @D + INTERVAL 40 DAY, 3),
 (3, 12, 1, 'إطلاق ميزة جديدة',       'منتج', 'عدد', 3.00, 1.00, 50, 33, 'in_progress', @D + INTERVAL 30 DAY, 3),
 (3, 6,  3, 'هدف ملغى',               NULL, NULL, NULL, 0.00, 10, 0, 'cancelled',   @D - INTERVAL 10 DAY, 3);

INSERT INTO performance_reviews (tenant_id, employee_id, cycle_id, reviewer_id, reviewer_type, rating,
  strengths, areas_for_improvement, review, status) VALUES
 (3, 1,  3, 3,  'manager',     4.50, 'دقيق ومنظم', 'تفويض المهام', 'أداء ممتاز', 'submitted'),
 (3, 1,  3, 30, 'self',        4.00, 'ملتزم', 'إدارة الوقت', 'تقييم ذاتي', 'submitted'),
 (3, 4,  3, 3,  'manager',     3.75, 'قيادي', 'المتابعة',   'جيد جداً', 'submitted'),
 (3, 12, 1, 3,  'manager',     NULL, NULL, NULL, 'مسودة قيد الإعداد', 'draft'),
 (3, 6,  3, 11, 'peer',        4.20, 'متعاونة', NULL, 'تقييم زميل', 'submitted');

-- ---------------------------------------------------------------------------
-- 21) SURVEYS — types/statuses + questions (all qtypes) + responses/answers
-- ---------------------------------------------------------------------------
INSERT INTO surveys (id, tenant_id, title, title_ar, description, type, is_anonymous, audience_type,
  audience_id, status, start_date, end_date, created_by, closed_at) VALUES
 (1, 3, 'eNPS Q', 'مؤشر الولاء الوظيفي', 'قياس eNPS', 'enps', 1, 'all', NULL, 'active', @D - INTERVAL 5 DAY, @D + INTERVAL 10 DAY, 3, NULL),
 (2, 3, 'Pulse',  'نبض الموظفين',         NULL,        'pulse',0, 'branch', 1, 'draft', NULL, NULL, 3, NULL),
 (3, 3, 'Custom', 'استبيان مخصص',         'منوع',      'custom',1,'category', 1, 'closed', @D - INTERVAL 40 DAY, @D - INTERVAL 10 DAY, 3, NOW() - INTERVAL 10 DAY);

INSERT INTO survey_questions (id, survey_id, tenant_id, question, question_ar, qtype, options, is_required, sort_order) VALUES
 (1, 1, 3, 'How likely to recommend?', 'ما مدى ترشيحك للعمل هنا؟', 'enps',  NULL, 1, 1),
 (2, 3, 3, 'Rate your manager',        'قيّم مديرك',               'rating',NULL, 1, 1),
 (3, 3, 3, 'Workload scale',           'مقياس عبء العمل',          'scale', NULL, 1, 2),
 (4, 3, 3, 'Any comments?',            'أي ملاحظات؟',              'text',  NULL, 0, 3),
 (5, 3, 3, 'Preferred shift',          'الوردية المفضلة',          'single_choice', JSON_ARRAY('صباحي','مسائي','ليلي'), 1, 4),
 (6, 3, 3, 'Perks you value',          'المزايا المهمة',           'multi_choice',  JSON_ARRAY('تأمين','بدل نقل','مرونة','تدريب'), 0, 5);

INSERT INTO survey_responses (id, survey_id, tenant_id, employee_id) VALUES
 (1, 1, 3, NULL),   -- anonymous
 (2, 3, 3, 1),
 (3, 3, 3, 4);

INSERT INTO survey_answers (response_id, question_id, tenant_id, answer_value, answer_text) VALUES
 (1, 1, 3, 9,    NULL),
 (2, 2, 3, 5,    NULL),
 (2, 3, 3, 3,    NULL),
 (2, 4, 3, NULL, 'بيئة عمل جيدة'),
 (2, 5, 3, NULL, 'صباحي'),
 (2, 6, 3, NULL, JSON_ARRAY('تأمين','مرونة')),
 (3, 2, 3, 4,    NULL),
 (3, 4, 3, NULL, 'تحسين التواصل');

INSERT INTO survey_completions (survey_id, tenant_id, employee_id, completed_at) VALUES
 (3, 3, 1, NOW() - INTERVAL 15 DAY),
 (3, 3, 4, NOW() - INTERVAL 14 DAY);

-- ---------------------------------------------------------------------------
-- 22) ENGAGEMENT — announcements / reads / kudos / notifications
-- ---------------------------------------------------------------------------
INSERT INTO announcements (id, tenant_id, title, title_ar, body, body_ar, category, audience_type,
  audience_id, is_pinned, status, published_at, created_by) VALUES
 (1, 3, 'Welcome', 'مرحباً بالجميع', 'Welcome body', 'يسعدنا انضمامكم', 'general',     'all',      NULL, 1, 'published', NOW() - INTERVAL 3 DAY, 3),
 (2, 3, 'Policy',  'تحديث سياسة',    'Policy body',  'تم تحديث سياسة الإجازات', 'policy', 'branch',   1,    0, 'published', NOW() - INTERVAL 2 DAY, 3),
 (3, 3, 'Event',   'حفل سنوي',       'Event body',   'دعوة للحفل السنوي', 'event',       'category', 1,    0, 'draft',     NULL, 3),
 (4, 3, 'Eid',     'تهنئة العيد',    'Eid body',     'كل عام وأنتم بخير', 'celebration', 'all',      NULL, 0, 'archived',  NOW() - INTERVAL 40 DAY, 3),
 (5, 3, 'Urgent',  'تنبيه عاجل',     'Urgent body',  'صيانة النظام الليلة', 'urgent',     'employee', 12,   1, 'published', NOW() - INTERVAL 1 HOUR, 3);

INSERT INTO announcement_reads (announcement_id, tenant_id, employee_id, read_at) VALUES
 (1, 3, 1,  NOW() - INTERVAL 2 DAY),
 (1, 3, 4,  NOW() - INTERVAL 2 DAY),
 (5, 3, 12, NOW() - INTERVAL 30 MINUTE);

INSERT INTO kudos (tenant_id, recipient_employee_id, sender_employee_id, sender_admin_id, badge, message, visibility) VALUES
 (3, 1,  3,    NULL, 'teamwork',         'شكراً على مساعدتك',        'public'),
 (3, 4,  NULL, 3,    'leadership',       'قيادة متميزة للفريق',      'public'),
 (3, 6,  1,    NULL, 'customer_service', 'خدمة عملاء رائعة',         'private'),
 (3, 12, NULL, 3,    'innovation',       'فكرة مبتكرة',              'public'),
 (3, 3,  12,   NULL, 'above_beyond',     'جهد يفوق المتوقع',         'public'),
 (3, 11, NULL, 3,    'reliability',      'موثوق دائماً',             'public'),
 (3, 13, 1,    NULL, 'thank_you',        'شكراً جزيلاً',             'public');

INSERT INTO notifications (tenant_id, admin_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, read_at) VALUES
 (3, 3,  NULL, 'attendance',   'Late check-in',   'تأخير حضور',     'Employee late', 'تأخر موظف عن الدوام', JSON_OBJECT('employee_id',2), 'push,in_app', NULL),
 (3, NULL,12,  'payroll',      'Payslip ready',   'كشف الراتب جاهز','Your payslip',  'كشف راتبك متاح',       JSON_OBJECT('month',@PREV), 'push,in_app', NOW() - INTERVAL 1 DAY),
 (3, NULL,1,   'leave',        'Leave approved',  'تمت الموافقة',   'Leave approved','تمت الموافقة على إجازتك', NULL, 'in_app', NULL),
 (3, 3,  NULL, 'approval',     'Pending approval','طلب موافقة',     'Action needed', 'بانتظار موافقتك',      NULL, 'in_app', NULL),
 (NULL,3, NULL,'system',       'System notice',   'إشعار نظام',     'Maintenance',   'صيانة مجدولة',         NULL, 'in_app,email', NULL),
 (3, NULL,12,  'warning',      'Warning issued',  'إنذار',          'You got a warning','صدر بحقك إنذار',    NULL, 'push', NULL);

-- ---------------------------------------------------------------------------
-- 23) APPROVAL ENGINE — chains/steps + requests/steps (all statuses)
-- ---------------------------------------------------------------------------
INSERT INTO approval_chains (id, tenant_id, name, name_ar, request_type, is_active, min_amount, branch_id, priority, created_by) VALUES
 (1, 3, 'Leave approval',   'اعتماد الإجازات', 'leave',   1, NULL, NULL, 10, 3),
 (3, 3, 'Loan approval',    'اعتماد القروض',   'loan',    1, NULL, NULL, 10, 3);

INSERT INTO approval_chain_steps (tenant_id, chain_id, step_order, approver_type, approver_role, approver_admin_id, label) VALUES
 (3, 1, 1, 'role',  'branch_manager', NULL, 'مدير الفرع'),
 (3, 1, 2, 'role',  'hr',             NULL, 'الموارد البشرية'),
 (3, 3, 1, 'role',  'general_manager',NULL, 'المدير العام');

INSERT INTO approval_requests (id, tenant_id, chain_id, entity_type, entity_id, requested_by_admin_id,
  requested_by_employee_id, context_amount, current_step, total_steps, status, decided_at) VALUES
 (1, 3, 1, 'leave',   2, NULL, 6,  NULL,   1, 2, 'pending',   NULL),
 (3, 3, 1, 'leave',   3, NULL, 4,  NULL,   2, 2, 'approved',  NOW() - INTERVAL 11 DAY),
 (5, 3, 3, 'loan',    4, 3,    NULL,1500.00,1, 1, 'cancelled', NOW());

INSERT INTO approval_request_steps (tenant_id, request_id, step_order, approver_type, approver_role,
  approver_admin_id, label, status, decided_by, decided_at, note) VALUES
 (3, 1, 1, 'role',  'branch_manager', NULL, 'مدير الفرع',     'pending',  NULL, NULL, NULL),
 (3, 1, 2, 'role',  'hr',             NULL, 'الموارد البشرية', 'pending',  NULL, NULL, NULL),
 (3, 3, 1, 'role',  'branch_manager', NULL, 'مدير الفرع',     'approved', 11, NOW() - INTERVAL 12 DAY, NULL),
 (3, 3, 2, 'role',  'hr',             NULL, 'الموارد البشرية', 'approved', 10, NOW() - INTERVAL 11 DAY, NULL),
 (3, 5, 1, 'role',  'general_manager',NULL, 'المدير العام',   'pending',  NULL, NULL, NULL);

-- ---------------------------------------------------------------------------
-- 24) MANAGER INVITATIONS — pending / accepted / cancelled / expired
-- ---------------------------------------------------------------------------
INSERT INTO manager_invitations (tenant_id, email, name, role, branch_id, permissions, token_hash,
  expires_at, accepted_at, accepted_admin_id, cancelled_at, invited_by) VALUES
 (3, 'invite.pending@permedjat.test',  'دعوة معلّقة',  'hr',             NULL, NULL, SHA2('inv-pending',256),  NOW() + INTERVAL 2 DAY, NULL, NULL, NULL, 3),
 (3, 'invite.accepted@permedjat.test', 'دعوة مقبولة',  'branch_manager', 1,    JSON_OBJECT('manage_attendance',true), SHA2('inv-accepted',256), NOW() + INTERVAL 1 DAY, NOW() - INTERVAL 1 DAY, 11, NULL, 3),
 (3, 'invite.cancelled@permedjat.test','دعوة ملغاة',   'viewer',         NULL, NULL, SHA2('inv-cancelled',256),NOW() + INTERVAL 1 DAY, NULL, NULL, NOW() - INTERVAL 2 HOUR, 3),
 (3, 'invite.expired@permedjat.test',  'دعوة منتهية',  'attendance',     1,    NULL, SHA2('inv-expired',256),  NOW() - INTERVAL 1 DAY, NULL, NULL, NULL, 3);

-- ---------------------------------------------------------------------------
-- 25) SUPPORT TICKETS + messages (all statuses)
-- ---------------------------------------------------------------------------
INSERT INTO support_tickets (id, tenant_id, opened_by_admin_id, subject, category, priority, status,
  assigned_super_admin_id, last_message_at, last_message_preview, unread_for_user, unread_for_support) VALUES
 (1, 3, 3, 'مشكلة في تسجيل الحضور',  'technical',       'high',   'open',            1,    NOW() - INTERVAL 1 HOUR, 'لا يعمل الكشك', 0, 1),
 (2, 3, 3, 'استفسار عن الفاتورة',    'billing',         'normal', 'pending_support', 1,    NOW() - INTERVAL 2 HOUR, 'متى تجدد؟', 0, 1),
 (3, 3, 10,'طلب ميزة جديدة',         'feature_request', 'low',    'pending_user',    1,    NOW() - INTERVAL 1 DAY,  'نحتاج تفاصيل', 1, 0),
 (4, 3, 3, 'تم الحل',                'account',         'normal', 'resolved',        1,    NOW() - INTERVAL 3 DAY,  'شكراً', 0, 0),
 (5, 3, 3, 'تذكرة مغلقة',            'other',           'urgent', 'closed',          1,    NOW() - INTERVAL 10 DAY, 'مغلقة', 0, 0);

INSERT INTO support_messages (ticket_id, sender_type, sender_admin_id, sender_super_admin_id, body) VALUES
 (1, 'user',    3, NULL, 'الكشك لا يعمل منذ الصباح'),
 (1, 'system',  NULL, NULL, 'تم استلام التذكرة'),
 (2, 'user',    3, NULL, 'متى يتم تجديد الاشتراك؟'),
 (3, 'user',    10, NULL, 'نريد تقرير مخصص'),
 (3, 'support', NULL, 1, 'هل يمكن توضيح المطلوب؟'),
 (4, 'user',    3, NULL, 'كانت لدي مشكلة دخول'),
 (4, 'support', NULL, 1, 'تم الحل، نعتذر عن الإزعاج');


-- ---------------------------------------------------------------------------
-- 27) ANALYTICS DASHBOARD + LOGS
-- ---------------------------------------------------------------------------
INSERT INTO analytics_dashboards (tenant_id, admin_id, name, layout) VALUES
 (3, 3, 'Default', JSON_ARRAY(JSON_OBJECT('key','attendance_rate','type','kpi','position',1,'size','sm'),
                              JSON_OBJECT('key','headcount','type','kpi','position',2,'size','sm'),
                              JSON_OBJECT('key','payroll_trend','type','chart','position',3,'size','lg'))),
 (3, 10,'HR View', JSON_ARRAY(JSON_OBJECT('key','turnover','type','chart','position',1,'size','lg')));

INSERT INTO login_attempts (identifier, identifier_type, tenant_id, admin_id, success, failure_reason, ip, user_agent) VALUES
 ('farkha.nims@gmail.com', 'email', 3, 3, 1, NULL, '127.0.0.1', 'PermedjatAdmin/1.0'),
 ('hr.test@permedjat.test',   'email', 3, 10, 0, 'wrong_password', '127.0.0.1', 'PermedjatAdmin/1.0'),
 ('+201023809407',         'phone', 3, NULL, 1, NULL, '127.0.0.1', 'PermedjatEmployee/1.0'),
 ('EMP-007',               'employee_code', 3, NULL, 0, 'not_activated', '127.0.0.1', 'PermedjatEmployee/1.0'),
 ('203.0.113.5',           'ip', NULL, NULL, 0, 'rate_limited', '203.0.113.5', 'curl/8.0');

INSERT INTO audit_log (tenant_id, admin_id, action, target_type, target_id, payload, ip, user_agent) VALUES
 (3, 3,  'payroll.approve', 'payroll',  '3',  JSON_OBJECT('month',@PREV), '127.0.0.1', 'PermedjatAdmin/1.0'),
 (3, 3,  'employee.create', 'employee', '14', JSON_OBJECT('name','ريم الحربي'), '127.0.0.1', 'PermedjatAdmin/1.0'),
 (3, 10, 'leave.approve',   'leave',    '1',  NULL, '127.0.0.1', 'PermedjatAdmin/1.0'),
 (3, 3,  'settings.update', 'tenant',   '3',  JSON_OBJECT('field','currency','value','SAR'), '127.0.0.1', 'PermedjatAdmin/1.0');

-- ============================================================================
-- 28) FULL ENUM COVERAGE — remaining enum values not hit above
-- ============================================================================

-- 28.1 admins.auth_provider = apple
INSERT INTO admins (id, firebase_uid, tenant_id, branch_id, name, phone, email,
  auth_provider, role, is_active) VALUES
 (15, 'apple-uid-0001', 3, NULL, 'مدير عبر Apple', '+966500000015', 'apple.test@permedjat.test', 'apple', 'viewer', 1);

-- 28.2 admin_sessions seed removed — table dropped 2026-06-13 (unused)

-- 28.3 bonus_rules.rule_type = text   |   deduction_rules.rule_type = text, boolean
INSERT INTO bonus_rules (tenant_id, rule_key, rule_type, rule_value, description, is_active) VALUES
 (3, 'bonus_note', 'text', 'يُصرف مع راتب الشهر التالي', 'ملاحظة نصية', 1);
INSERT INTO deduction_rules (tenant_id, rule_key, rule_type, rule_value, description, is_active) VALUES
 (3, 'deduction_policy',  'text',    'حسب لائحة الجزاءات', 'سياسة نصية', 1),
 (3, 'apply_on_weekends', 'boolean', '0',                  'تطبيق الخصم في عطلة الأسبوع', 1);

-- 28.4 employee_settlements — remaining reasons + draft/paid statuses (UNIQUE per employee)
INSERT INTO employee_settlements (tenant_id, employee_id, reason, last_working_day, base_salary, net_amount,
  status, created_by, approved_by, approved_at, paid_at) VALUES
 (3, 2,  'resignation',    @D - INTERVAL 3 DAY,   4500.00, 4500.00,  'draft',    3, NULL, NULL, NULL),
 (3, 5,  'termination',    @D - INTERVAL 70 DAY,  5500.00, 6000.00,  'paid',     3, 3, NOW() - INTERVAL 60 DAY, NOW() - INTERVAL 55 DAY),
 (3, 8,  'retirement',     @D + INTERVAL 30 DAY,  6500.00, 12000.00, 'approved', 3, 3, NOW() - INTERVAL 1 DAY, NULL),
 (3, 11, 'death',          @D - INTERVAL 20 DAY,  4800.00, 8000.00,  'paid',     3, 3, NOW() - INTERVAL 18 DAY, NOW() - INTERVAL 15 DAY),
 (3, 13, 'absconding',     @D - INTERVAL 10 DAY,  5300.00, 0.00,     'draft',    3, NULL, NULL, NULL),
 (3, 14, 'other',          @D - INTERVAL 5 DAY,   3500.00, 3500.00,  'approved', 3, 3, NOW(), NULL);

-- 28.5 manager_invitations.role = general_manager
INSERT INTO manager_invitations (tenant_id, email, name, role, branch_id, permissions, token_hash,
  expires_at, accepted_at, accepted_admin_id, cancelled_at, invited_by) VALUES
 (3, 'invite.gm@permedjat.test', 'دعوة مدير عام', 'general_manager', NULL, NULL, SHA2('inv-gm',256), NOW() + INTERVAL 3 DAY, NULL, NULL, NULL, 3);

-- 28.6 notifications.type = general, invite, support
INSERT INTO notifications (tenant_id, admin_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via, read_at) VALUES
 (3, 3, NULL, 'general',      'General notice',  'إشعار عام',     'General message',   'رسالة عامة لكل المسؤولين',  NULL, 'in_app',       NULL),
 (3, 3, NULL, 'invite',       'Invite accepted', 'قبول دعوة',     'Manager joined',    'انضم مدير جديد عبر دعوة',   NULL, 'in_app',       NOW() - INTERVAL 1 DAY),
 (3, 3, NULL, 'support',      'Support reply',   'رد الدعم',      'Support replied',   'رد فريق الدعم على تذكرتك',  NULL, 'push,in_app',  NULL);

-- 28.7 performance_cycles.period_type = monthly, semi_annual, custom
INSERT INTO performance_cycles (id, tenant_id, name, name_ar, period_type, start_date, end_date, status, created_by) VALUES
 (4, 3, 'Monthly',      'تقييم شهري',   'monthly',     @D - INTERVAL 10 DAY,  @D + INTERVAL 20 DAY, 'active', 3),
 (5, 3, 'Semi-annual',  'نصف سنوي',     'semi_annual', @D - INTERVAL 3 MONTH, @D + INTERVAL 3 MONTH, 'draft',  3),
 (6, 3, 'Custom range', 'مدى مخصص',     'custom',      @D - INTERVAL 1 MONTH, @D + INTERVAL 1 MONTH, 'active', 3);

-- 28.8 performance_reviews.reviewer_type = subordinate
INSERT INTO performance_reviews (tenant_id, employee_id, cycle_id, reviewer_id, reviewer_type, rating,
  strengths, areas_for_improvement, review, status) VALUES
 (3, 4, 3, 30, 'subordinate', 3.90, 'منفتح للنقاش', 'الحزم في القرارات', 'تقييم 360° من مرؤوس', 'submitted');


-- 28.10 recurring_leaves.day_of_week = remaining days
INSERT INTO recurring_leaves (tenant_id, branch_id, day_of_week, type, reason, is_active) VALUES
 (3, NULL, 'monday',    'weekly_off', 'تغطية حالة', 1),
 (3, NULL, 'tuesday',   'weekly_off', 'تغطية حالة', 1),
 (3, NULL, 'wednesday', 'weekly_off', 'تغطية حالة', 1),
 (3, NULL, 'thursday',  'weekly_off', 'تغطية حالة', 0);

-- 28.11 EXTRA TENANTS → active/inactive states (super-admin testing data)
INSERT INTO tenants (id, name, timezone, currency, country_code, is_active) VALUES
 (4, 'شركة نشطة',   'Asia/Riyadh', 'SAR', 'SA', 1),
 (5, 'شركة موقوفة', 'Asia/Riyadh', 'SAR', 'SA', 0),
 (6, 'شركة موقوفة 2','Africa/Cairo','EGP', 'EG', 0),
 (7, 'شركة نشطة 2', 'Asia/Riyadh', 'SAR', 'SA', 1);

-- 28.12 super_admins.role = readonly, admin  (preserved table → INSERT IGNORE for re-runs)
SET @sa_hash := (SELECT password_hash FROM super_admins WHERE username = 'superadmin' LIMIT 1);
INSERT IGNORE INTO super_admins (username, email, password_hash, display_name, role, is_active) VALUES
 ('support_readonly', NULL, @sa_hash, 'Support Readonly', 'readonly', 1),
 ('support_admin',    NULL, @sa_hash, 'Support Admin',    'admin',    1);

-- ============================================================================
-- DONE
-- ============================================================================
SELECT 'SEED COMPLETE' AS status;
