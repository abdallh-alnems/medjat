-- ============================================
-- Migration: record the channel a punch came from, plus browser punch evidence
-- Date: 2026-08-03
-- Feature: specs/004-web-attendance-checkin
-- ============================================
--
-- Two additions, for two different reasons.
--
-- ORIGIN. A browser cannot verify what the app verifies — it cannot read the
-- WiFi access point and gets no location-spoofing signal — so a punch recorded
-- from a browser is not the same evidentiary object as one recorded from the
-- app, even when both say `gps_only`. Managers and auditors need to be able to
-- tell them apart, so the channel is recorded next to the method.
--
-- Note this is deliberately NOT a new value in check_in_method. The web is
-- *where* attendance was recorded from; the method is *how identity was proven*.
-- AttendanceMethodResolver::ALLOWED already blurs those two ideas together, and
-- this feature must not blur it further (spec FR-023b).
--
-- PHOTO. It is the only control on the browser channel that says anything about
-- *who* pressed the button — location and IP only say *where*. It is evidence
-- for a human, never an input to an automatic decision: nothing scores it,
-- nothing matches it, and no punch is accepted or rejected because of it.

ALTER TABLE `attendance`
  ADD COLUMN `check_in_origin` enum('app','web') COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Channel the check-in came from. NULL for pre-existing rows and for device/manual punches.'
    AFTER `check_in_method`,
  ADD COLUMN `check_out_origin` enum('app','web') COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Channel the check-out came from.'
    AFTER `check_out_method`;

ALTER TABLE `attendance`
  ADD COLUMN `check_in_photo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Relative path under uploads/attendance/. Evidence for human review only — never scored or matched.',
  ADD COLUMN `check_out_photo` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  ADD COLUMN `shared_device_flag` tinyint(1) NOT NULL DEFAULT '0'
    COMMENT 'One browser recorded attendance for more than one employee today. Advisory — never blocks.';

-- Restating every existing value is required: MODIFY replaces the enum
-- definition wholesale, so omitting one would invalidate the rows already
-- holding it.
--
-- web_shared_device is written as information, not as a refusal. It is the only
-- value in this enum that does not correspond to a blocked attempt, which is
-- the point: no non-biometric channel can *prevent* a colleague punching for a
-- willing employee, so the design makes the pattern visible instead of
-- pretending it is stopped.
ALTER TABLE `attendance_security_logs`
  MODIFY COLUMN `reason` enum(
    'mock_location',
    'rooted',
    'jailbroken',
    'vpn',
    'gps_out_of_range',
    'no_local_biometric',
    'web_not_permitted',
    'web_pin_locked',
    'web_shared_device'
  ) COLLATE utf8mb4_unicode_ci NOT NULL;
