-- ============================================
-- Migration: record whether a company's timezone was actually chosen
-- Date: 2026-07-31
-- ============================================
--
-- `tenants.timezone` defaults to 'Africa/Cairo', so the value alone cannot say
-- whether a company picked Cairo or simply never picked anything. The company
-- settings screen in permedjat_central inferred it from the value:
--
--     if (timezone == 'Africa/Cairo') { autoDetectFromDevice(); }
--
-- which misfires both ways. A genuinely Egyptian company gets its timezone
-- silently re-filled from the device every time the screen opens — so an admin
-- opening settings while abroad, then saving an unrelated field, moves the
-- whole company's clock. And a company that deliberately chose Cairo can never
-- stop the suggestion.
--
-- With this flag the guess disappears: onboarding sets it to 1 because the
-- admin picked a value, and the settings screen only ever suggests when it is 0.
--
-- Existing companies get 0 — none of them chose, so they keep today's
-- behaviour until someone saves the setting explicitly.
--
-- MySQL 8 (live) has no "ADD COLUMN IF NOT EXISTS" — run once by hand.

ALTER TABLE `tenants`
  ADD COLUMN `timezone_is_explicit` tinyint(1) NOT NULL DEFAULT 0
  COMMENT 'Admin actually chose this timezone (vs sitting on the column default)'
  AFTER `timezone`;
