-- Fixed monthly allowances per employee (housing, transport, food, etc.).
-- Unlike manual bonuses (one-off lines), an allowance row is active across a
-- date range and re-emitted by PayrollCalculator for every payroll month in
-- that range. Empty end_month means "ongoing until cancelled".
--
-- MySQL 8 safe. Run once.
CREATE TABLE IF NOT EXISTS `employee_allowances` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL
    COMMENT 'housing|transport|food|communication|other (or custom key)',
  `label` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Optional human label, overrides the type translation in slips',
  `amount` decimal(12,2) NOT NULL,
  `start_month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM inclusive',
  `end_month` varchar(7) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'YYYY-MM inclusive; NULL = ongoing',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_alw_emp` (`employee_id`, `tenant_id`),
  KEY `idx_alw_tenant_active` (`tenant_id`, `start_month`, `end_month`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `fk_alw_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_alw_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_alw_admin` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
