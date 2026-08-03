-- ============================================
-- Migration: per-company opt-in rejection of mocked GPS locations
-- Date: 2026-07-31
-- ============================================
--
-- The employee app already detects a mocked location and refuses to check in,
-- but that check runs on the employee's own phone — a patched APK simply skips
-- it. The server receives `is_mock_location` in the check-in payload and has
-- never read it (only `is_vpn` was consumed), so a spoofed location is accepted
-- without question.
--
-- This adds the server-side switch. DEFAULT 0 so deploying it changes nothing
-- for existing companies; each one opts in from company settings.
--
-- Deliberately NOT added: a matching switch for `is_rooted_device`. Rooting is
-- common on cheap Android handsets and is not evidence of cheating, so blocking
-- on it would lock out honest employees. Mock location is the precise signal.
--
-- Note the limits of this control before enabling it for a customer:
--   * the flag is client-reported, so it stops an off-the-shelf "Fake GPS" app
--     but not someone who has patched the APK to report 0;
--   * iOS never reports it (Apple exposes no equivalent API), so this is an
--     Android-only protection.
-- Proving *identity* rather than location is what face_selfie is for.
--
-- MySQL 8 (live) has no "ADD COLUMN IF NOT EXISTS" — run once by hand.

ALTER TABLE `tenants`
  ADD COLUMN `reject_mock_location` tinyint(1) NOT NULL DEFAULT 0
  COMMENT 'Reject check-in/out when the device reports a mocked GPS location (Android only)'
  AFTER `allow_offline_attendance`;
