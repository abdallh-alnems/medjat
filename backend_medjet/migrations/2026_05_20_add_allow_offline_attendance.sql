-- ============================================
-- Migration: Add allow_offline_attendance to tenants & branches
-- Date: 2026-05-20
-- ============================================

ALTER TABLE `tenants`
  ADD COLUMN `allow_offline_attendance` TINYINT(1) NOT NULL DEFAULT 1
    COMMENT 'Company-level toggle for offline attendance capture'
    AFTER `manual_attendance_admin_ids`;

ALTER TABLE `branches`
  ADD COLUMN `allow_offline_attendance` TINYINT(1) DEFAULT NULL
    COMMENT 'NULL = inherit tenant; 1 = forced on; 0 = forced off'
    AFTER `station_anti_spoofing_enabled`;
