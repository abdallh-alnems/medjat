-- Configurable weekly-schedule (roster) start weekday. Company-level setting.
-- ISO-8601 weekday convention: 1=Mon .. 7=Sun. Default 6 = Saturday (Arab work week).
-- Scope: weekly schedule / roster grid only (not attendance cycle or payroll).
-- NOTE: MySQL 8 has no `ADD COLUMN IF NOT EXISTS`; run once.
ALTER TABLE `tenants`
  ADD COLUMN `week_start_day` tinyint unsigned NOT NULL DEFAULT 6 COMMENT 'Weekly schedule start weekday (ISO: 1=Mon..7=Sun, default 6=Sat)' AFTER `cycle_start_day`;
