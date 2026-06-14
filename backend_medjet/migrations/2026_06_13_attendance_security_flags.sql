-- ============================================
-- Migration: device-integrity flags on attendance (is_vpn etc.)
-- Date: 2026-06-13
-- ============================================
--
-- AttendanceModel::checkIn inserts `is_vpn`, and the security/sync paths read
-- is_mock_location / is_rooted_device. These columns exist in schema.sql but
-- were never applied to some live/local DBs — without them every check-in
-- errors with "Unknown column 'is_vpn'". Add the three advisory flags.
--
-- MySQL 8 (live) has no "ADD COLUMN IF NOT EXISTS"; run once by hand.

ALTER TABLE `attendance`
  ADD COLUMN `is_vpn` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'VPN detected on device at check-in (advisory)' AFTER `is_offline`,
  ADD COLUMN `is_mock_location` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Mock-location flag reported by client (advisory)' AFTER `is_vpn`,
  ADD COLUMN `is_rooted_device` tinyint(1) NOT NULL DEFAULT '0' COMMENT 'Root/jailbreak flag reported by client (advisory)' AFTER `is_mock_location`;
