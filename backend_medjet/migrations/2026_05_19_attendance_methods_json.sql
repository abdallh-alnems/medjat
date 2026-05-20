-- ============================================
-- Migration: Convert attendance_method (single ENUM) → attendance_methods (JSON array)
--           + add manual_attendance_admin_ids to tenants
-- Date: 2026-05-19
-- ============================================

-- 1) tenants: drop old ENUM, add JSON columns
ALTER TABLE `tenants`
  DROP COLUMN `attendance_method`,
  ADD COLUMN `attendance_methods` JSON NOT NULL
    COMMENT 'Enabled methods, e.g. ["qr_gps","manual"]'
    AFTER `is_active`,
  ADD COLUMN `manual_attendance_admin_ids` JSON DEFAULT NULL
    COMMENT 'NULL = all admins with manage_attendance permission; array of admin IDs = restricted set'
    AFTER `attendance_methods`;

-- Backfill: every existing tenant gets qr_gps + manual enabled by default
UPDATE `tenants`
  SET `attendance_methods` = JSON_ARRAY('qr_gps', 'manual')
  WHERE JSON_TYPE(`attendance_methods`) IS NULL
     OR `attendance_methods` = '';

-- 2) branches: drop old ENUM, add JSON column (NULL = inherit tenant)
ALTER TABLE `branches`
  DROP COLUMN `attendance_method`,
  ADD COLUMN `attendance_methods` JSON DEFAULT NULL
    COMMENT 'NULL = inherits tenant; array of methods = override'
    AFTER `qr_code`;
