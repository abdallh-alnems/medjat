-- ============================================
-- Migration: lower the face-match threshold default 0.650 -> 0.450
-- Date: 2026-08-02
-- ============================================
--
-- 0.650 was picked before there was a model to measure it against. The model
-- shipped on 2026-08-01 (assets/models/mobilefacenet.tflite) and was then
-- measured on 800 standard LFW pairs:
--
--   same person       mean cosine 0.597
--   different people  mean cosine 0.044
--
--   threshold   impostor accepted   employee rejected
--     0.650           0.0%               52.5%     <- what we shipped with
--     0.450           0.2%               19.2%     <- this migration
--     0.300           4.2%                6.5%
--
-- At 0.650 a company switching to `enforce` would have blocked roughly half of
-- its genuine check-ins. That is not a tuning preference, it is a broken
-- default, so it changes for everyone rather than waiting to be discovered one
-- company at a time.
--
-- LFW is harsher than a deliberate front-facing check-in selfie (press photos,
-- varied lighting and pose), so the real false-reject rate should be lower.
-- 0.450 is a starting point, NOT a tuned value: every company should still run
-- in face_enforce_mode = 'log_only', read its own distribution from
-- face_verification_logs via app/attendance/face_logs.php, and set its own
-- threshold before enforcing.
--
-- The UPDATE is safe to apply wholesale today: all 6 tenants still hold the
-- untouched 0.650 default, none has enrolled a single face, and every one is in
-- log_only — so nobody has deliberately chosen this number and no live decision
-- changes. It is scoped to rows still at exactly 0.650 so that a company that
-- later tunes to that value on purpose is never silently overwritten by a
-- re-run.
--
-- branches.face_match_threshold is nullable and inherits the tenant, so it
-- needs no change; no branch currently sets an override.
--
-- MySQL 8 (live): ALTER ... MODIFY replaces the column definition wholesale,
-- so the type and NOT NULL are restated in full.

ALTER TABLE `tenants`
  MODIFY COLUMN `face_match_threshold` decimal(4,3) NOT NULL DEFAULT 0.450
  COMMENT 'Minimum cosine similarity to accept a face match (see migration 2026_08_02)';

UPDATE `tenants`
   SET `face_match_threshold` = 0.450
 WHERE `face_match_threshold` = 0.650;
