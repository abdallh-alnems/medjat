-- ============================================================
-- Migration: record the browser channel's network refusals
-- Date: 2026-08-25
-- ============================================================
--
-- WHY
--
-- spec 004 counts network restriction among the compensating controls that make
-- the browser — the weakest verification channel in the product — acceptable at
-- all. web_status.php has been announcing that control to the page since the
-- feature shipped, reporting `network_constraint: 'ip'` whenever a branch had an
-- approved IP row.
--
-- Nothing ever applied it. The only call to NetworkVerifier on the punch path is
-- gated on `method === 'wifi_gps'`, and a browser never sends that method: the
-- page posts no `method` at all, so check_in.php resolves it as 'gps_only'. The
-- control existed on the screen and nowhere else, for every browser punch since
-- 2026-08-15.
--
-- core/NetworkVerifier::verifyBrowser() now applies it, and this is the reason
-- code its refusals are logged under. A blocked attempt that leaves no trace is
-- the failure this table exists to end.
--
-- WHY A SEPARATE VALUE FROM THE WiFi ONES
--
-- 'wrong_network' would read as the wifi_gps refusal an app punch produces, and
-- the two are not the same evidence: the app was matched on the access point it
-- is joined to, the browser only on an IP address. Anyone reading these rows to
-- tune a branch's approved list needs to tell them apart.
--
-- ENUM VALUES READ FROM PRODUCTION on 2026-08-25, not from the last migration
-- that touched this column — the note at the bottom of
-- 2026_08_06_restore_web_security_log_reasons.sql explains what that distinction
-- already cost this codebase once. Verified live:
--
--   enum('mock_location','rooted','jailbroken','vpn','gps_out_of_range',
--        'no_local_biometric','kiosk_ambiguous_match','kiosk_spoofing_suspected',
--        'kiosk_out_of_branch','kiosk_pin_bruteforce','kiosk_revoked_token',
--        'kiosk_version_blocked','web_not_permitted','web_pin_locked',
--        'web_shared_device','qr_replayed','qr_expired','crew_not_supervisor',
--        'replayed_embedding')
--
-- Nineteen values restated below, plus the new one. Widening an enum invalidates
-- no stored row.
--
-- A TRAP LEFT BEHIND, for whoever bootstraps an empty database:
-- migrate.sh applies files in filename order, and among the 2026_08_06 files
-- 'restore…' sorts AFTER 'crew_attendance' and 'face_replay_detection' while
-- restating an enum that predates both. Replaying that day in filename order
-- would therefore drop 'crew_not_supervisor' and 'replayed_embedding'.
-- Production is unaffected — those two ran after the restore in real time, which
-- is why the live column above holds all nineteen — and --bootstrap loads
-- schema.sql rather than replaying. Do not replay 2026_08_06 by hand.

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
    -- browser channel (feature 004)
    'web_not_permitted',
    'web_pin_locked',
    'web_shared_device',
    -- rotating branch QR
    'qr_replayed',
    'qr_expired',
    -- crew attendance
    'crew_not_supervisor',
    -- face replay detection
    'replayed_embedding',
    -- browser channel: punched from an IP outside the branch's approved list
    'web_wrong_network'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;
