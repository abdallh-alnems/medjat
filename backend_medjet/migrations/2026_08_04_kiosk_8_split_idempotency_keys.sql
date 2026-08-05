-- ============================================================
-- Migration: branch kiosk — separate idempotency keys per direction
-- Date: 2026-08-04
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- Corrects a design fault in 2026_08_03_kiosk_4_enum_widening.sql, found by an
-- end-to-end test rather than by reading.
--
-- That migration added ONE `kiosk_idempotency_key` to `attendance`. But
-- attendance is one row per employee per day carrying BOTH a check-in and a
-- check-out, and each is a separate punch with its own client-generated key.
-- The check-out therefore overwrote the check-in's key, and with it the
-- guarantee the column exists to provide: after checking out, a retried
-- check-in would no longer be recognised as a replay and would be treated as a
-- fresh punch.
--
-- The failure needed a check-in and a check-out on the same day to appear, so it
-- would have reached production and shown up as duplicated morning punches on
-- days when somebody's connection dropped twice.
--
-- Two columns, each independently unique. The old column is left in place and
-- unused, per the additive-only rule; nothing has shipped that reads it.
--
-- MySQL 8: no "ADD COLUMN IF NOT EXISTS". Run once, in order.

ALTER TABLE `attendance`
  ADD COLUMN `kiosk_checkin_idem_key` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Client-generated key for the check-in punch; a retry collides and replays',
  ADD COLUMN `kiosk_checkout_idem_key` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Client-generated key for the check-out punch',
  ADD UNIQUE KEY `uniq_att_kiosk_idem_in` (`kiosk_checkin_idem_key`),
  ADD UNIQUE KEY `uniq_att_kiosk_idem_out` (`kiosk_checkout_idem_key`);

-- A UNIQUE index over a NULLable column allows unlimited non-kiosk rows, since
-- MySQL treats NULLs as distinct, while making a replayed punch a no-op.
