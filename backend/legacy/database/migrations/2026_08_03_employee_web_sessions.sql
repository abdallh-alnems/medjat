-- ============================================
-- Migration: employee web sign-in — repeatable PIN + expiring browser sessions
-- Date: 2026-08-03
-- Feature: specs/004-web-attendance-checkin
-- ============================================
--
-- The employee identity was designed for a personal phone: a single-use
-- activation code is exchanged once for a token that never expires. That works
-- when the device belongs to one person. A browser does not: it is opened on
-- office computers and borrowed handsets, so the session has to end — and the
-- moment it ends, the employee has nothing to get back in with, because the
-- activation code was consumed on first use and lapses after 24h anyway
-- (see the comment in app/auth/employee_login.php).
--
-- This migration adds the piece that was missing: a secret the employee can
-- reuse. The activation code is still consumed exactly once — to set the PIN.
--
-- Six digits, not four. The web sign-in page is reachable by anyone with the
-- link, which the app's login never really was, so the guessing surface is
-- genuinely new. 10^6 plus a 5-attempt lockout is the bound; the rate limiter
-- alone only slows guessing down, it does not stop it.

CREATE TABLE `employee_web_credentials` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `employee_id` int unsigned NOT NULL,
  `pin_hash` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'password_hash() of the 6-digit PIN — never the PIN itself',
  `failed_attempts` tinyint unsigned NOT NULL DEFAULT '0',
  `locked_until` datetime DEFAULT NULL COMMENT 'Set in SQL, never computed in PHP (PHP runs UTC, MySQL does not)',
  `pin_set_at` datetime NOT NULL,
  `last_used_at` datetime DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_web_credential_employee` (`employee_id`),
  KEY `idx_web_credential_tenant` (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- MODIFY replaces an enum definition wholesale, so every existing value has to
-- be restated — omitting one silently invalidates the rows holding it. Same
-- care as 2026_07_31_local_biometric_gate.sql.
--
-- Without this value, web sessions would NOT fail loudly. app/auth/employee_login.php
-- coerces anything unrecognised:
--     if (!in_array($platform, ['android','ios'], true)) { $platform = 'android'; }
-- so every browser session would be filed as Android, corrupting the channel
-- attribution the feature depends on and making the shared-device report lie.
ALTER TABLE `employee_auth_tokens`
  MODIFY COLUMN `platform` enum('android','ios','web') COLLATE utf8mb4_unicode_ci NOT NULL;

-- NULLABLE on purpose. App tokens are deliberately perpetual — this table has
-- never had an expiry — and a non-null default would start expiring every phone
-- already in the field. NULL means "never expires"; only web sessions set it.
ALTER TABLE `employee_auth_tokens`
  ADD COLUMN `expires_at` datetime DEFAULT NULL
  COMMENT 'NULL = never expires (app tokens). Web sessions set it; computed in SQL.'
  AFTER `revoked_at`;

-- Expiry is checked on every authenticated request, so it needs to be indexed
-- alongside the revocation check that already happens there.
ALTER TABLE `employee_auth_tokens`
  ADD KEY `idx_token_active` (`revoked_at`, `expires_at`);
