-- ============================================
-- Migration: per-company control of the browser attendance channel
-- Date: 2026-08-03
-- Feature: specs/004-web-attendance-checkin
-- ============================================
--
-- DEFAULT 0. The browser is the weakest verification surface Permedjat has — no
-- WiFi access-point check, no location-spoofing signal, no face model — so
-- shipping it enabled would quietly lower the standard for every company that
-- already exists. Each one opts in knowingly instead. Deploying this migration
-- must change nothing for anybody (spec SC-006).
--
-- The photo default is the opposite way round on purpose: 1, not 0. A company
-- that switches on the weakest channel gets the one control that says anything
-- about *who* pressed the button, and has to remove it deliberately rather than
-- discover later that it was never there.

ALTER TABLE `tenants`
  ADD COLUMN `web_attendance_enabled` tinyint(1) NOT NULL DEFAULT 0
    COMMENT 'Allow employees to record attendance from a browser. Off for every existing company.',
  ADD COLUMN `web_attendance_photo_required` tinyint(1) NOT NULL DEFAULT 1
    COMMENT 'Capture an image at each browser punch. On by default WHEN the channel is enabled.';

-- NULL = inherit the company setting, which keeps the simple case free of
-- configuration: a company that enables the channel and touches nothing else
-- has it available to everyone.
--
-- Resolution is union-with-any across the employee's categories, matching how
-- category attendance methods already resolve — administrators should meet one
-- mental model, not two:
--
--   company disabled                                   -> refuse
--   company enabled, no category sets a value          -> allow
--   company enabled, >=1 of the employee's categories
--     sets web_attendance_allowed = 1                  -> allow
--   otherwise                                          -> refuse
--
-- This is NOT an attendance method and must never be added to
-- AttendanceMethodResolver::ALLOWED (spec FR-023b).
ALTER TABLE `employee_categories`
  ADD COLUMN `web_attendance_allowed` tinyint(1) DEFAULT NULL
    COMMENT 'NULL = inherit company. 1 = allowed. 0 = refused for this category.';
