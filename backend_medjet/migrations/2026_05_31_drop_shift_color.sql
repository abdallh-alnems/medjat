-- Drop the `shifts.color` column.
-- The hex colour was only ever a UI hint (shift badge tint + weekly schedule
-- cell tint). The app no longer reads or writes it, so the column is dropped to
-- keep the schema lean.
--
-- Idempotent: fresh installs created from the updated schema.sql won't have the
-- column, so we guard the DROP behind information_schema to avoid an error there.

SET NAMES utf8mb4;

SET @col_exists := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'shifts'
      AND COLUMN_NAME = 'color'
);

SET @ddl := IF(@col_exists > 0,
    'ALTER TABLE `shifts` DROP COLUMN `color`',
    'SELECT 1'
);

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
