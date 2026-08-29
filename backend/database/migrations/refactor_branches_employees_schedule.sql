SET NAMES utf8mb4;

ALTER TABLE `employees`
    ADD COLUMN `work_start_time` TIME NOT NULL DEFAULT '09:00:00' AFTER `hire_date`,
    ADD COLUMN `work_end_time` TIME NOT NULL DEFAULT '17:00:00' AFTER `work_start_time`;

UPDATE `employees` e
    JOIN `branches` b ON b.id = e.branch_id
    SET e.work_start_time = b.work_start_time,
        e.work_end_time = b.work_end_time
    WHERE b.work_start_time IS NOT NULL;

ALTER TABLE `branches`
    DROP COLUMN `work_start_time`,
    DROP COLUMN `work_end_time`,
    DROP COLUMN `gps_radius`;
