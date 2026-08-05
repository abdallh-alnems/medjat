-- ============================================================
-- Migration: branch kiosk — administration session on the station
-- Date: 2026-08-04
-- Feature: specs/005-branch-kiosk
-- ============================================================
--
-- Opening the kiosk's administration area costs a single-use access code, but
-- the session it opens has to outlive that one request: a supervisor enrolling
-- thirty workers on a first morning cannot type a fresh code per face.
--
-- Columns on `attendance_stations` rather than a table of their own, because
-- the constraint is genuinely one-per-station: a tablet has exactly one
-- administration area, and it is either open or it is not. A separate table
-- would have allowed two concurrent sessions on one device, which is a state
-- with no meaning and a security answer nobody wants to have to give.
--
-- Only the hash is stored, like every other credential in this feature.
--
-- The expiry exists because an enrollment screen left open on a wall is a
-- self-enrollment machine: anyone walking past could add their own face. It is
-- refreshed by activity, so an active supervisor is never interrupted, and it
-- closes itself the moment they walk away.
--
-- MySQL 8: no "ADD COLUMN IF NOT EXISTS". Run once, in order.

ALTER TABLE `attendance_stations`
  ADD COLUMN `admin_session_hash` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'SHA-256 of the open administration session token; NULL when closed',
  ADD COLUMN `admin_session_expires_at` datetime DEFAULT NULL
    COMMENT 'Computed in SQL. Refreshed by activity so a long enrollment run is not interrupted',
  ADD COLUMN `admin_session_by` int unsigned DEFAULT NULL
    COMMENT 'admins.id who authorised the open session — carried onto every enrollment made during it';
