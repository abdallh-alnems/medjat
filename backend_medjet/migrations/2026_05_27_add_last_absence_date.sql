-- Lazy absence catch-up marker.
-- Stores the last *completed* day for which absences were materialized by the
-- on-access catch-up (AttendanceModel::catchUpAbsences), which replaces the
-- daily mark_absent cron. NULL = never run; the catch-up then bootstraps a
-- bounded window (see $maxBackfillDays).
--
-- MySQL 8 safe (no "IF NOT EXISTS" on ADD COLUMN). Run once.
ALTER TABLE `tenants`
  ADD COLUMN `last_absence_date` DATE NULL
  COMMENT 'Last completed day absences were materialized (lazy on-access catch-up)'
  AFTER `cycle_start_day`;
