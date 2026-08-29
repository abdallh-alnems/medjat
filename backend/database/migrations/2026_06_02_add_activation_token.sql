-- Join-link / QR support for employee activation.
--
-- The short `code` is meant to be typed by hand. For the deep link and QR
-- code we need a longer, non-guessable secret embedded in a URL, so we add a
-- `token` column to the SAME activation row. Because the code, the link and
-- the QR all reference one row, consuming any of them (which sets `used_at`)
-- invalidates the others automatically — no extra bookkeeping needed.
--
-- MySQL 8 has no "ADD COLUMN IF NOT EXISTS"; this migration is written for the
-- live MySQL 8 database and must be run once. Re-running it will error on the
-- duplicate column/index, which is the expected guard.

ALTER TABLE `employee_activation_codes`
  ADD COLUMN `token` varchar(64) COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL
  COMMENT 'Long opaque secret for join link / QR; same row as code' AFTER `code`;

ALTER TABLE `employee_activation_codes`
  ADD UNIQUE KEY `uniq_token` (`token`);
