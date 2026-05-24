-- Weekly rotating shifts.
-- The existing `shifts` table defines shift templates (Morning 07-15, Mid 12-21, ...)
-- and `employees.shift_id` is a single STATIC assignment. That only fits fixed
-- schedules. Call centres and similar rotate staff between shifts every week, so the
-- "expected shift" must be resolved per DATE, not per employee.
--
-- `employee_shift_schedule` holds one row per employee per day (one shift/day, v1 has
-- no split shifts). `shift_id = NULL` means a rest/off day. Rows start as `draft` while
-- the manager edits the week and become `published` once they hit Publish — only
-- published rows drive attendance. When no published row exists for a date, attendance
-- falls back to the static `employees.shift_id`, so fixed-shift employees are unaffected.

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `employee_shift_schedule` (
    `id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `tenant_id` INT UNSIGNED NOT NULL,
    `employee_id` INT UNSIGNED NOT NULL,
    `shift_id` INT UNSIGNED DEFAULT NULL COMMENT 'NULL = rest / off day',
    `work_date` DATE NOT NULL,
    `status` ENUM('draft','published') NOT NULL DEFAULT 'draft',
    `created_by` INT UNSIGNED DEFAULT NULL COMMENT 'admin who last set this cell',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uniq_sched_emp_date` (`employee_id`, `work_date`),
    INDEX `idx_sched_tenant_date` (`tenant_id`, `work_date`),
    INDEX `idx_sched_shift` (`shift_id`),
    CONSTRAINT `fk_sched_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sched_employee` FOREIGN KEY (`employee_id`) REFERENCES `employees`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sched_shift` FOREIGN KEY (`shift_id`) REFERENCES `shifts`(`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_sched_admin` FOREIGN KEY (`created_by`) REFERENCES `admins`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Marks whether an employee uses the single static shift or the weekly roster.
-- 'fixed' keeps the current behaviour; 'rotating' tells the UI to manage the
-- employee from the weekly schedule instead of the static shift dropdown.
ALTER TABLE `employees`
    ADD COLUMN `shift_type` ENUM('fixed','rotating') NOT NULL DEFAULT 'fixed' AFTER `shift_id`;
