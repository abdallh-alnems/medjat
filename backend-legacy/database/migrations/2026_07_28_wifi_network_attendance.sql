-- ============================================================
-- Migration: WiFi-network attendance method (wifi_gps)
-- Date: 2026-07-28
-- ============================================================
--
-- Adds `wifi_gps`: on top of the existing GPS/geofence check, the employee
-- must be connected to one of the branch's approved access points.
--
-- WiFi proves the DEVICE is indoors at the branch — it closes the gap where
-- GPS drifts 50-100m inside a concrete building. It does not prove WHO is
-- holding the phone; that is what face_selfie is for.
--
-- Run manually on the live MySQL 8 database (migrations are not auto-applied).

-- ------------------------------------------------------------
-- 1) Method enum values
-- ------------------------------------------------------------
ALTER TABLE `attendance`
  MODIFY COLUMN `check_in_method`
    enum('qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','manual','kiosk','offline')
    COLLATE utf8mb4_unicode_ci DEFAULT 'qr_gps',
  MODIFY COLUMN `check_out_method`
    enum('qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','manual','kiosk','offline','auto')
    COLLATE utf8mb4_unicode_ci DEFAULT NULL;

-- ------------------------------------------------------------
-- 2) Per-branch WiFi configuration
-- ------------------------------------------------------------
-- `wifi_mode` NULL means the branch has never used the method. A branch that
-- enables it always starts in 'learning': enforcing straight away, before any
-- network has been approved, would lock the entire company out.
ALTER TABLE `branches`
  ADD COLUMN `wifi_mode` enum('learning','enforcing','optional') COLLATE utf8mb4_unicode_ci
    DEFAULT NULL
    COMMENT 'learning = record only; enforcing = reject unknown networks; optional = GPS or WiFi',
  ADD COLUMN `wifi_match` enum('bssid','ip','either') COLLATE utf8mb4_unicode_ci
    NOT NULL DEFAULT 'bssid'
    COMMENT 'bssid = access point MAC; ip = public egress IP (works on iOS without entitlement)';

-- ------------------------------------------------------------
-- 3) Approved networks — the source of truth the check-in path reads
-- ------------------------------------------------------------
-- One physical router usually broadcasts SEVERAL BSSIDs (2.4GHz, 5GHz, guest
-- SSID), so a branch needs a list, not a single value. Storing them as rows
-- rather than a JSON column keeps each one individually labelled, deactivatable
-- and auditable when a router is replaced.
CREATE TABLE IF NOT EXISTS `branch_networks` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned NOT NULL,
  `kind` enum('bssid','ip_v4','ip_cidr') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'bssid',
  `value` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL
    COMMENT 'BSSID normalised to lower-case colon form, or an IPv4 / CIDR',
  `label` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `source` enum('captured','discovered','manual') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'discovered',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `approved_by` int unsigned DEFAULT NULL,
  `approved_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_branch_network` (`tenant_id`,`branch_id`,`kind`,`value`),
  KEY `idx_branch_network_lookup` (`tenant_id`,`branch_id`,`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4) Sightings — raw observations that feed the approval screen
-- ------------------------------------------------------------
-- Kept separate from branch_networks on purpose: this table grows with every
-- check-in and is pruned, while branch_networks stays small and is read on the
-- hot check-in path.
--
-- `inside_geofence` is the column that makes the whole feature work: it is what
-- separates "the office router" from "an employee's home router seen once
-- during the learning week".
CREATE TABLE IF NOT EXISTS `branch_network_sightings` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `branch_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `bssid` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ssid` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `client_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `inside_geofence` tinyint(1) NOT NULL DEFAULT '0',
  `distance_meters` int DEFAULT NULL,
  `seen_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_sighting_branch` (`tenant_id`,`branch_id`,`seen_at`),
  KEY `idx_sighting_bssid` (`tenant_id`,`branch_id`,`bssid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
