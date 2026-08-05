-- ============================================================
-- Migration: branch kiosk — enum widening and punch idempotency
-- Date: 2026-08-03
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- The only file in this feature that rewrites existing tables. Split out from
-- the others so a failure here cannot strand half-created new tables.
--
-- MySQL 8 has no additive ENUM syntax, so each enum is RE-STATED IN FULL with
-- its existing values first and unchanged. No stored row is invalidated.
--
-- Note on what is NOT here: `attendance.check_in_method` and `check_out_method`
-- already contain 'kiosk', and `attendance.recognition_method` already contains
-- 'station_face'. Both survived the 2026-06 removal and need no change.

-- ------------------------------------------------------------
-- 1) attendance_security_logs.reason — kiosk refusals
-- ------------------------------------------------------------
-- Existing six values preserved in order, six kiosk values appended.
--
-- IMPORTANT — this table cannot record every kiosk refusal, and must not be
-- made to. `employee_id` here is NOT NULL with an FK to employees, so an
-- attempt that identified NOBODY has no row to write. Those live in
-- station_recognition_logs, which allows a null employee. Only refusals that
-- resolve to a known employee are mirrored here, so this table keeps its
-- meaning: "something was blocked or flagged for a specific person".
--
-- Do not relax that FK to accommodate the kiosk — it would weaken an existing
-- guarantee for a different channel's convenience.
ALTER TABLE `attendance_security_logs`
  MODIFY COLUMN `reason` enum(
    'mock_location','rooted','jailbroken','vpn','gps_out_of_range','no_local_biometric',
    'kiosk_ambiguous_match','kiosk_spoofing_suspected','kiosk_out_of_branch',
    'kiosk_pin_bruteforce','kiosk_revoked_token','kiosk_version_blocked'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;

-- ------------------------------------------------------------
-- 2) face_challenges.employee_id — nullable
-- ------------------------------------------------------------
-- The selfie flow issues a liveness challenge to a KNOWN employee: the phone is
-- already signed in as them. A kiosk issues one before anybody has been
-- identified — that is the entire point of one-to-many — so the column cannot
-- stay NOT NULL.
--
-- Widening a constraint invalidates no existing row.
ALTER TABLE `face_challenges`
  MODIFY COLUMN `employee_id` int unsigned DEFAULT NULL
    COMMENT 'NULL for kiosk challenges: at challenge time the identity is not yet known';

-- The `purpose` enum already carries 'check_in','check_out','enroll', so
-- kiosk-side enrollment needs no change there.

-- ------------------------------------------------------------
-- 3) attendance.kiosk_idempotency_key — safe retry
-- ------------------------------------------------------------
-- There is no offline queue on a kiosk: identification requires the server, so
-- nothing can be queued. The one case that still needs care is a request that
-- was sent and whose RESPONSE was lost — the employee cannot tell whether their
-- punch registered, and a naive retry would double-punch them.
--
-- The client generates a key per punch and replays it verbatim on retry. The
-- unique index makes the second write collide, and the handler returns the
-- ORIGINAL result with 200. From the employee's side a retry is
-- indistinguishable from a success, which is the point.
--
-- A UNIQUE index over a NULLable column allows unlimited non-kiosk rows
-- (MySQL treats NULLs as distinct) while making a replayed kiosk punch a no-op.
ALTER TABLE `attendance`
  ADD COLUMN `kiosk_idempotency_key` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Client-generated per punch so a retried kiosk request cannot double-insert',
  ADD UNIQUE KEY `uniq_att_kiosk_idem` (`kiosk_idempotency_key`);
