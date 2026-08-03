-- Migration: remove the attendance kiosk / station system entirely
-- Date: 2026-06-14
--
-- ⚠️ ONLY HALF OF THIS WAS EVER APPLIED TO PRODUCTION — verified 2026-08-02.
--
--   step 1 (DROP TABLE)  : APPLIED — attendance_stations, station_recognition_logs
--                          and kiosk_pins are gone from the live database.
--   step 2 (ALTER branches): NOT APPLIED — all six `branches.station_*` columns
--                          are still present live, and therefore still present in
--                          the generated schema.sql.
--
-- DO NOT "finish the job" by dropping those columns. The kiosk is being rebuilt
-- (see attendance-methods-vs-competitors.md: a shared branch device is the single
-- biggest gap against every competitor). Those columns plus `attendance.station_id`,
-- `attendance.recognition_confidence` and the `station_*` values in
-- `attendance.recognition_method` are the parts of that system that survived, and
-- they are already live — which makes rebuilding materially cheaper than starting
-- from nothing. Treat them as reserved, not as leftovers.
--
-- One caveat for whoever rebuilds: `station_methods` is
-- enum('face_only','fingerprint_only','both_available'), and the fingerprint
-- options assume hardware a tablet does not have. Revisit that enum then.
--
-- This file lives in archive/ and must never be run. See CLAUDE.md.
--
-- Drops the kiosk-only tables and the per-branch station configuration columns.
-- Historical attendance records are PRESERVED: the `attendance` table keeps its
-- `station_id`, `recognition_method`, and `recognition_confidence` columns (and
-- any rows with check_in_method/check_out_method = 'kiosk'). There is no FK from
-- `attendance.station_id` to `attendance_stations`, so dropping the table below
-- does not touch the attendance data.
--
-- Run manually on the live MySQL 8 database (migrations are not auto-applied).

-- 1) Drop kiosk-only tables (child-first to respect foreign keys).
DROP TABLE IF EXISTS `station_recognition_logs`;
DROP TABLE IF EXISTS `kiosk_pins`;
DROP TABLE IF EXISTS `attendance_stations`;

-- 2) Drop the per-branch station configuration columns.
ALTER TABLE `branches`
    DROP COLUMN `station_enabled`,
    DROP COLUMN `station_methods`,
    DROP COLUMN `station_gps_radius_meters`,
    DROP COLUMN `station_confidence_threshold`,
    DROP COLUMN `station_admin_pin_hash`,
    DROP COLUMN `station_anti_spoofing_enabled`;

-- 3) Remove the 'station' value from any stored attendance-method lists.
--    Methods are stored as JSON arrays on tenants.attendance_methods and
--    branches.attendance_methods; strip 'station' where present.
UPDATE `tenants`
SET `attendance_methods` = JSON_REMOVE(
        `attendance_methods`,
        JSON_UNQUOTE(JSON_SEARCH(`attendance_methods`, 'one', 'station'))
    )
WHERE JSON_SEARCH(`attendance_methods`, 'one', 'station') IS NOT NULL;

UPDATE `branches`
SET `attendance_methods` = JSON_REMOVE(
        `attendance_methods`,
        JSON_UNQUOTE(JSON_SEARCH(`attendance_methods`, 'one', 'station'))
    )
WHERE `attendance_methods` IS NOT NULL
  AND JSON_SEARCH(`attendance_methods`, 'one', 'station') IS NOT NULL;
