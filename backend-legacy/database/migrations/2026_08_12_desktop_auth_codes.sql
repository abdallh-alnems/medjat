-- Single-use codes that hand a browser sign-in back to the desktop app.
--
-- The desktop shell is an Electron window, and Electron has no platform
-- authenticator (`isUserVerifyingPlatformAuthenticatorAvailable()` is false), so
-- a Google account protected by a passkey cannot complete sign-in inside it.
-- Sign-in therefore happens in the user's real browser, which then hands the
-- session back through a code exchanged for a Firebase custom token.
--
-- Codes are short-lived and single-use; only their hashes are stored, so a
-- database read cannot replay one.

CREATE TABLE `desktop_auth_codes` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `code_hash` char(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'sha256 of the code handed to the browser',
  `state_hash` char(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'sha256 of the nonce the desktop app generated',
  `admin_id` int unsigned NOT NULL,
  `firebase_uid` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` datetime NOT NULL,
  `used_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_desktop_auth_code` (`code_hash`),
  KEY `idx_desktop_auth_expires` (`expires_at`),
  CONSTRAINT `fk_desktop_auth_admin` FOREIGN KEY (`admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
