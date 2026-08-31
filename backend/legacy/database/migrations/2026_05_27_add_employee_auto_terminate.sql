-- Fixed-duration ("temporary") employees: the date their employment automatically
-- ends. When it passes, the daily alerts cron flips the employee to 'terminated'
-- (so they can no longer check in / log in). NULL = open-ended employment.
ALTER TABLE `employees`
    ADD COLUMN `auto_terminate_at` DATE DEFAULT NULL
        COMMENT 'Auto-terminate the employee on this date (fixed-term workers); NULL = open-ended'
        AFTER `weekly_off_days`;

ALTER TABLE `employees`
    ADD KEY `idx_emp_auto_terminate` (`tenant_id`, `status`, `auto_terminate_at`);
