-- Allow fractional base salaries (e.g. 4500.50). The column was previously INT,
-- which silently truncated any decimal part. DECIMAL(12,2) matches the payroll table.
ALTER TABLE `employees`
    MODIFY COLUMN `base_salary` DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0.00;
