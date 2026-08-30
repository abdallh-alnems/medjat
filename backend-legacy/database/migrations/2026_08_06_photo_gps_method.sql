-- ============================================================
-- Migration: photo_gps — a photographed punch with no face matching
-- Date: 2026-08-06
-- ============================================================
--
-- WHY A SEPARATE METHOD RATHER THAN A SETTING
--
-- Today a company gets one of two things and nothing in between: `face_selfie`,
-- which extracts an embedding and lets the server accept or reject the punch on
-- a similarity score, or no image at all. Labour law 14/2025 makes that gap
-- expensive — biometric processing needs documented explicit consent and a
-- retention policy, and a company that only wants a deterrent has to take on
-- the whole compliance burden to get one.
--
-- photo_gps is GPS plus an image kept as evidence. Nothing scores it, nothing
-- matches it, and no punch is ever accepted or rejected because of it. That is
-- the same contract the browser channel's photo already has (see
-- 2026_08_03_attendance_punch_photo.sql and core/PunchPhotoService.php); this
-- migration only makes it reachable as a method in its own right rather than a
-- side effect of being on the web.
--
-- To be explicit about the limit: this avoids the BIOMETRIC part of 14/2025.
-- Location and a photograph of a person are still personal data and still need
-- consent — the saving is that no biometric template is derived or stored.
--
-- WHAT THIS DOES NOT DO
--
-- It does not add a row to the method/constraint confusion in
-- AttendanceMethodResolver::ALLOWED without acknowledging it. photo_gps is
-- "GPS + one more thing", the same shape as qr_gps, wifi_gps and face_selfie,
-- and it is the fourth of them. The separation of method from constraint is
-- still owed; this is one more caller that will need migrating when it happens,
-- and it is deliberately named to sort with the others so it is not missed.
--
-- ENUM VALUES ARE RESTATED IN FULL, read from production on 2026-08-06 rather
-- than from the last migration that touched them — see the note at the bottom of
-- 2026_08_06_restore_web_security_log_reasons.sql for why that distinction cost
-- this codebase three silently discarded log reasons.
--
-- 'qr_gps_face' is a legacy value with no code path left; it is preserved
-- because rows still hold it.

ALTER TABLE `attendance`
  MODIFY COLUMN `check_in_method` enum(
    'qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps',
    'photo_gps',
    'device','manual','kiosk','offline'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'qr_gps';

ALTER TABLE `attendance`
  MODIFY COLUMN `check_out_method` enum(
    'qr_gps','gps_only','qr_gps_face','face_selfie','wifi_gps',
    'photo_gps',
    'device','manual','kiosk','offline','auto'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
