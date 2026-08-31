-- ============================================
-- Migration: leave_carryover_advanced
-- Advanced annual-leave carryover system:
--   1) Expiry of carried-over days
--   2) Automatic year-end rollover (cron flag)
--   3) Cash encashment (payout) of excess / legal-minimum days
--   4) Multi-level carryover policies (tenant/branch/category/employee + seniority tiers)
--   5) Legal cap (statutory minimum carry + seniority-based entitlement bump)
-- Date: 2026-06-12
-- MySQL 8.0 compatible (NO `ADD COLUMN IF NOT EXISTS` — run once, by hand, on live DB)
-- ============================================

-- ---------------------------------------------------------------
-- 1) Multi-level carryover policies.
--    Resolver precedence: employee > category > branch > tenant.
--    Within a scope, the highest `min_seniority_months <= tenure` wins.
--    A NULL `carryover_max_days` means "no cap" (carry everything).
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `leave_carryover_policies` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `scope_type` enum('tenant','branch','category','employee') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'tenant',
  `scope_id` int unsigned DEFAULT NULL COMMENT 'branch/category/employee id; NULL for tenant scope',
  `min_seniority_months` int unsigned NOT NULL DEFAULT 0 COMMENT 'Seniority tier threshold in months (0 = applies to everyone)',
  `carryover_enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT '0 = remaining is dropped (unless legal_min/encash apply)',
  `carryover_max_days` int DEFAULT NULL COMMENT 'Max days carried; NULL = unlimited',
  `expiry_months` int unsigned DEFAULT NULL COMMENT 'Carried days expire N months into the new year; NULL = never',
  `encash_excess` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'Pay out days above the cap instead of dropping them',
  `legal_min_carry_days` int unsigned DEFAULT NULL COMMENT 'Statutory floor that must be carried or encashed, never forfeited',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_lcp_scope` (`tenant_id`,`scope_type`,`scope_id`,`min_seniority_months`),
  KEY `idx_lcp_tenant` (`tenant_id`),
  CONSTRAINT `fk_lcp_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------
-- 2) Leave encashment (cash payout) records.
--    One row per employee per source year; fed into payroll as a bonus line.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `leave_encashments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `source_year` smallint NOT NULL COMMENT 'Year whose remaining balance is being cashed out',
  `days` int NOT NULL DEFAULT 0,
  `daily_rate` decimal(12,2) NOT NULL DEFAULT '0.00',
  `amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `status` enum('pending','paid','cancelled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `payroll_month` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'YYYY-MM where it was paid',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_enc_employee_year` (`employee_id`,`source_year`),
  KEY `idx_enc_tenant` (`tenant_id`),
  KEY `idx_enc_month` (`tenant_id`,`payroll_month`),
  CONSTRAINT `fk_enc_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_enc_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------
-- 3) Expiry tracking on the yearly opening balance.
-- ---------------------------------------------------------------
ALTER TABLE `leave_year_balances`
    ADD COLUMN `carryover_expires_on` DATE NULL DEFAULT NULL
        COMMENT 'Carried-over days expire (drop if unused) on this date; NULL = never'
        AFTER `carried_over_days`,
    ADD COLUMN `carryover_encashed_days` INT NOT NULL DEFAULT 0
        COMMENT 'Days that were cashed out for this year instead of carried'
        AFTER `carryover_expires_on`;

-- ---------------------------------------------------------------
-- 4) Tenant-level switches for automation + statutory entitlement.
-- ---------------------------------------------------------------
ALTER TABLE `tenants`
    ADD COLUMN `auto_rollover_enabled` TINYINT(1) NOT NULL DEFAULT 0
        COMMENT '1 = cron runs year-end rollover automatically on Jan 1'
        AFTER `leave_carryover_max_days`,
    ADD COLUMN `apply_legal_seniority_entitlement` TINYINT(1) NOT NULL DEFAULT 1
        COMMENT '1 = bump annual entitlement to >=30 days after 10 years service (Egyptian labour law)'
        AFTER `auto_rollover_enabled`;
