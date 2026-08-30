-- Per-day absence deduction override.
-- mode=auto  -> company rule (absence_multiplier) applies (default)
-- mode=days  -> deduction = (base_salary / 30) * deduction_value
-- mode=amount-> deduction = deduction_value (fixed money)
-- NOTE: MySQL 8 has no `ADD COLUMN IF NOT EXISTS`; run once.
ALTER TABLE `attendance`
  ADD COLUMN `deduction_mode` enum('auto','days','amount') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto' AFTER `recorded_by`,
  ADD COLUMN `deduction_value` decimal(10,2) DEFAULT NULL AFTER `deduction_mode`;
