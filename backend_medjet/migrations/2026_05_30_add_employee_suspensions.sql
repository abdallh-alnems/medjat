-- Work-suspension ("موقوف عن العمل") feature. The admin suspends an employee
-- from work for a definite period (start + end date) or open-ended (until
-- manually ended). Each suspension records how the salary is treated during
-- the suspension window:
--   unpaid  → full daily rate deducted for every suspended day
--   partial → only `pay_percentage`% of the daily rate is paid; the rest is
--             deducted
--   full    → precautionary suspension, no deduction (full pay)
-- The employee's `status` is flipped to 'suspended' while a suspension is
-- active and restored to `previous_status` when it ends (manually or when a
-- definite period elapses). Safe to run once.

CREATE TABLE IF NOT EXISTS `employee_suspensions` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `pay_mode` enum('unpaid','partial','full') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unpaid',
  `pay_percentage` decimal(5,2) DEFAULT NULL COMMENT 'Percent of salary paid during suspension when pay_mode=partial (0-100)',
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL COMMENT 'NULL = open-ended until manually ended',
  `status` enum('active','ended') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active',
  `previous_status` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Employee status before suspension, restored on reactivation',
  `ended_at` datetime DEFAULT NULL,
  `ended_by` int unsigned DEFAULT NULL,
  `end_note` text COLLATE utf8mb4_unicode_ci,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_susp_tenant` (`tenant_id`),
  KEY `idx_susp_employee` (`employee_id`),
  KEY `idx_susp_status` (`status`),
  KEY `idx_susp_active` (`employee_id`,`status`),
  KEY `idx_susp_dates` (`employee_id`,`start_date`,`end_date`),
  CONSTRAINT `fk_susp_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_susp_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_susp_created_by` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_susp_ended_by` FOREIGN KEY (`ended_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
