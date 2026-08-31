-- ============================================
-- Migration: leave_balance_settings
-- Configurable annual leave entitlement
-- (company default + optional per-employee override)
-- + year-to-year carryover balances.
-- Date: 2026-05-23
-- MySQL 8.0 compatible (no ADD COLUMN IF NOT EXISTS)
-- ============================================

-- 1) + 2) Tenant-level leave settings.
--    default_annual_leave_days: company-wide entitlement (Egyptian labor law default = 21).
--    leave_carryover_max_days : NULL = no carryover (remaining is dropped);
--                               a number = max days carried into the next year.
ALTER TABLE `tenants`
    ADD COLUMN `default_annual_leave_days` INT NOT NULL DEFAULT 21 COMMENT 'Default annual leave entitlement for all employees'
        AFTER `allow_offline_attendance`,
    ADD COLUMN `leave_carryover_max_days` INT NULL DEFAULT NULL COMMENT 'NULL = no carryover; number = max days carried to next year'
        AFTER `default_annual_leave_days`;

-- 3) Per-employee override. NULL = inherit company default.
ALTER TABLE `employees`
    ADD COLUMN `annual_leave_days` INT NULL DEFAULT NULL COMMENT 'NULL = inherit tenant default; number = per-employee override'
        AFTER `work_end_time`;

-- 4) Opening balance per employee per year (drives carryover).
CREATE TABLE IF NOT EXISTS `leave_year_balances` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `year` smallint NOT NULL,
  `entitlement_days` int NOT NULL COMMENT 'Entitlement for this year at row-generation time',
  `carried_over_days` int NOT NULL DEFAULT 0 COMMENT 'Days carried over from the previous year',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_lyb_employee_year` (`employee_id`,`year`),
  KEY `idx_lyb_tenant` (`tenant_id`),
  CONSTRAINT `fk_lyb_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_lyb_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
