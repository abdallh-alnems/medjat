-- ============================================================
-- Migration: mobile selfie face-recognition attendance method
-- Date: 2026-07-28
-- ============================================================
--
-- Adds the `face_selfie` attendance method: the employee takes a selfie at
-- check-in, the device extracts a face embedding, and the SERVER compares it
-- against the enrolled embedding (cosine similarity) before recording the
-- punch. Liveness is proven by answering a server-issued random challenge.
--
-- Run manually on the live MySQL 8 database (migrations are not auto-applied).
-- MySQL 8 has no "ADD COLUMN IF NOT EXISTS" — run once, in order.

-- ------------------------------------------------------------
-- 1) Attendance method enum values
-- ------------------------------------------------------------
-- `qr_gps_face` already exists (legacy v2 design: QR + GPS + face). The new
-- method is GPS + face without a QR, so it needs its own value.
ALTER TABLE `attendance`
  MODIFY COLUMN `check_in_method`
    enum('qr_gps','gps_only','qr_gps_face','face_selfie','manual','kiosk','offline')
    COLLATE utf8mb4_unicode_ci DEFAULT 'qr_gps',
  MODIFY COLUMN `check_out_method`
    enum('qr_gps','gps_only','qr_gps_face','face_selfie','manual','kiosk','offline','auto')
    COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  MODIFY COLUMN `recognition_method`
    enum('manual','qr_gps','mobile_face','station_face','station_fingerprint','station_both','station_qr')
    COLLATE utf8mb4_unicode_ci DEFAULT NULL;

-- ------------------------------------------------------------
-- 2) Company-level face settings (the inherited defaults)
-- ------------------------------------------------------------
ALTER TABLE `tenants`
  ADD COLUMN `face_match_threshold` decimal(4,3) NOT NULL DEFAULT '0.650'
    COMMENT 'Minimum cosine similarity to accept a face match (0-1)',
  ADD COLUMN `face_liveness_required` tinyint(1) NOT NULL DEFAULT '1'
    COMMENT 'Require the device to pass the server-issued liveness challenge',
  ADD COLUMN `face_enforce_mode` enum('log_only','enforce') COLLATE utf8mb4_unicode_ci
    NOT NULL DEFAULT 'log_only'
    COMMENT 'log_only = record the score but never reject (tuning phase); enforce = reject below threshold';

-- ------------------------------------------------------------
-- 3) Branch overrides (NULL = inherit the company value)
-- ------------------------------------------------------------
ALTER TABLE `branches`
  ADD COLUMN `face_match_threshold` decimal(4,3) DEFAULT NULL,
  ADD COLUMN `face_liveness_required` tinyint(1) DEFAULT NULL;

-- ------------------------------------------------------------
-- 4) Employee enrollment metadata
-- ------------------------------------------------------------
-- `face_photo_url` was dropped in 2026_06_14_drop_frontend_unused_columns.sql;
-- it comes back because the enrolled reference photo is needed for HR audit.
-- `face_model_version` matters: embeddings are only comparable within the same
-- model. Swapping the model invalidates every stored embedding, so the version
-- is recorded per employee and checked at verification time.
ALTER TABLE `employees`
  ADD COLUMN `face_photo_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    AFTER `face_embedding`,
  ADD COLUMN `face_model_version` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Embedding model that produced face_embedding (e.g. mobilefacenet_v1)'
    AFTER `face_photo_url`,
  ADD COLUMN `face_embedding_dim` smallint unsigned DEFAULT NULL
    COMMENT 'Number of dimensions in face_embedding'
    AFTER `face_model_version`;

-- ------------------------------------------------------------
-- 5) Liveness challenges (single-use, short-lived nonces)
-- ------------------------------------------------------------
-- Without a server-issued nonce the client could replay a previously captured
-- embedding forever. Each challenge is consumed by exactly one verification.
CREATE TABLE IF NOT EXISTS `face_challenges` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `nonce` char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `challenge` enum('blink','turn_left','turn_right','smile') COLLATE utf8mb4_unicode_ci NOT NULL,
  `purpose` enum('check_in','check_out','enroll') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'check_in',
  `expires_at` datetime NOT NULL,
  `consumed_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_face_challenge_nonce` (`nonce`),
  KEY `idx_face_challenge_lookup` (`tenant_id`,`employee_id`,`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- 6) Verification audit trail
-- ------------------------------------------------------------
-- Every attempt is logged, accepted or not — this is what makes threshold
-- tuning possible and gives HR something to review when an employee disputes
-- a rejection.
CREATE TABLE IF NOT EXISTS `face_verification_logs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `branch_id` int unsigned DEFAULT NULL,
  `purpose` enum('check_in','check_out') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'check_in',
  `result` enum(
      'matched','below_threshold','liveness_failed','not_enrolled',
      'invalid_challenge','bad_embedding','model_mismatch'
    ) COLLATE utf8mb4_unicode_ci NOT NULL,
  `accepted` tinyint(1) NOT NULL DEFAULT '0'
    COMMENT 'Whether the punch was allowed through (log_only mode accepts below-threshold)',
  `match_score` decimal(4,3) DEFAULT NULL,
  `threshold` decimal(4,3) DEFAULT NULL,
  `liveness_passed` tinyint(1) NOT NULL DEFAULT '0',
  `challenge` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `selfie_path` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_mock_location` tinyint(1) NOT NULL DEFAULT '0',
  `is_rooted_device` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_fvl_employee` (`tenant_id`,`employee_id`,`created_at`),
  KEY `idx_fvl_result` (`tenant_id`,`result`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
