-- Enhancements to the bulk-adjustments feature:
--   * allow 'shift' as a scope (so the older branch/shift/category sheet can be
--     unified onto the tracked-batch path).
-- The `month` column already exists on bulk_adjustments; no change needed for
-- the month-selection enhancement.
--
-- MySQL 8 (live): run once by hand.

ALTER TABLE `bulk_adjustments`
  MODIFY COLUMN `scope_type`
    enum('all','branch','category','employee','shift')
    COLLATE utf8mb4_unicode_ci NOT NULL;
