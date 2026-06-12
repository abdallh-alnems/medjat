-- ============================================================
-- Migration: default annual leave entitlement starts at 0
-- Date: 2026-06-11
-- Companies should start with 0 default annual leave days and
-- have the administration set the real value, instead of the
-- previous baked-in 21. New tenants now default to 0.
--
-- Existing tenants are left untouched: we cannot tell apart a
-- tenant that intentionally chose 21 from one still on the old
-- auto-default. Uncomment the UPDATE below only if you want to
-- reset every tenant still on the legacy 21 back to 0.
-- ============================================================

ALTER TABLE `tenants`
  MODIFY COLUMN `default_annual_leave_days` int NOT NULL DEFAULT 0
  COMMENT 'Default annual leave entitlement for all employees (0 until admin sets it)';

-- Optional reset of existing tenants still on the legacy default:
-- UPDATE `tenants` SET `default_annual_leave_days` = 0 WHERE `default_annual_leave_days` = 21;
