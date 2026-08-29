-- ============================================
-- Migration: company-wide GPS geofence (tenant default)
-- Date: 2026-06-12
-- ============================================
--
-- A company-level GPS center + radius used as the default for GPS/QR+GPS
-- attendance. A branch with its own latitude/longitude overrides it; branches
-- without one fall back to this company location. NULL = not set (no geofence
-- enforced until a center exists).
--
-- MySQL 8 (live) has no "ADD COLUMN IF NOT EXISTS"; run these once by hand.

ALTER TABLE `tenants`
  ADD COLUMN `gps_latitude` DECIMAL(10,7) DEFAULT NULL AFTER `allow_offline_attendance`,
  ADD COLUMN `gps_longitude` DECIMAL(10,7) DEFAULT NULL AFTER `gps_latitude`,
  ADD COLUMN `gps_radius_meters` INT DEFAULT NULL AFTER `gps_longitude`;
