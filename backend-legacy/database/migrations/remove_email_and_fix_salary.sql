-- Remove email column and change base_salary to INT
ALTER TABLE `employees` DROP COLUMN `email`;
ALTER TABLE `employees` MODIFY COLUMN `base_salary` INT UNSIGNED NOT NULL DEFAULT 0;
