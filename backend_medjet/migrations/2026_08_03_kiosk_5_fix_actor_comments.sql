-- ============================================================
-- Migration: branch kiosk — correct the actor column comments
-- Date: 2026-08-03
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- Comment-only correction. No data, type, or constraint changes.
--
-- 2026_08_03_kiosk_1_stations.sql described `attendance_stations.paired_by`,
-- `revoked_by`, and `kiosk_codes.created_by` as "employees.id". That is wrong:
-- administrators in this system live in `admins`, and `Auth::authenticateUser()`
-- returns `admin_id` from that table. An employee never pairs a kiosk.
--
-- Left uncorrected this would eventually produce a JOIN against the wrong table
-- that silently returns nothing — the columns carry no foreign key, so nothing
-- would have complained.
--
-- Written as a new file rather than by editing the applied one: migrate.sh
-- checksums every applied migration and warns when one changes underneath it.

ALTER TABLE `attendance_stations`
  MODIFY COLUMN `paired_by` int unsigned DEFAULT NULL
    COMMENT 'admins.id of the administrator who paired this tablet',
  MODIFY COLUMN `revoked_by` int unsigned DEFAULT NULL
    COMMENT 'admins.id of the administrator who revoked it';

ALTER TABLE `kiosk_codes`
  MODIFY COLUMN `created_by` int unsigned NOT NULL
    COMMENT 'admins.id — who authorised this code. Carried onto every enrollment performed in the session it opens';
