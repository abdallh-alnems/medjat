-- End-of-service / Full & Final Settlement ("تسوية نهاية الخدمة").
--
-- When HR ends an employee's service the app opens a settlement page that
-- auto-computes the final dues and lets HR edit every line before approving:
--
--   Earnings
--     pending_salary    → salary earned in the current payroll cycle up to the
--                         last working day (prorated, from PayrollCalculator)
--     gratuity_amount   → end-of-service gratuity. Default suggestion is
--                         `gratuity_days` (≈21/yr of service) × daily rate, but
--                         HR can override the amount outright.
--     leave_encashment  → unused annual-leave balance × daily rate
--     other_additions   → free-form positive line total (see line_items)
--
--   Deductions
--     outstanding_loans → remaining balance of active loans/advances
--     other_deductions  → free-form negative line total (see line_items)
--
--   net_amount = total_earnings − total_deductions
--
-- line_items holds the editable custom rows as
--   [{"label": "...", "kind": "earning|deduction", "amount": 0.00}, ...]
-- breakdown freezes the full computed snapshot at approval time (like payroll).
--
-- Lifecycle: draft → approved → paid. Approving the settlement flips the
-- employee row to status='terminated' and stamps terminated_at = last_working_day.
-- One settlement per employee (unique), upserted while still a draft.
-- Safe to run once.

CREATE TABLE IF NOT EXISTS `employee_settlements` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `reason` enum('resignation','termination','end_of_contract','retirement','death','absconding','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'resignation',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `last_working_day` date NOT NULL,
  `hire_date` date DEFAULT NULL COMMENT 'Snapshot of service-start date used for the gratuity calc',
  `base_salary` decimal(12,2) NOT NULL DEFAULT '0.00',
  `daily_rate` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'base_salary / 30',
  `years_of_service` decimal(6,2) NOT NULL DEFAULT '0.00',
  `pending_salary` decimal(12,2) NOT NULL DEFAULT '0.00',
  `gratuity_days` decimal(7,2) NOT NULL DEFAULT '0.00',
  `gratuity_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `leave_balance_days` decimal(7,2) NOT NULL DEFAULT '0.00',
  `leave_encashment` decimal(12,2) NOT NULL DEFAULT '0.00',
  `other_additions` decimal(12,2) NOT NULL DEFAULT '0.00',
  `outstanding_loans` decimal(12,2) NOT NULL DEFAULT '0.00',
  `other_deductions` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_earnings` decimal(12,2) NOT NULL DEFAULT '0.00',
  `total_deductions` decimal(12,2) NOT NULL DEFAULT '0.00',
  `net_amount` decimal(12,2) NOT NULL DEFAULT '0.00',
  `line_items` json DEFAULT NULL COMMENT 'Custom editable rows [{label,kind,amount}]',
  `breakdown` json DEFAULT NULL COMMENT 'Frozen computed snapshot captured at approval',
  `status` enum('draft','approved','paid') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'draft',
  `created_by` int unsigned DEFAULT NULL,
  `approved_by` int unsigned DEFAULT NULL,
  `approved_at` datetime DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_settlement_employee` (`tenant_id`,`employee_id`),
  KEY `idx_settlement_tenant` (`tenant_id`),
  KEY `idx_settlement_status` (`tenant_id`,`status`),
  CONSTRAINT `fk_settlement_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_settlement_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_settlement_created_by` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_settlement_approved_by` FOREIGN KEY (`approved_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
