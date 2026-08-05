-- ============================================================
-- Migration: branch kiosk — identification attempt log
-- Date: 2026-08-03
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- Every attempt by a person at a kiosk to be identified, INCLUDING the ones
-- that identify nobody. Restores a table name the removed station system used.
--
-- Why this is not `face_verification_logs` with a wider enum — two structural
-- blockers, both real:
--
--   1. face_verification_logs.employee_id is NOT NULL. The single most
--      important row this feature records — a one-to-many attempt that matched
--      nobody — has no employee.
--   2. Its `result` enum has no value for the one-to-many outcomes: ambiguous
--      (the margin rule failed), no_match, or out_of_branch.
--
-- Widening that table would also degrade something app/attendance/face_logs.php
-- already reads for threshold tuning. Same reasoning rules out
-- attendance_security_logs, whose employee_id is likewise NOT NULL with an FK.
--
-- ---- The margin rule, and why two scores are stored -------------------------
--
-- The employee app verifies ONE known person against ONE threshold (1:1). A
-- kiosk resolves an unknown face against the whole branch roster (1:N), and
-- false-accept risk compounds: at a per-comparison FAR of p, scanning N
-- candidates gives roughly 1 - (1-p)^N. At the 0.450 threshold FaceMatchService
-- ships with, 200 candidates is about a one-in-three chance of a wrong match.
--
-- So a match is accepted only when the best candidate clears the threshold AND
-- beats the runner-up by a margin. `runner_up_score` and `candidates_searched`
-- are stored on every row so that rule can be audited after the fact and the
-- operating point tuned on real data rather than on LFW figures.
--
-- MySQL 8: no additive ENUM syntax. Run once, in order.

CREATE TABLE `station_recognition_logs` (
  `id`                  bigint unsigned NOT NULL AUTO_INCREMENT
                        COMMENT 'bigint: one row per ATTEMPT, not per punch — the fastest-growing table in this feature',
  `tenant_id`           int unsigned NOT NULL,
  `station_id`          int unsigned NOT NULL,
  `branch_id`           int unsigned NOT NULL COMMENT 'Denormalised for reporting',
  `employee_id`         int unsigned DEFAULT NULL
                        COMMENT 'NULL when nobody was identified — the whole reason this table exists',
  `purpose`             enum('check_in','check_out','enroll') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'check_in',
  `method`              enum('face','code') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'face',
  `result`              enum(
                          'matched','ambiguous','no_match','below_threshold',
                          'liveness_failed','out_of_branch','spoofing_suspected',
                          'not_enrolled','wrong_method','too_soon','out_of_range',
                          'bad_embedding','model_mismatch'
                        ) COLLATE utf8mb4_unicode_ci NOT NULL,
  `accepted`            tinyint(1) NOT NULL DEFAULT '0'
                        COMMENT 'Whether a punch was allowed through; 0 in log_only even when result=matched',
  `match_score`         decimal(4,3) DEFAULT NULL COMMENT 'Best candidate cosine similarity',
  `runner_up_score`     decimal(4,3) DEFAULT NULL COMMENT 'Second best — makes the margin rule auditable',
  `threshold`           decimal(4,3) DEFAULT NULL COMMENT 'Value in force at the time',
  `margin`              decimal(4,3) DEFAULT NULL COMMENT 'Value in force at the time',
  `candidates_searched` smallint unsigned DEFAULT NULL
                        COMMENT 'Roster size at the moment of the attempt — correlate mis-attribution with N',
  `liveness_passed`     tinyint(1) NOT NULL DEFAULT '0',
  `challenge`           varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `capture_path`        varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL
                        COMMENT 'Evidence image; NULL once purged, or never set for an unflagged failed attempt',
  `capture_expires_at`  datetime DEFAULT NULL
                        COMMENT 'Computed in SQL. The purge unlinks the file and nulls capture_path; the row and its scores survive for tuning',
  `latitude`            decimal(10,7) DEFAULT NULL,
  `longitude`           decimal(10,7) DEFAULT NULL,
  `attendance_id`       int unsigned DEFAULT NULL COMMENT 'Set when the attempt produced a punch',
  `created_at`          timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_srl_station` (`station_id`,`created_at`),
  KEY `idx_srl_employee` (`tenant_id`,`employee_id`,`created_at`),
  KEY `idx_srl_result` (`tenant_id`,`result`,`created_at`),
  KEY `idx_srl_purge` (`capture_expires_at`),
  CONSTRAINT `srl_ibfk_tenant` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `srl_ibfk_station` FOREIGN KEY (`station_id`) REFERENCES `attendance_stations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- No FK on employee_id: it is nullable by design, and a deleted employee must
-- not erase the record that somebody was refused at a door.
