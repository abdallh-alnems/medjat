-- Customizable attendance cycle start day (e.g. 25 -> a cycle runs 25th to 24th
-- of the next month). Company-level default with optional per-branch override.
-- The cycle is labeled/reported by its END month. Scope: attendance views only.
-- NOTE: MySQL 8 has no `ADD COLUMN IF NOT EXISTS`; run once.
ALTER TABLE `tenants`
  ADD COLUMN `cycle_start_day` tinyint unsigned NOT NULL DEFAULT 1 COMMENT 'Attendance cycle start day (1-28); cycle labeled by its end month' AFTER `leave_carryover_max_days`;
ALTER TABLE `branches`
  ADD COLUMN `cycle_start_day` tinyint unsigned DEFAULT NULL COMMENT 'Per-branch override of attendance cycle start day; NULL = inherit company' AFTER `gps_radius_meters`;
