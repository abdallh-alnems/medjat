-- ============================================================
-- Migration: restore the three web reasons this enum lost to a collision
-- Date: 2026-08-06
-- Fixes: silent data loss on the browser channel, live since 2026-08-03
-- ============================================================
--
-- WHAT HAPPENED
--
-- Two migrations dated the same day both MODIFY `attendance_security_logs`.`reason`,
-- and each restated the enum in full from its own starting point:
--
--   2026_08_03_attendance_punch_photo.sql   (feature 004, web check-in)
--       added  web_not_permitted, web_pin_locked, web_shared_device
--
--   2026_08_03_kiosk_4_enum_widening.sql    (feature 005, branch kiosk)
--       added  kiosk_ambiguous_match, kiosk_spoofing_suspected, kiosk_out_of_branch,
--              kiosk_pin_bruteforce, kiosk_revoked_token, kiosk_version_blocked
--
-- migrate.sh applies files in filename order, and 'a' sorts before 'k', so the
-- kiosk file ran second. MODIFY replaces an enum definition wholesale rather
-- than adding to it, and the kiosk file was written against the enum as it
-- existed BEFORE the web file — so it silently dropped all three web values.
--
-- Verified on production 2026-08-06:
--   enum('mock_location','rooted','jailbroken','vpn','gps_out_of_range',
--        'no_local_biometric','kiosk_ambiguous_match','kiosk_spoofing_suspected',
--        'kiosk_out_of_branch','kiosk_pin_bruteforce','kiosk_revoked_token',
--        'kiosk_version_blocked')
--
-- WHY IT WENT UNNOTICED
--
-- Three shipped code paths write the missing values:
--
--   core/WebAccessPolicy.php          -> web_not_permitted
--   core/SharedDeviceDetector.php     -> web_shared_device
--   app/auth/employee_web_login.php   -> web_pin_locked
--
-- All three go through AttendanceSecurityModel::log(), which wraps the INSERT in
-- try/catch and only calls error_log() on failure. Under MySQL 8's default
-- strict mode an out-of-range enum is an error, so every one of these writes has
-- been thrown away without surfacing anywhere a person would look.
--
-- This is the second time this table has silently discarded refusals — the first
-- was 2026-07-31, when the table did not exist on production at all. The failure
-- mode is identical and the lesson is the same: a security log that fails softly
-- is indistinguishable from a security log with nothing to say.
--
-- THE FIX
--
-- Restate all fifteen values: the six originals, the six kiosk values, and the
-- three web values put back. Widening an enum invalidates no stored row, and no
-- row can currently hold a web value precisely because they were rejected.
--
-- NOTE FOR THE NEXT PERSON: before adding a value to this enum, read the CURRENT
-- definition out of the database rather than out of the most recent migration
-- that touched it. Two features in flight at once is all it takes.

ALTER TABLE `attendance_security_logs`
  MODIFY COLUMN `reason` enum(
    -- originals
    'mock_location',
    'rooted',
    'jailbroken',
    'vpn',
    'gps_out_of_range',
    'no_local_biometric',
    -- branch kiosk (feature 005)
    'kiosk_ambiguous_match',
    'kiosk_spoofing_suspected',
    'kiosk_out_of_branch',
    'kiosk_pin_bruteforce',
    'kiosk_revoked_token',
    'kiosk_version_blocked',
    -- browser channel (feature 004) — restored here
    'web_not_permitted',
    'web_pin_locked',
    'web_shared_device',
    -- rotating branch QR (2026-08-06): a code that was valid but already spent
    -- by this employee, or one that belongs to a different branch.
    'qr_replayed',
    'qr_expired'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;
