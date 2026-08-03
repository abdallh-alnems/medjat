-- ============================================
-- Migration: create the missing `attendance_security_logs` table
-- Date: 2026-07-31
-- ============================================
--
-- The table is defined in schema.sql but has never existed in production: the
-- live DB was cloned from the old Hostinger database and the dated migrations
-- were deliberately not replayed on top of it, so this one was never created.
--
-- Consequence today: AttendanceSecurityModel::log() wraps its INSERT in a
-- try/catch and only error_log()s the failure, so every blocked/flagged
-- attempt — including the ones the employee app already reports through
-- app/attendance/security_log.php — is silently discarded. There is no record
-- of any tampering attempt anywhere.
--
-- This is also a prerequisite for rejecting mock GPS server-side
-- (2026_07_31_reject_mock_location.sql): rejecting employees without an audit
-- trail leaves HR with no way to see why someone was turned away.
--
-- MySQL 8 supports CREATE TABLE IF NOT EXISTS (unlike ADD COLUMN IF NOT EXISTS),
-- so this is safe to run more than once.

CREATE TABLE IF NOT EXISTS `attendance_security_logs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `reason` enum('mock_location','rooted','jailbroken','vpn','gps_out_of_range') COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` enum('blocked','flagged') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'blocked',
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `platform` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'android | ios',
  `app_version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_seclog_tenant_date` (`tenant_id`,`created_at`),
  KEY `idx_seclog_employee` (`employee_id`),
  CONSTRAINT `seclog_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `seclog_ibfk_2` FOREIGN KEY (`employee_id`) REFERENCES `employees` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
