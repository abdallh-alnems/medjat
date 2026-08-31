-- ============================================
-- Migration: who do we call about this company?
-- Date: 2026-08-05
-- ============================================
--
-- The super-admin panel is a support desk, and a support desk needs a phone
-- number. `tenants` has never carried one: `company_phone` / `company_address`
-- exist but are the company's OWN details as printed on salary letters, not a
-- way for us to reach the person who signed up. The only contact data in the
-- whole schema is `admins.phone` / `admins.email`, which is whoever happens to
-- have an account — it disappears the moment that person is removed, and it
-- says nothing about who is actually responsible for the account.
--
-- All four columns are nullable with no default: every company that already
-- exists keeps working and simply shows an empty contact card until someone
-- fills it in. Nothing reads these in the tenant-facing apps — they are ours.
--
-- MySQL 8: plain ADD COLUMN (no MariaDB `IF NOT EXISTS`). Applied once, in
-- order, by deploy.sh / migrate.sh and recorded in schema_migrations.

ALTER TABLE `tenants`
  ADD COLUMN `contact_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Person we deal with at this company (billing/decisions), set by the super-admin panel',
  ADD COLUMN `contact_email` varchar(150) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Contact email — not necessarily an admins.email, and not used for auth',
  ADD COLUMN `contact_phone` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'E.164 preferred (+20...) so the panel can dial / open WhatsApp directly',
  ADD COLUMN `ops_notes` text COLLATE utf8mb4_unicode_ci DEFAULT NULL
    COMMENT 'Internal support notes about this account. Never shown to the company.';
