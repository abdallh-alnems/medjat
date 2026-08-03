-- ============================================================
-- Migration: biometric attendance devices (ZKTeco ADMS / push)
-- Date: 2026-07-30
-- ============================================================
--
-- Adds the `device` attendance method: a fingerprint/face terminal installed
-- at a branch pushes its punch log to the server over the ZKTeco ADMS "push"
-- protocol (the device opens the connection outwards, so it works behind any
-- customer router with no port forwarding).
--
-- The flow this schema serves:
--   1. HR types the device SERIAL NUMBER into medjat_central -> the row here is
--      claimed by that tenant and bound to one branch.
--   2. HR enrols fingerprints ON THE DEVICE, which assigns each person a
--      numeric "User ID" (PIN). The device pushes its user list to us, so those
--      IDs show up in the app without anyone typing them.
--   3. HR links each device User ID to a Medjat employee (`device_users`).
--   4. Every punch lands in `device_punches` (raw, never lost) and is then
--      applied to the `attendance` table.
--
-- Run manually on the live MySQL 8 database (migrations are not auto-applied).
-- MySQL 8 has no "ADD COLUMN IF NOT EXISTS" — run once, in order.

-- ------------------------------------------------------------
-- 1) Attendance method enum values
-- ------------------------------------------------------------
ALTER TABLE `attendance`
  MODIFY COLUMN `check_in_method`
    enum('qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','device','manual','kiosk','offline')
    COLLATE utf8mb4_unicode_ci DEFAULT 'qr_gps',
  MODIFY COLUMN `check_out_method`
    enum('qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps','device','manual','kiosk','offline','auto')
    COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  MODIFY COLUMN `recognition_method`
    enum('manual','qr_gps','mobile_face','device_fingerprint','device_face','device_card','device_password','station_face','station_fingerprint','station_both','station_qr')
    COLLATE utf8mb4_unicode_ci DEFAULT NULL;

-- ------------------------------------------------------------
-- 2) The devices themselves
-- ------------------------------------------------------------
-- `tenant_id` is NULLABLE on purpose, which is the one place in this schema
-- that departs from the usual multi-tenant rule. A device that has been
-- powered on and pointed at us starts talking BEFORE anyone claims it, and
-- throwing that first contact away would make the app unable to answer the
-- only question HR actually asks: "did the thing connect or not?". An
-- unclaimed row carries no tenant data — just a serial number and a timestamp.
--
-- The UNIQUE serial number is what makes claiming safe: the first tenant to
-- enter it owns it, and a second tenant entering the same serial is rejected
-- rather than silently stealing another company's punches.
CREATE TABLE IF NOT EXISTS `attendance_devices` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `serial_number` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL
    COMMENT 'SN as reported by the device, upper-cased',
  `name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `vendor` enum('zkteco','hikvision','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'zkteco',
  `model` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `firmware` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('unclaimed','active','disabled') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unclaimed',

  -- How to read the in/out direction of a punch.
  -- 'auto'          = first punch of the day is the check-in, the last one is
  --                   the check-out. This is what real deployments need,
  --                   because staff almost never press the F1/F2 function keys.
  -- 'device_status' = trust the status byte the device sends.
  `direction_mode` enum('auto','device_status') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto',

  -- Two punches from the same person closer together than this are treated as
  -- one (people tap twice when the beep is late).
  `min_interval_seconds` smallint unsigned NOT NULL DEFAULT '60',

  -- Correction for a device whose own clock is wrong. The device sits at the
  -- branch, so its wall clock is already the company's local time; this is only
  -- a nudge, not a timezone conversion.
  `clock_offset_minutes` smallint NOT NULL DEFAULT '0',

  -- Punches for a User ID nobody has linked yet: keep them (default) so they
  -- can be replayed onto the employee the moment the link is made.
  `keep_unmatched` tinyint(1) NOT NULL DEFAULT '1',

  -- Verbose protocol capture, for bringing a new device model up. Self-limiting
  -- (see device_protocol_logs) and off by default.
  `debug_logging` tinyint(1) NOT NULL DEFAULT '0',

  `last_seen_at` datetime DEFAULT NULL,
  `last_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `last_punch_at` datetime DEFAULT NULL,
  `user_count` smallint unsigned DEFAULT NULL COMMENT 'As last reported by the device',
  `claimed_by` int unsigned DEFAULT NULL,
  `claimed_at` datetime DEFAULT NULL,
  `first_seen_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_device_serial` (`serial_number`),
  KEY `idx_device_tenant` (`tenant_id`,`status`),
  KEY `idx_device_branch` (`tenant_id`,`branch_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 3) Device User ID -> Medjat employee
-- ------------------------------------------------------------
-- Mapped PER DEVICE, not per tenant: every terminal numbers its users from 1,
-- so "user 3" on the factory device and "user 3" on the office device are
-- different people.
--
-- `employee_id` is nullable because rows appear here the moment the device
-- reports a user, i.e. before HR has said who that is. An unlinked row is
-- exactly the "waiting to be linked" list the app shows.
--
-- `tenant_id` is nullable for the same reason it is on `attendance_devices`:
-- a terminal that is mounted and enrolled before anyone types its serial into
-- the app pushes its user list straight away, and that list is worth keeping —
-- it is what makes the linking screen non-empty on day one. register.php
-- stamps the tenant onto these rows at claim time.
CREATE TABLE IF NOT EXISTS `device_users` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL,
  `device_id` int unsigned NOT NULL,
  `device_user_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL
    COMMENT 'The PIN / User ID as stored on the device',
  `device_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Name as typed into the device, shown to help HR match people',
  `employee_id` int unsigned DEFAULT NULL,
  `card_number` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `privilege` tinyint unsigned DEFAULT NULL COMMENT '0 = user, 14 = device admin',
  `is_active` tinyint(1) NOT NULL DEFAULT '1',
  `linked_by` int unsigned DEFAULT NULL,
  `linked_at` datetime DEFAULT NULL,
  `last_punch_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_device_user` (`device_id`,`device_user_id`),
  KEY `idx_device_user_employee` (`tenant_id`,`employee_id`),
  KEY `idx_device_user_pending` (`tenant_id`,`device_id`,`employee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 4) Raw punches
-- ------------------------------------------------------------
-- Every line the device sends is stored here verbatim BEFORE anything is done
-- with it. The device deletes its local copy once we answer OK, so this table
-- is the only surviving record — it must never reject a row for a business
-- reason. Whether the punch could be turned into attendance is a `state`, not
-- a reason to drop it.
--
-- The unique key is the deduplicator: ZK terminals re-send their whole buffer
-- whenever the transfer stamp is lost (power cut, firmware reset), and the same
-- person cannot punch twice in the same second anyway.
CREATE TABLE IF NOT EXISTS `device_punches` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned DEFAULT NULL,
  `device_id` int unsigned NOT NULL,
  `device_user_id` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `employee_id` int unsigned DEFAULT NULL,
  `punched_at` datetime NOT NULL COMMENT 'Company local time (device wall clock + clock_offset_minutes)',
  `status_code` tinyint unsigned DEFAULT NULL COMMENT '0 in, 1 out, 2/3 break, 4/5 overtime',
  `verify_mode` tinyint unsigned DEFAULT NULL COMMENT '1 fingerprint, 4 card, 15 face, 0 password',
  `work_code` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `direction` enum('in','out') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `state` enum('applied','duplicate','unmatched','ignored','failed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unmatched',
  `note` varchar(191) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attendance_id` int unsigned DEFAULT NULL,
  `raw_line` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `received_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_device_punch` (`device_id`,`device_user_id`,`punched_at`),
  KEY `idx_punch_tenant_time` (`tenant_id`,`punched_at`),
  KEY `idx_punch_employee` (`tenant_id`,`employee_id`,`punched_at`),
  KEY `idx_punch_state` (`device_id`,`state`,`punched_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 5) Outbound command queue
-- ------------------------------------------------------------
-- The server never dials the device; it leaves commands here and the device
-- collects them on its next poll (a few seconds). Used for "fix the clock",
-- "reboot", "tell me your info", and later for pushing users down.
CREATE TABLE IF NOT EXISTS `device_commands` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `device_id` int unsigned NOT NULL,
  `kind` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'sync_time, reboot, info, delete_user',
  `payload` text COLLATE utf8mb4_unicode_ci COMMENT 'The literal command line sent to the device',
  `state` enum('queued','sent','done','failed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'queued',
  `result_code` varchar(16) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `sent_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `created_by` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_command_queue` (`device_id`,`state`,`id`),
  KEY `idx_command_tenant` (`tenant_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6) Protocol debug log
-- ------------------------------------------------------------
-- Firmware differs between ZK models in small, undocumented ways. When a new
-- model refuses to talk, the only thing that helps is seeing exactly what it
-- sent. Written only while `attendance_devices.debug_logging` is on, and
-- pruned by the ingestor so it can never grow without bound.
CREATE TABLE IF NOT EXISTS `device_protocol_logs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `device_id` int unsigned DEFAULT NULL,
  `serial_number` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `method` varchar(8) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `path` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `query_string` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `body` text COLLATE utf8mb4_unicode_ci,
  `response` text COLLATE utf8mb4_unicode_ci,
  `client_ip` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_protocol_device` (`device_id`,`id`),
  KEY `idx_protocol_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 7) Company + branch opt-in
-- ------------------------------------------------------------
-- 'device' joins the attendance-method list so a branch can be set to
-- device-only, which is how the employee app gets told to stop offering self
-- check-in there. The device path itself does NOT consult the resolver: a
-- claimed device plus an explicit User ID link is its own authorisation.
--
-- Nothing to add for the methods themselves (they live in the JSON columns
-- `tenants.attendance_methods` / `branches.attendance_methods` /
-- `employee_categories.attendance_methods` / `employees.attendance_methods`),
-- but AttendanceMethodResolver::ALLOWED must list 'device' — see the PHP side.
