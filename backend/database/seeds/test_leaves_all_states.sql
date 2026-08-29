-- =====================================================================
-- Test seed: leave requests in EVERY type × status combination.
-- 6 types (annual, sick, personal, unpaid, weekly_off, converted_from_absence)
-- × 3 statuses (pending, approved, rejected) = 18 rows.
--
-- Safe to run on the live DB: every row's `reason` is prefixed with "TEST"
-- so you can remove them all later with:
--     DELETE FROM leaves WHERE reason LIKE 'TEST %';
--
-- Targets are auto-resolved (no IDs to fill in): the first active employee,
-- that employee's tenant, and an admin in the same tenant (for approver/rejecter).
-- If you want a specific employee, set @emp manually instead of the SELECT below.
-- =====================================================================

SET @emp    := (SELECT id FROM employees WHERE status IN ('active','on_leave') ORDER BY id LIMIT 1);
SET @tenant := (SELECT tenant_id FROM employees WHERE id = @emp);
SET @admin  := (SELECT id FROM admins WHERE tenant_id = @tenant ORDER BY id LIMIT 1);

INSERT INTO leaves
  (tenant_id, employee_id, date, start_date, end_date, type, reason, status,
   approved_by, approved_at, rejected_by, rejection_reason, created_at)
VALUES
-- ── annual ────────────────────────────────────────────────────────────
(@tenant,@emp,'2026-07-01','2026-07-01','2026-07-03','annual','TEST اجازة سنوية - قيد الانتظار','pending', NULL,   NULL,  NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-07-05','2026-07-05','2026-07-07','annual','TEST اجازة سنوية - مقبولة','approved',     @admin, NOW(), NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-07-09','2026-07-09','2026-07-10','annual','TEST اجازة سنوية - مرفوضة','rejected',     NULL,   NULL,  @admin, 'TEST سبب الرفض: ضغط عمل', NOW()),
-- ── sick ──────────────────────────────────────────────────────────────
(@tenant,@emp,'2026-07-12','2026-07-12','2026-07-12','sick','TEST اجازة مرضية - قيد الانتظار','pending',  NULL,   NULL,  NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-07-14','2026-07-14','2026-07-16','sick','TEST اجازة مرضية - مقبولة','approved',       @admin, NOW(), NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-07-18','2026-07-18','2026-07-18','sick','TEST اجازة مرضية - مرفوضة','rejected',       NULL,   NULL,  @admin, 'TEST سبب الرفض: لا يوجد تقرير طبي', NOW()),
-- ── personal ──────────────────────────────────────────────────────────
(@tenant,@emp,'2026-07-20','2026-07-20','2026-07-20','personal','TEST اجازة شخصية - قيد الانتظار','pending', NULL, NULL, NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-07-22','2026-07-22','2026-07-23','personal','TEST اجازة شخصية - مقبولة','approved',    @admin, NOW(), NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-07-25','2026-07-25','2026-07-25','personal','TEST اجازة شخصية - مرفوضة','rejected',    NULL,   NULL,  @admin, 'TEST سبب الرفض',     NOW()),
-- ── unpaid ────────────────────────────────────────────────────────────
(@tenant,@emp,'2026-07-27','2026-07-27','2026-07-29','unpaid','TEST اجازة بدون راتب - قيد الانتظار','pending', NULL, NULL, NULL, NULL,                 NOW()),
(@tenant,@emp,'2026-08-01','2026-08-01','2026-08-05','unpaid','TEST اجازة بدون راتب - مقبولة','approved',  @admin, NOW(), NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-08-07','2026-08-07','2026-08-07','unpaid','TEST اجازة بدون راتب - مرفوضة','rejected',  NULL,   NULL,  @admin, 'TEST سبب الرفض',     NOW()),
-- ── weekly_off ────────────────────────────────────────────────────────
(@tenant,@emp,'2026-08-09','2026-08-09','2026-08-09','weekly_off','TEST راحة اسبوعية - قيد الانتظار','pending', NULL, NULL, NULL, NULL,               NOW()),
(@tenant,@emp,'2026-08-10','2026-08-10','2026-08-10','weekly_off','TEST راحة اسبوعية - مقبولة','approved', @admin, NOW(), NULL,   NULL,                 NOW()),
(@tenant,@emp,'2026-08-11','2026-08-11','2026-08-11','weekly_off','TEST راحة اسبوعية - مرفوضة','rejected', NULL,   NULL,  @admin, 'TEST سبب الرفض',     NOW()),
-- ── converted_from_absence ────────────────────────────────────────────
(@tenant,@emp,'2026-08-13','2026-08-13','2026-08-13','converted_from_absence','TEST تحويل من غياب - قيد الانتظار','pending', NULL, NULL, NULL, NULL, NOW()),
(@tenant,@emp,'2026-08-14','2026-08-14','2026-08-14','converted_from_absence','TEST تحويل من غياب - مقبول','approved', @admin, NOW(), NULL, NULL,        NOW()),
(@tenant,@emp,'2026-08-15','2026-08-15','2026-08-15','converted_from_absence','TEST تحويل من غياب - مرفوض','rejected', NULL, NULL, @admin, 'TEST سبب الرفض', NOW());

-- Verify what was inserted:
SELECT id, type, status, start_date, end_date, reason FROM leaves WHERE reason LIKE 'TEST %' ORDER BY id;
