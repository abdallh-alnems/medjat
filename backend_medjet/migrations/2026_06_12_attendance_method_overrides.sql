-- ============================================
-- Migration: per-category and per-employee attendance method overrides
-- Date: 2026-06-12
-- ============================================
--
-- Extends the attendance-method resolution chain. Effective methods for an
-- employee are resolved most-specific-first:
--   1) employees.attendance_methods        (employee override)
--   2) employee_categories.attendance_methods (UNION across the employee's
--      categories that set an override)
--   3) branches.attendance_methods          (branch override)
--   4) tenants.attendance_methods           (company default)
--
-- NULL means "inherit the next level". gps_radius / allow_offline stay
-- branch-level only (geographic), so they are NOT added here.
--
-- MySQL 8 (live) has no "ADD COLUMN IF NOT EXISTS"; run these once by hand.
-- Re-running errors on the existing column (safe to ignore).

ALTER TABLE `employees`
  ADD COLUMN `attendance_methods` JSON DEFAULT NULL
    COMMENT 'NULL = inherit (category/branch/tenant); array = employee override'
    AFTER `branch_id`;

ALTER TABLE `employee_categories`
  ADD COLUMN `attendance_methods` JSON DEFAULT NULL
    COMMENT 'NULL = inherit; array = category override (unioned across an employees categories)'
    AFTER `is_active`;
