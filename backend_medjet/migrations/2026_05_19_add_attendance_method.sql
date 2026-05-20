-- ============================================
-- Migration: Add attendance_method to tenants & branches
-- Date: 2026-05-19
-- ============================================

-- 1) Tenant-level default attendance method
ALTER TABLE `tenants`
  ADD COLUMN `attendance_method` ENUM('qr_gps','gps_only') NOT NULL DEFAULT 'qr_gps'
  COMMENT 'Default attendance method for the tenant';

-- 2) Branch-level override (NULL = inherit from tenant) + GPS radius
ALTER TABLE `branches`
  ADD COLUMN `attendance_method` ENUM('qr_gps','gps_only') DEFAULT NULL
  COMMENT 'Branch-level override; NULL inherits tenants.attendance_method',
  ADD COLUMN `gps_radius_meters` INT UNSIGNED NOT NULL DEFAULT 100
  COMMENT 'Allowed GPS radius for check-in in meters';
