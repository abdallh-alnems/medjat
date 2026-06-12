-- Bulk bonus/deduction batches.
--
-- A "batch" records a single bulk action (give a bonus or a deduction to a
-- whole scope: all employees / a branch / a category / one employee). When a
-- batch is applied it fans out into one manual_bonuses / manual_deductions row
-- per matching employee (so payroll math, slips and audit stay unchanged), and
-- every fanned-out row carries the originating `batch_id`.
--
-- Tracking the batch lets the admin later:
--   * delete the whole batch (removes every child row),
--   * remove one employee from the batch,
--   * edit the amount / percentage (recomputes every child row).
--
-- MySQL 8 (live) has no "ADD COLUMN IF NOT EXISTS", so the ALTERs below are
-- written to be run once by hand. Re-running will error on the existing column
-- (safe to ignore).

CREATE TABLE IF NOT EXISTS `bulk_adjustments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `kind` enum('bonus','deduction') COLLATE utf8mb4_unicode_ci NOT NULL,
  `scope_type` enum('all','branch','category','employee') COLLATE utf8mb4_unicode_ci NOT NULL,
  `scope_id` int unsigned DEFAULT NULL COMMENT 'NULL for scope_type = all',
  `scope_name` varchar(190) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'snapshot label for display',
  `amount` decimal(12,2) NOT NULL COMMENT 'fixed money OR percent value (0-100)',
  `amount_type` enum('fixed','percent') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'fixed',
  `reason` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `month` varchar(7) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'YYYY-MM',
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ba_tenant_month` (`tenant_id`,`month`),
  KEY `created_by` (`created_by`),
  CONSTRAINT `bulk_adjustments_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bulk_adjustments_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Link the per-employee rows back to their batch (NULL = single-employee manual
-- adjustment, created the old way). ON DELETE SET NULL so removing a batch is an
-- explicit app-level operation, never a silent cascade of payroll figures.
ALTER TABLE `manual_bonuses`
  ADD COLUMN `batch_id` int unsigned DEFAULT NULL AFTER `employee_id`,
  ADD KEY `idx_mb_batch` (`batch_id`),
  ADD CONSTRAINT `manual_bonuses_ibfk_batch` FOREIGN KEY (`batch_id`) REFERENCES `bulk_adjustments` (`id`) ON DELETE SET NULL;

ALTER TABLE `manual_deductions`
  ADD COLUMN `batch_id` int unsigned DEFAULT NULL AFTER `employee_id`,
  ADD KEY `idx_md_batch` (`batch_id`),
  ADD CONSTRAINT `manual_deductions_ibfk_batch` FOREIGN KEY (`batch_id`) REFERENCES `bulk_adjustments` (`id`) ON DELETE SET NULL;
