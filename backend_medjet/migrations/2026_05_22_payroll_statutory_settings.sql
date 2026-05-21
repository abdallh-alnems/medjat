-- ============================================
-- Migration: payroll_statutory_settings
-- Flexible statutory deductions per tenant
-- (social insurance, income tax, EOSB)
-- Date: 2026-05-22
-- MySQL 8.0 compatible
-- ============================================

CREATE TABLE IF NOT EXISTS `payroll_statutory_settings` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `social_insurance_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `si_employee_rate` decimal(5,2) DEFAULT NULL,
  `si_employer_rate` decimal(5,2) DEFAULT NULL,
  `si_min_wage` decimal(12,2) DEFAULT NULL,
  `si_max_wage` decimal(12,2) DEFAULT NULL,
  `income_tax_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `income_tax_brackets` json DEFAULT NULL,
  `tax_personal_exemption` decimal(12,2) DEFAULT NULL,
  `eosb_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `eosb_days_per_year` decimal(5,2) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_statutory_tenant` (`tenant_id`),
  CONSTRAINT `fk_statutory_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
