-- ============================================================
-- Migration: branch kiosk — 'station_code' recognition method
-- Date: 2026-08-04
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- `attendance.recognition_method` survived the 2026-06 station removal with
-- four station values — station_face, station_fingerprint, station_both,
-- station_qr — none of which describes "the employee typed their personal
-- code". Without a value for it, a code-identified punch would have to store
-- either NULL (indistinguishable from an old row) or `station_face` (a lie that
-- would later be read as biometric evidence it never had).
--
-- FR-011 requires every kiosk punch to carry the identification method that
-- produced it, and FR-042 makes the face-versus-code distinction the security
-- boundary of the whole feature. It has to be visible on the attendance row
-- itself, not only in the recognition log.
--
-- Existing values are re-stated in full and unchanged; MySQL 8 has no additive
-- ENUM syntax. No stored row is invalidated.
--
-- The three unused station values are kept. They are historical: rows written by
-- the removed system still carry them.

ALTER TABLE `attendance`
  MODIFY COLUMN `recognition_method` enum(
    'manual','qr_gps','mobile_face',
    'device_fingerprint','device_face','device_card','device_password',
    'station_face','station_fingerprint','station_both','station_qr',
    'station_code'
  ) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL;
