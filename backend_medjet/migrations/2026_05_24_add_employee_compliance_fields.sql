-- Compliance / legal credential fields on employees + indexes for expiry alerts.
-- Powers the "document expiry alerts + compliance fields" feature (iqama, passport,
-- work permit, contract, health insurance) used by the run_alerts cron.
ALTER TABLE `employees`
    ADD COLUMN `nationality` VARCHAR(60) DEFAULT NULL AFTER `national_id`,
    ADD COLUMN `iqama_number` VARCHAR(30) DEFAULT NULL COMMENT 'Residency / iqama number' AFTER `nationality`,
    ADD COLUMN `iqama_expiry` DATE DEFAULT NULL AFTER `iqama_number`,
    ADD COLUMN `passport_number` VARCHAR(30) DEFAULT NULL AFTER `iqama_expiry`,
    ADD COLUMN `passport_expiry` DATE DEFAULT NULL AFTER `passport_number`,
    ADD COLUMN `work_permit_number` VARCHAR(40) DEFAULT NULL COMMENT 'Work permit / labor card' AFTER `passport_expiry`,
    ADD COLUMN `work_permit_expiry` DATE DEFAULT NULL AFTER `work_permit_number`,
    ADD COLUMN `contract_type` ENUM('permanent','fixed_term','part_time','temporary') DEFAULT NULL AFTER `work_permit_expiry`,
    ADD COLUMN `contract_start` DATE DEFAULT NULL AFTER `contract_type`,
    ADD COLUMN `contract_end` DATE DEFAULT NULL AFTER `contract_start`,
    ADD COLUMN `health_insurance_expiry` DATE DEFAULT NULL AFTER `contract_end`;

ALTER TABLE `employees`
    ADD KEY `idx_emp_iqama_expiry` (`tenant_id`, `iqama_expiry`),
    ADD KEY `idx_emp_passport_expiry` (`tenant_id`, `passport_expiry`),
    ADD KEY `idx_emp_workpermit_expiry` (`tenant_id`, `work_permit_expiry`),
    ADD KEY `idx_emp_contract_end` (`tenant_id`, `contract_end`),
    ADD KEY `idx_emp_health_expiry` (`tenant_id`, `health_insurance_expiry`);
