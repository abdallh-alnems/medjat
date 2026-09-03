-- ============================================================
-- Migration: branch kiosk — station identity, credentials, codes
-- Date: 2026-08-03
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- A kiosk is a shared tablet mounted at a branch door, so employees without
-- smartphones can record their own attendance. It is a THIRD authentication
-- principal alongside the administrator (Firebase token) and the employee
-- (X-Employee-Token): a kiosk credential acts for a BRANCH, not for a person,
-- and can record attendance for anyone enrolled at that branch. Everything
-- below follows from that difference — the credential is bound to one branch,
-- it is revocable, and it is never an employee token.
--
-- Permedjat had a station/kiosk system before; it was removed in 2026-06 but only
-- half the removal was applied. `branches.station_*`, `attendance.station_id`,
-- `attendance.recognition_confidence`, the `station_*` values in
-- `attendance.recognition_method`, and `'kiosk'` in the check_in/check_out
-- method enums are all still live and are REUSED here. Only the dropped tables
-- are rebuilt. See migrations/archive/2026_06_14_remove_kiosk_system.sql.
--
-- MySQL 8: no "ADD COLUMN IF NOT EXISTS", no additive ENUM syntax.
-- Applied by deploy.sh / migrate.sh, which record it in schema_migrations.

-- ------------------------------------------------------------
-- 1) attendance_stations — one row per tablet in service
-- ------------------------------------------------------------
-- Modelled on `attendance_devices` (the ZKTeco terminal table), which solves
-- the same problem: a physical device bound to a branch, claimed by a human,
-- reporting in over time. The differences are that a kiosk is born bound (there
-- is no "unclaimed" state — the pairing exchange creates the row) and that it
-- authenticates with a token rather than a serial number.
CREATE TABLE `attendance_stations` (
  `id`            int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id`     int unsigned NOT NULL,
  `branch_id`     int unsigned NOT NULL,
  `name`          varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL
                  COMMENT 'Set at pairing, e.g. "Main gate"',
  `status`        enum('active','revoked') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active'
                  COMMENT 'Revocation is a state, never a delete: attendance.station_id must not be orphaned',
  `device_model`  varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `platform`      varchar(20)  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'android'
                  COMMENT 'Reserved for a future iPad build; Android only for now',
  `app_version`   varchar(20)  COLLATE utf8mb4_unicode_ci DEFAULT NULL
                  COMMENT 'Reported on every heartbeat; drives the minimum-version gate',
  `last_seen_at`  datetime DEFAULT NULL
                  COMMENT 'Stale during working hours = a dark kiosk, which management is alerted about',
  `last_ip`       varchar(45)  COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_punch_at` datetime DEFAULT NULL,
  `punch_count`   int unsigned NOT NULL DEFAULT '0',
  `paired_by`     int unsigned DEFAULT NULL COMMENT 'employees.id of the administrator',
  `paired_at`     datetime DEFAULT NULL,
  `revoked_by`    int unsigned DEFAULT NULL,
  `revoked_at`    datetime DEFAULT NULL,
  `created_at`    timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_station_tenant` (`tenant_id`,`status`),
  KEY `idx_station_branch` (`branch_id`,`status`),
  KEY `idx_station_last_seen` (`last_seen_at`),
  CONSTRAINT `station_ibfk_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `station_ibfk_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 2) kiosk_auth_tokens — the credential the tablet presents
-- ------------------------------------------------------------
-- Mirrors `employee_auth_tokens`, including its trick for "one live token per
-- owner": because MySQL treats NULLs as distinct in a UNIQUE index, the key on
-- (station_id, revoked_at) permits unlimited revoked rows but only one row with
-- revoked_at IS NULL.
--
-- Only the SHA-256 of the token is stored. The plaintext is returned once, at
-- pairing, and never again — a database read must not yield a working
-- credential for a device that can punch on behalf of a whole branch.
CREATE TABLE `kiosk_auth_tokens` (
  `id`            int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id`     int unsigned NOT NULL,
  `station_id`    int unsigned NOT NULL,
  `token_hash`    varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'SHA-256 of the opaque token',
  `device_id`     varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Stable per tablet install',
  `issued_at`     timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `last_used_at`  timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `revoked_at`    timestamp NULL DEFAULT NULL,
  `revoke_reason` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL
                  COMMENT 'unpaired | branch_deleted | replaced',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_kiosk_token_hash` (`token_hash`),
  UNIQUE KEY `uniq_active_token_per_station` (`station_id`,`revoked_at`),
  KEY `idx_kiosk_token_tenant` (`tenant_id`),
  CONSTRAINT `kiosk_token_ibfk_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `kiosk_token_ibfk_station` FOREIGN KEY (`station_id`) REFERENCES `attendance_stations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3) kiosk_codes — both short-lived secrets, one table
-- ------------------------------------------------------------
-- Two purposes that share every property except what they open:
--
--   'pair'   brings an unconfigured tablet into service as a station.
--            station_id is NULL — no station exists yet.
--   'access' opens the administration area of a tablet ALREADY in service:
--            enrollment, kiosk settings, and release of kiosk mode.
--
-- Both are single-use and short-lived (pair ~15 min, access ~5 min), and both
-- are stored HASHED. That last point is the difference from
-- `employee_activation_codes`, which stores its code in plaintext: an access
-- code enrolls faces and unlocks the tablet, so reading the table must not hand
-- anybody a working key.
--
-- The old system's `branches.station_admin_pin_hash` (a STATIC per-branch PIN)
-- is superseded by this table and deliberately left unused: a static PIN gets
-- shared once and works forever.
CREATE TABLE `kiosk_codes` (
  `id`              int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id`       int unsigned NOT NULL,
  `branch_id`       int unsigned NOT NULL,
  `station_id`      int unsigned DEFAULT NULL COMMENT 'NULL for purpose=pair; set for purpose=access',
  `purpose`         enum('pair','access') COLLATE utf8mb4_unicode_ci NOT NULL,
  `code_hash`       varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'SHA-256; plaintext shown once and never stored',
  `expires_at`      datetime NOT NULL
                    COMMENT 'ALWAYS computed in SQL: DATE_ADD(NOW(), INTERVAL ? SECOND). PHP runs UTC here and MySQL runs the tenant zone, so a PHP-computed expiry is born expired',
  `used_at`         datetime DEFAULT NULL COMMENT 'Non-null = consumed. Single use',
  `used_by_station` int unsigned DEFAULT NULL,
  `created_by`      int unsigned NOT NULL COMMENT 'employees.id — who authorised it',
  `created_at`      timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_kiosk_code_lookup` (`code_hash`,`used_at`,`expires_at`),
  KEY `idx_kiosk_code_branch` (`branch_id`,`purpose`),
  KEY `idx_kiosk_code_expires` (`expires_at`),
  CONSTRAINT `kiosk_code_ibfk_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `kiosk_code_ibfk_branch` FOREIGN KEY (`branch_id`) REFERENCES `branches` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
