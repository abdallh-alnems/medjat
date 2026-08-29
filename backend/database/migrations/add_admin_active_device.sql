-- Single active session per admin (management app).
-- Logging in on a new device updates `active_device_id`; any other device is
-- signed out on its next authenticated request (handled in Auth::authenticateUser).
--
-- MySQL 8 has no `ADD COLUMN IF NOT EXISTS`, so run this once by hand.
-- If the column already exists this will error with 1060 (Duplicate column) —
-- that's safe to ignore.

ALTER TABLE `admins`
  ADD COLUMN `active_device_id` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL
  COMMENT 'Most recent device that logged in; other devices are signed out on their next request'
  AFTER `last_login_ip`;
