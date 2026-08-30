-- Per-line payroll overrides. Lets an admin edit the amount of, or remove,
-- ANY single computed line (absence, late, loan, insurance, tax, overtime…)
-- for one employee in one month — not just the manual deductions/bonuses.
--
-- A line is identified by a stable hash of (type | date | description) so the
-- override re-attaches to the same line each time payroll is recalculated. The
-- override is applied live while the slip is a draft and is frozen into the
-- slip snapshot on approval (see app/payroll/approve.php). Safe to run once.

CREATE TABLE IF NOT EXISTS `payroll_line_overrides` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `month` char(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `line_kind` enum('deduction','bonus') COLLATE utf8mb4_unicode_ci NOT NULL,
  `line_type` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `line_date` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `line_desc` text COLLATE utf8mb4_unicode_ci,
  `line_hash` char(40) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'sha1(type|date|desc)',
  `waived` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1 = line removed for this month',
  `override_amount` decimal(12,2) DEFAULT NULL COMMENT 'replacement amount when not waived',
  `reason` text COLLATE utf8mb4_unicode_ci,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_override` (`tenant_id`,`employee_id`,`month`,`line_kind`,`line_hash`),
  KEY `idx_plo_emp_month` (`employee_id`,`month`,`tenant_id`),
  CONSTRAINT `fk_plo_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_plo_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_plo_created_by` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
