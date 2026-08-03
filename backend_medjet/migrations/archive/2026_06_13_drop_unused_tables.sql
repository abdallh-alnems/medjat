-- Drop unused legacy tables (2026-06-13)
-- These tables are not referenced anywhere in the codebase (PHP or Dart):
--   * activation_codes      -> superseded by employee_activation_codes
--   * admin_sessions        -> superseded by admin_devices
--   * payment_transactions  -> billing feature never wired to any API
-- Only data present was demo seed data. No incoming foreign keys.

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS activation_codes;
DROP TABLE IF EXISTS admin_sessions;
DROP TABLE IF EXISTS payment_transactions;

SET FOREIGN_KEY_CHECKS = 1;
